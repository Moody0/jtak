using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    public class SettlementRequestService : ISettlementRequestService
    {
        private readonly AccountingDbContext _context;
        private readonly ILedgerService _ledger;
        private readonly ILogger<SettlementRequestService> _logger;

        public SettlementRequestService(AccountingDbContext context, ILedgerService ledger, ILogger<SettlementRequestService> logger)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _ledger = ledger ?? throw new ArgumentNullException(nameof(ledger));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<SettlementBalanceDto> GetCaptainBalanceAsync(Guid captainUserId, string currency = "SYP")
        {
            currency = NormalizeCurrency(currency);
            var gross = await _ledger.GetUserCashFloatBalanceAsync(captainUserId, currency);
            var active = await _context.SettlementRequests
                .Where(x => x.RequestedByUserId == captainUserId &&
                            x.PartyType == SettlementPartyType.Captain &&
                            x.Currency == currency &&
                            (x.Status == SettlementRequestStatus.Pending || x.Status == SettlementRequestStatus.Approved))
                .SumAsync(x => (decimal?)x.Amount) ?? 0m;

            return new SettlementBalanceDto
            {
                GrossAmount = gross,
                PendingAmount = active,
                AvailableAmount = Math.Max(0m, gross - active),
                Currency = currency,
                HasPendingRequest = active > 0m
            };
        }

        public async Task<SettlementBalanceDto> GetMerchantBalanceAsync(IEnumerable<int> merchantIds, string currency = "SYP")
        {
            currency = NormalizeCurrency(currency);
            var ids = (merchantIds ?? Array.Empty<int>()).Distinct().ToArray();
            decimal gross = 0m;
            foreach (var merchantId in ids)
            {
                gross += await _ledger.GetMerchantPayableBalanceAsync(merchantId, currency);
            }

            var active = ids.Length == 0 ? 0m : await _context.SettlementRequestMerchantAllocations
                .Where(x => ids.Contains(x.MerchantId) &&
                            x.SettlementRequest.Currency == currency &&
                            (x.SettlementRequest.Status == SettlementRequestStatus.Pending ||
                             x.SettlementRequest.Status == SettlementRequestStatus.Approved))
                .SumAsync(x => (decimal?)x.Amount) ?? 0m;

            return new SettlementBalanceDto
            {
                GrossAmount = gross,
                PendingAmount = active,
                AvailableAmount = Math.Max(0m, gross - active),
                Currency = currency,
                HasPendingRequest = active > 0m
            };
        }

        public Task<SettlementRequestDto> CreateCaptainRequestAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request) =>
            InFinancialTransactionAsync(() => CreateCaptainRequestCoreAsync(userId, name, phone, request));

        private async Task<SettlementRequestDto> CreateCaptainRequestCoreAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request)
        {
            var currency = "SYP";
            var balance = await GetCaptainBalanceAsync(userId, currency);
            if (balance.HasPendingRequest)
                throw new InvalidOperationException("يوجد طلب تسوية قيد المراجعة بالفعل.");
            if (balance.GrossAmount <= 0m)
                throw new InvalidOperationException("لا توجد عهدة نقدية لتسويتها حالياً.");

            var amount = request?.Amount.HasValue == true && request.Amount.Value > 0
                ? request.Amount.Value
                : balance.AvailableAmount;

            if (amount <= 0m)
                throw new InvalidOperationException("يرجى إدخال مبلغ صحيح أكبر من الصفر.");
            if (amount > balance.AvailableAmount)
                throw new InvalidOperationException($"المبلغ المطلوب يتجاوز العهدة المتاحة ({balance.AvailableAmount:N0} {currency}).");

            var entity = NewRequest(SettlementPartyType.Captain, userId, name, phone, amount, currency, request);
            _context.SettlementRequests.Add(entity);
            await _context.SaveChangesAsync();
            return Map(entity);
        }

        public Task<SettlementRequestDto> CreateMerchantRequestAsync(Guid userId, string name, string phone, IEnumerable<MerchantSettlementSource> merchants, CreateSettlementRequestDto request) =>
            InFinancialTransactionAsync(() => CreateMerchantRequestCoreAsync(userId, name, phone, merchants, request));

        private async Task<SettlementRequestDto> CreateMerchantRequestCoreAsync(Guid userId, string name, string phone, IEnumerable<MerchantSettlementSource> merchants, CreateSettlementRequestDto request)
        {
            var sources = (merchants ?? Array.Empty<MerchantSettlementSource>())
                .GroupBy(x => x.MerchantId)
                .Select(x => x.First())
                .ToArray();
            if (sources.Length == 0)
                throw new InvalidOperationException("لا يوجد متجر مرتبط بهذا الحساب.");

            var currency = "SYP";
            var balance = await GetMerchantBalanceAsync(sources.Select(x => x.MerchantId), currency);
            var amount = request?.Amount ?? balance.AvailableAmount;
            if (amount <= 0m)
                throw new InvalidOperationException("يرجى إدخال مبلغ صحيح أكبر من الصفر.");
            if (amount > balance.AvailableAmount)
                throw new InvalidOperationException($"المبلغ المطلوب يتجاوز الرصيد المتاح ({balance.AvailableAmount:N0} ل.س).");

            var entity = NewRequest(SettlementPartyType.Merchant, userId, name, phone, amount, currency, request);
            var remaining = amount;
            foreach (var source in sources)
            {
                var payable = await _ledger.GetMerchantPayableBalanceAsync(source.MerchantId, currency);
                var reserved = await _context.SettlementRequestMerchantAllocations
                    .Where(x => x.MerchantId == source.MerchantId &&
                                (x.SettlementRequest.Status == SettlementRequestStatus.Pending ||
                                 x.SettlementRequest.Status == SettlementRequestStatus.Approved))
                    .SumAsync(x => (decimal?)x.Amount) ?? 0m;
                var available = Math.Max(0m, payable - reserved);
                var allocated = Math.Min(remaining, available);
                if (allocated <= 0m) continue;
                entity.MerchantAllocations.Add(new SettlementRequestMerchantAllocation
                {
                    MerchantId = source.MerchantId,
                    MerchantTitle = source.MerchantTitle,
                    Amount = allocated
                });
                remaining -= allocated;
                if (remaining <= 0m) break;
            }

            if (remaining > 0.001m)
                throw new InvalidOperationException("تعذر حجز كامل المبلغ المطلوب. يرجى تحديث الرصيد والمحاولة مجدداً.");

            _context.SettlementRequests.Add(entity);
            await _context.SaveChangesAsync();
            return Map(entity);
        }

        public async Task<List<SettlementRequestDto>> GetMineAsync(Guid userId, SettlementPartyType partyType) =>
            (await BaseQuery().Where(x => x.RequestedByUserId == userId && x.PartyType == partyType)
                .OrderByDescending(x => x.CreatedDate).ToListAsync()).Select(Map).ToList();

        public async Task<List<SettlementRequestDto>> GetAllAsync(SettlementRequestStatus? status = null, SettlementPartyType? partyType = null)
        {
            var query = BaseQuery();
            if (status.HasValue) query = query.Where(x => x.Status == status.Value);
            if (partyType.HasValue) query = query.Where(x => x.PartyType == partyType.Value);
            return (await query.OrderByDescending(x => x.CreatedDate).ToListAsync()).Select(Map).ToList();
        }

        public Task<SettlementRequestDto> AcceptAsync(Guid requestId, Guid adminId, string notes = null) =>
            InFinancialTransactionAsync(() => AcceptCoreAsync(requestId, adminId, notes));

        private async Task<SettlementRequestDto> AcceptCoreAsync(Guid requestId, Guid adminId, string notes)
        {
            var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                ?? throw new InvalidOperationException("طلب التسوية غير موجود.");
            if (entity.Status != SettlementRequestStatus.Pending)
                throw new InvalidOperationException("تمت معالجة طلب التسوية مسبقاً.");

            if (entity.PartyType == SettlementPartyType.Captain)
            {
                var currentFloat = await _ledger.GetUserCashFloatBalanceAsync(entity.RequestedByUserId, entity.Currency);
                if (currentFloat + 0.001m < entity.Amount)
                    throw new InvalidOperationException($"عهدة المندوب الحالية ({currentFloat:N0} {entity.Currency}) أقل من المبلغ المطلوب تسويته ({entity.Amount:N0} {entity.Currency}).");

                var captainFloat = await _ledger.GetOrCreateUserAccountAsync(entity.RequestedByUserId, AccountType.Asset,
                    SystemAccountCodes.CaptainCashFloatPrefix, $"Cash Float - {entity.RequestedByName}", entity.Currency);
                var vault = await _ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault", AccountType.Asset, entity.Currency);
                var txn = await _ledger.PostTransactionAsync(new PostTransactionRequest
                {
                    ReferenceType = "CaptainSettlementRequest",
                    ReferenceId = entity.Id.ToString(),
                    IdempotencyKey = $"CaptainSettlementRequest-{entity.Id}",
                    Description = $"Cash received from captain {entity.RequestedByName}",
                    Entries = new List<PostLedgerEntryRequest>
                    {
                        new() { AccountId = vault.Id, Debit = entity.Amount, Currency = entity.Currency, Memo = $"Cash received for {entity.RequestNumber}" },
                        new() { AccountId = captainFloat.Id, Credit = entity.Amount, Currency = entity.Currency, Memo = $"Captain custody cleared by {entity.RequestNumber}" }
                    }
                });

                entity.Status = SettlementRequestStatus.Completed;
                entity.LedgerTransactionId = txn.Id;
                entity.CompletedByAdminId = adminId;
                entity.CompletedAt = DateTime.UtcNow;
            }
            else
            {
                entity.Status = SettlementRequestStatus.Approved;
            }

            entity.ReviewedByAdminId = adminId;
            entity.ReviewedAt = DateTime.UtcNow;
            if (!string.IsNullOrWhiteSpace(notes)) entity.Notes = JoinNotes(entity.Notes, notes);
            await _context.SaveChangesAsync();
            return Map(entity);
        }

        public Task<SettlementRequestDto> RejectAsync(Guid requestId, Guid adminId, string reason = null) =>
            InFinancialTransactionAsync(() => RejectCoreAsync(requestId, adminId, reason));

        private async Task<SettlementRequestDto> RejectCoreAsync(Guid requestId, Guid adminId, string reason)
        {
            var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                ?? throw new InvalidOperationException("طلب التسوية غير موجود.");
            if (entity.Status != SettlementRequestStatus.Pending)
                throw new InvalidOperationException("لا يمكن رفض الطلب بعد قبوله أو معالجته مسبقاً.");
            entity.Status = SettlementRequestStatus.Rejected;
            entity.RejectionReason = string.IsNullOrWhiteSpace(reason) ? "لم تتم الموافقة على طلب التسوية." : reason.Trim();
            entity.ReviewedByAdminId = adminId;
            entity.ReviewedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return Map(entity);
        }

        public Task<SettlementRequestDto> CompleteMerchantPayoutAsync(Guid requestId, Guid adminId, string notes = null) =>
            InFinancialTransactionAsync(() => CompleteMerchantPayoutCoreAsync(requestId, adminId, notes));

        private async Task<SettlementRequestDto> CompleteMerchantPayoutCoreAsync(Guid requestId, Guid adminId, string notes)
        {
            var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                ?? throw new InvalidOperationException("طلب التسوية غير موجود.");
            if (entity.PartyType != SettlementPartyType.Merchant)
                throw new InvalidOperationException("هذا الإجراء متاح لطلبات التجار فقط.");

            // Idempotency: If already completed, return existing without re-posting
            if (entity.Status == SettlementRequestStatus.Completed)
            {
                return Map(entity);
            }

            if (entity.Status != SettlementRequestStatus.Approved)
                throw new InvalidOperationException("يجب قبول طلب التاجر أولاً قبل تأكيد الاستلام.");

            return await PostMerchantPayoutJournalAsync(entity, notes, isMerchantConfirmation: false, completedByAdminId: adminId);
        }

        public Task<SettlementRequestDto> ConfirmMerchantReceiptAsync(Guid requestId, Guid merchantUserId, string notes = null) =>
            InFinancialTransactionAsync(() => ConfirmMerchantReceiptCoreAsync(requestId, merchantUserId, notes));

        private async Task<SettlementRequestDto> ConfirmMerchantReceiptCoreAsync(Guid requestId, Guid merchantUserId, string notes)
        {
            var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                ?? throw new InvalidOperationException("طلب التسوية غير موجود.");

            if (entity.PartyType != SettlementPartyType.Merchant)
                throw new InvalidOperationException("هذا الإجراء متاح لطلبات تسوية التجار فقط.");

            if (entity.RequestedByUserId != merchantUserId)
                throw new InvalidOperationException("لا يمكنك تأكيد استلام طلب تسوية يخص حساباً آخر.");

            // Idempotency: If already completed, return existing without re-posting
            if (entity.Status == SettlementRequestStatus.Completed)
            {
                return Map(entity);
            }

            if (entity.Status != SettlementRequestStatus.Approved)
                throw new InvalidOperationException("يجب قبول واعتماد طلب التسوية من الإدارة أولاً لتأكيد الاستلام.");

            return await PostMerchantPayoutJournalAsync(entity, notes, isMerchantConfirmation: true, completedByAdminId: null);
        }

        private async Task<SettlementRequestDto> PostMerchantPayoutJournalAsync(
            SettlementRequest entity, string notes, bool isMerchantConfirmation, Guid? completedByAdminId)
        {
            var entries = new List<PostLedgerEntryRequest>();
            foreach (var allocation in entity.MerchantAllocations)
            {
                var balance = await _ledger.GetMerchantPayableBalanceAsync(allocation.MerchantId, entity.Currency);
                if (balance + 0.001m < allocation.Amount)
                    throw new InvalidOperationException($"رصيد {allocation.MerchantTitle ?? $"المتجر #{allocation.MerchantId}"} لم يعد كافياً لإتمام التسوية.");
                var account = await _ledger.GetOrCreateMerchantAccountAsync(allocation.MerchantId, allocation.MerchantTitle, entity.Currency);
                entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = account.Id,
                    Debit = allocation.Amount,
                    Currency = entity.Currency,
                    Memo = $"Merchant payout received for {entity.RequestNumber}"
                });
            }

            var (sourceAccount, sourceAccountName) = await ResolvePayoutSourceAccountAsync(entity.Method, entity.Currency);
            var sourceBalance = await _ledger.GetAccountBalanceAsync(sourceAccount.Id);
            if (sourceBalance + 0.001m < entity.Amount)
                throw new InvalidOperationException($"رصيد {sourceAccountName} ({sourceAccount.AccountCode}) غير كافٍ لإتمام التسوية. المتاح حالياً {sourceBalance:N0} {entity.Currency}.");

            entries.Add(new PostLedgerEntryRequest
            {
                AccountId = sourceAccount.Id,
                Credit = entity.Amount,
                Currency = entity.Currency,
                Memo = $"Merchant payout disbursed from {sourceAccount.AccountCode} for {entity.RequestNumber}"
            });

            var txn = await _ledger.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "MerchantSettlementRequest",
                ReferenceId = entity.Id.ToString(),
                IdempotencyKey = $"MerchantSettlementRequest-{entity.Id}",
                Description = isMerchantConfirmation
                    ? $"Merchant confirmed payout receipt for {entity.RequestNumber} via {sourceAccountName}"
                    : $"Admin recorded payout receipt for {entity.RequestNumber} via {sourceAccountName}",
                Entries = entries
            });

            entity.Status = SettlementRequestStatus.Completed;
            if (completedByAdminId.HasValue) entity.CompletedByAdminId = completedByAdminId.Value;
            entity.CompletedAt = DateTime.UtcNow;
            entity.LedgerTransactionId = txn.Id;
            if (!string.IsNullOrWhiteSpace(notes)) entity.Notes = JoinNotes(entity.Notes, notes);
            await _context.SaveChangesAsync();
            _logger.LogInformation("Completed merchant settlement request {RequestNumber} (Actor: {Actor}, Source: {SourceCode})",
                entity.RequestNumber, isMerchantConfirmation ? "Merchant" : "Admin", sourceAccount.AccountCode);
            return Map(entity);
        }

        private async Task<(Account Account, string AccountName)> ResolvePayoutSourceAccountAsync(string method, string currency)
        {
            var normalizedMethod = (method ?? string.Empty).Trim().ToLowerInvariant();

            if (normalizedMethod.Contains("bank") || normalizedMethod.Contains("transfer") || normalizedMethod.Contains("wire"))
            {
                var bank = await _ledger.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.BankMain, "Company Main Bank Account", AccountType.Asset, currency);
                return (bank, "الحساب البنكي الرئيسي");
            }

            if (normalizedMethod.Contains("safe") || normalizedMethod == "cash_safe" || normalizedMethod == "office_safe" || normalizedMethod == "branch_safe")
            {
                var safe = await _ledger.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.CompanyCashSafe, "Company Cash Safe", AccountType.Asset, currency);
                return (safe, "صندوق الخزينة النقدي");
            }

            if (normalizedMethod.Contains("pgw") || normalizedMethod.Contains("gateway") || normalizedMethod.Contains("wallet") || normalizedMethod.Contains("clearing"))
            {
                var pgw = await _ledger.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.ElectronicPaymentGateway, "Electronic Payment Gateway Clearing", AccountType.Asset, currency);
                return (pgw, "بوابة الدفع الإلكتروني");
            }

            // Default: Company Main Cash Vault (1000)
            var vault = await _ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.CompanyMainVault, "Company Cash Vault", AccountType.Asset, currency);
            return (vault, "خزينة جيتك الرئيسية");
        }

        private IQueryable<SettlementRequest> BaseQuery() => _context.SettlementRequests
            .Include(x => x.MerchantAllocations).AsNoTracking();

        private IQueryable<SettlementRequest> TrackingQuery() => _context.SettlementRequests
            .Include(x => x.MerchantAllocations);

        private async Task<T> InFinancialTransactionAsync<T>(Func<Task<T>> action)
        {
            // The in-memory provider used by unit tests does not support transactions.
            if (!_context.Database.IsRelational())
                return await action();

            await using var transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var result = await action();
            await transaction.CommitAsync();
            return result;
        }

        private static SettlementRequest NewRequest(SettlementPartyType partyType, Guid userId, string name, string phone,
            decimal amount, string currency, CreateSettlementRequestDto request) => new()
        {
            Id = Guid.NewGuid(),
            RequestNumber = $"SET-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}",
            PartyType = partyType,
            Status = SettlementRequestStatus.Pending,
            RequestedByUserId = userId,
            RequestedByName = name,
            RequestedByPhone = phone,
            Amount = amount,
            Currency = currency,
            Method = request?.Method,
            AccountDetails = request?.AccountDetails,
            Notes = request?.Notes
        };

        private static string NormalizeCurrency(string currency) => (currency ?? "SYP").Trim().ToUpperInvariant();
        private static string JoinNotes(string current, string extra) => string.IsNullOrWhiteSpace(current) ? extra.Trim() : $"{current}\n{extra.Trim()}";

        private static SettlementRequestDto Map(SettlementRequest x) => new()
        {
            Id = x.Id,
            RequestNumber = x.RequestNumber,
            PartyType = x.PartyType,
            Status = x.Status,
            RequestedByUserId = x.RequestedByUserId,
            RequestedByName = x.RequestedByName,
            RequestedByPhone = x.RequestedByPhone,
            Amount = x.Amount,
            Currency = x.Currency,
            Method = x.Method,
            AccountDetails = x.AccountDetails,
            Notes = x.Notes,
            RejectionReason = x.RejectionReason,
            ReviewedByAdminId = x.ReviewedByAdminId,
            ReviewedAt = x.ReviewedAt,
            CompletedAt = x.CompletedAt,
            LedgerTransactionId = x.LedgerTransactionId,
            CreatedDate = x.CreatedDate,
            MerchantAllocations = x.MerchantAllocations?.Select(a => new SettlementMerchantAllocationDto
            {
                MerchantId = a.MerchantId,
                MerchantTitle = a.MerchantTitle,
                Amount = a.Amount
            }).ToList() ?? new List<SettlementMerchantAllocationDto>()
        };
    }
}
