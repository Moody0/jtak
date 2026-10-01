using App.Orders.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Orders.Entities;
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
        private readonly OrdersDbContext _ordersContext;
        private readonly ILedgerService _ledger;
        private readonly ILogger<SettlementRequestService> _logger;
        private readonly DriverFinancialSafetyService _safety;

        public SettlementRequestService(AccountingDbContext context, ILedgerService ledger, ILogger<SettlementRequestService> logger,
            OrdersDbContext ordersContext = null, DriverFinancialSafetyService safety = null)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _ledger = ledger ?? throw new ArgumentNullException(nameof(ledger));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _ordersContext = ordersContext;
            _safety = safety ?? new DriverFinancialSafetyService(context, ledger, orders: ordersContext);
        }

        public async Task<SettlementBalanceDto> GetCaptainBalanceAsync(Guid captainUserId, string currency = "SYP")
        {
            currency = NormalizeCurrency(currency);
            var gross = await _ledger.GetUserCashFloatBalanceAsync(captainUserId, currency);
            var activeAmounts = await _context.SettlementRequests
                .Where(x => x.RequestedByUserId == captainUserId &&
                            x.PartyType == SettlementPartyType.Captain &&
                            x.Currency == currency &&
                            (x.Status == SettlementRequestStatus.Pending || x.Status == SettlementRequestStatus.Approved))
                .Select(x => x.Amount).ToListAsync();
            var active = activeAmounts.Sum();

            var position = await _safety.GetPositionAsync(captainUserId, currency: currency);
            var hasPendingAccounting = position.HasUnfinishedAccounting;
            var availableCustody = hasPendingAccounting ? 0m : Math.Max(0m, gross - active - position.ReservedForPurchases);

            // Compute driver earnings to calculate smart netting breakdown
            var earningsGross = await _ledger.GetUserEarningsBalanceAsync(captainUserId, currency);
            var activeEarnings = await _context.SettlementRequests
                .Where(x => x.RequestedByUserId == captainUserId &&
                            x.PartyType == SettlementPartyType.CaptainEarnings &&
                            x.Currency == currency &&
                            (x.Status == SettlementRequestStatus.Pending || x.Status == SettlementRequestStatus.Approved))
                .SumAsync(x => (decimal?)x.Amount) ?? 0m;
            var availableEarnings = hasPendingAccounting ? 0m : Math.Max(0m, earningsGross - activeEarnings);

            var wagesOffset = Math.Min(availableCustody, Math.Max(0m, availableEarnings));
            var netCashDue = Math.Max(0m, availableCustody - wagesOffset);
            var isCovered = availableEarnings > 0m && availableCustody >= availableEarnings;

            return new SettlementBalanceDto
            {
                GrossAmount = gross,
                CustodyBalance = gross,
                PendingAmount = active,
                ReservedPurchaseAmount = position.ReservedForPurchases,
                AvailableAmount = availableCustody,
                WagesOffset = wagesOffset,
                NetCashDue = netCashDue,
                IsCoveredByCustody = isCovered,
                Currency = currency,
                HasPendingRequest = active > 0m,
                HasPendingAccountingOrders = hasPendingAccounting
            };
        }

        public async Task<CaptainEarningsWalletDto> GetCaptainEarningsAsync(Guid captainUserId, string currency = "SYP")
        {
            currency = NormalizeCurrency(currency);
            var entries = await _context.LedgerEntries.AsNoTracking()
                .Where(x => x.Account.OwnerUserId == captainUserId &&
                            x.Account.Type == AccountType.Liability &&
                            x.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix) &&
                            x.Currency == currency)
                .Select(x => new { x.Credit, x.Debit, x.Transaction.ReferenceType }).ToListAsync();
            var gross = entries.Sum(x => x.Credit - x.Debit);
            // Reversal/correction debits are not cash payouts. Net lifetime
            // earnings include those corrections; payouts include EOD offsets.
            var paid = entries.Where(x => x.ReferenceType == "CaptainEarningsPayout" || x.ReferenceType == "FleetSettlement" || x.ReferenceType == "CaptainSettlementRequest")
                .Sum(x => x.Debit - x.Credit);
            var requests = await GetMineAsync(captainUserId, SettlementPartyType.CaptainEarnings);
            var active = requests.Where(x => x.Currency == currency &&
                (x.Status == SettlementRequestStatus.Pending || x.Status == SettlementRequestStatus.Approved)).Sum(x => x.Amount);
            var position = await _safety.GetPositionAsync(captainUserId, currency: currency);
            var pendingAccounting = position.HasUnfinishedAccounting;
            var available = pendingAccounting ? 0m : Math.Max(0m, gross - active);

            var custodyGross = position.Cash;
            var custodySpendable = position.SpendableCash;
            var wagesOffset = Math.Min(custodySpendable, Math.Max(0m, available));
            var netCashDue = Math.Max(0m, custodySpendable - wagesOffset);
            var isCovered = available > 0m && custodySpendable >= available;

            return new CaptainEarningsWalletDto
            {
                GrossAmount = gross,
                CustodyBalance = custodyGross,
                TotalPaid = paid,
                TotalEarned = gross + paid,
                PendingAmount = active,
                AvailableAmount = available,
                WagesOffset = wagesOffset,
                NetCashDue = netCashDue,
                IsCoveredByCustody = isCovered,
                Currency = currency,
                HasPendingRequest = active > 0m,
                HasPendingAccountingOrders = pendingAccounting,
                Requests = requests.Take(50).ToList()
            };
        }

        public Task<SettlementRequestDto> CreateCaptainEarningsRequestAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request) =>
            _safety.WithDriverLockAsync(userId, () => InFinancialTransactionAsync(async () =>
            {
                var balance = await GetCaptainEarningsAsync(userId);
                if (balance.HasPendingAccountingOrders)
                    throw new InvalidOperationException("هناك طلبات مسلّمة قيد المعالجة المحاسبية. يرجى المحاولة بعد اكتمالها.");
                if (balance.HasPendingRequest)
                    throw new InvalidOperationException("يوجد طلب صرف مستحقات قيد المعالجة بالفعل.");
                if (balance.IsCoveredByCustody)
                    throw new InvalidOperationException("مستحقاتك مغطاة بالكامل من العهدة النقدية المسجلة بحوزتك. يتم اقتطاعها مباشرة عند تسليم صافي العهدة للإدارة.");
                var maxPayable = balance.WagesOffset > 0m ? Math.Max(0m, balance.AvailableAmount - balance.WagesOffset) : balance.AvailableAmount;
                if (maxPayable <= 0m)
                    throw new InvalidOperationException("مستحقاتك مغطاة بالكامل من العهدة النقدية المسجلة بحوزتك. يتم اقتطاعها مباشرة عند تسليم صافي العهدة للإدارة.");
                var amount = request?.Amount ?? maxPayable;
                if (amount <= 0m || amount != Math.Round(amount, 2) || amount > maxPayable)
                    throw new InvalidOperationException(balance.WagesOffset > 0m
                        ? $"المبلغ المطلوب يتجاوز المستحقات غير المغطاة بالعهدة النقدية ({maxPayable:N0} ل.س)."
                        : "مبلغ الصرف غير صالح أو يتجاوز الأرباح المتاحة.");
                var entity = NewRequest(SettlementPartyType.CaptainEarnings, userId, name, phone, amount, "SYP", request);
                // The driver cannot select an unrelated treasury/payment source.
                entity.Method = "cash_driver_payout";
                _context.SettlementRequests.Add(entity);
                await _context.SaveChangesAsync();
                return Map(entity);
            }));

        public Task<SettlementRequestDto> CompleteCaptainEarningsPayoutAsync(Guid requestId, Guid adminId, string notes = null) =>
            WithRequestDriverLockAsync(requestId, () => InFinancialTransactionAsync(async () =>
            {
                var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                    ?? throw new InvalidOperationException("طلب صرف المستحقات غير موجود.");
                if (entity.PartyType != SettlementPartyType.CaptainEarnings)
                    throw new InvalidOperationException("هذا الإجراء متاح لصرف مستحقات السائق فقط.");
                if (entity.Status == SettlementRequestStatus.Completed) return Map(entity);
                if (entity.Status != SettlementRequestStatus.Approved)
                    throw new InvalidOperationException("يجب الموافقة على الطلب أولاً قبل تأكيد دفع المستحقات.");
                var balance = await GetCaptainEarningsAsync(entity.RequestedByUserId, entity.Currency);
                if (balance.HasPendingAccountingOrders || balance.GrossAmount < entity.Amount)
                    throw new InvalidOperationException("الرصيد غير كافٍ أو توجد قيود محاسبية معلقة. لم يتم الصرف.");
                var earnings = await _ledger.GetOrCreateUserAccountAsync(entity.RequestedByUserId, AccountType.Liability,
                    SystemAccountCodes.CaptainEarningsPrefix, $"Earnings - {entity.RequestedByName}", entity.Currency);
                var vault = await _ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault", AccountType.Asset, entity.Currency);
                if (await _ledger.GetAccountBalanceAsync(vault.Id) < entity.Amount)
                    throw new InvalidOperationException("رصيد خزينة جيتك غير كافٍ لصرف المستحقات. لم يتم الخصم.");
                var txn = await _ledger.PostTransactionAsync(new PostTransactionRequest
                {
                    ReferenceType = "CaptainEarningsPayout", ReferenceId = entity.Id.ToString(),
                    IdempotencyKey = $"CaptainEarningsPayout-{entity.Id}",
                    Description = $"Driver earnings paid for {entity.RequestNumber}",
                    Entries = new List<PostLedgerEntryRequest>
                    {
                        new() { AccountId = earnings.Id, Debit = entity.Amount, Currency = entity.Currency, Memo = $"Driver paid for {entity.RequestNumber}" },
                        new() { AccountId = vault.Id, Credit = entity.Amount, Currency = entity.Currency, Memo = $"Cash paid for {entity.RequestNumber}" }
                    }
                });
                entity.Status = SettlementRequestStatus.Completed;
                entity.LedgerTransactionId = txn.Id;
                entity.CompletedByAdminId = adminId; entity.CompletedAt = DateTime.UtcNow;
                if (!string.IsNullOrWhiteSpace(notes)) entity.Notes = JoinNotes(entity.Notes, notes);
                await _context.SaveChangesAsync();
                return Map(entity);
            }));

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

            var hasPendingAccounting = _ordersContext != null && ids.Length > 0 && await _ordersContext.Orders
                .AnyAsync(x => x.AccountingStatus == OrderAccountingStatus.PendingAccounting &&
                               x.OrderDetails.Any(d => ids.Contains(d.MerchantId)));

            return new SettlementBalanceDto
            {
                GrossAmount = gross,
                PendingAmount = active,
                AvailableAmount = hasPendingAccounting ? 0m : Math.Max(0m, gross - active),
                Currency = currency,
                HasPendingRequest = active > 0m,
                HasPendingAccountingOrders = hasPendingAccounting
            };
        }

        public Task<SettlementRequestDto> CreateCaptainRequestAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request) =>
            _safety.WithDriverLockAsync(userId, () => InFinancialTransactionAsync(() => CreateCaptainRequestCoreAsync(userId, name, phone, request)));

        private async Task<SettlementRequestDto> CreateCaptainRequestCoreAsync(Guid userId, string name, string phone, CreateSettlementRequestDto request)
        {
            var currency = "SYP";
            var balance = await GetCaptainBalanceAsync(userId, currency);
            if (balance.HasPendingAccountingOrders)
                throw new InvalidOperationException("لا يمكن طلب تسوية مالية للمندوب لوجود طلبات مسلّمة معلقة لم تكتمل قيودها المحاسبية بعد.");
            if (balance.HasPendingRequest)
                throw new InvalidOperationException("يوجد طلب تسوية قيد المراجعة بالفعل.");
            if (balance.GrossAmount <= 0m)
                throw new InvalidOperationException("لا توجد عهدة نقدية لتسويتها حالياً.");

            var isNetHandover = balance.WagesOffset > 0m && (request?.Method == "cash_to_admin_net" || (request?.Amount.HasValue == true && request.Amount.Value == balance.NetCashDue));
            var amount = isNetHandover && request?.Amount.HasValue == true
                ? request.Amount.Value
                : (isNetHandover ? balance.NetCashDue : (request?.Amount.HasValue == true && request.Amount.Value > 0 ? request.Amount.Value : balance.AvailableAmount));

            if (amount < 0m || (amount == 0m && !isNetHandover))
                throw new InvalidOperationException("يرجى إدخال مبلغ صحيح أكبر من الصفر.");
            if (amount > balance.AvailableAmount)
                throw new InvalidOperationException($"المبلغ المطلوب يتجاوز العهدة المتاحة ({balance.AvailableAmount:N0} {currency}).");

            var entity = NewRequest(SettlementPartyType.Captain, userId, name, phone, amount, currency, request);
            if (isNetHandover)
            {
                entity.Method = "cash_to_admin_net";
            }
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
            if (balance.HasPendingAccountingOrders)
                throw new InvalidOperationException("لا يمكن طلب تسوية مالية للمتجر لوجود طلبات مسلّمة معلقة لم تكتمل قيودها المحاسبية بعد.");
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
            WithRequestDriverLockAsync(requestId, () => InFinancialTransactionAsync(() => AcceptCoreAsync(requestId, adminId, notes)));

        private async Task<SettlementRequestDto> AcceptCoreAsync(Guid requestId, Guid adminId, string notes)
        {
            var entity = await TrackingQuery().FirstOrDefaultAsync(x => x.Id == requestId)
                ?? throw new InvalidOperationException("طلب التسوية غير موجود.");
            if (entity.Status == SettlementRequestStatus.Completed ||
                (entity.PartyType == SettlementPartyType.CaptainEarnings && entity.Status == SettlementRequestStatus.Approved))
                return Map(entity);
            if (entity.Status != SettlementRequestStatus.Pending)
                throw new InvalidOperationException("تمت معالجة طلب التسوية مسبقاً.");

            if (entity.PartyType == SettlementPartyType.CaptainEarnings)
            {
                var earnings = await GetCaptainEarningsAsync(entity.RequestedByUserId, entity.Currency);
                if (earnings.HasPendingAccountingOrders || earnings.GrossAmount < entity.Amount)
                    throw new InvalidOperationException("الرصيد غير كافٍ أو توجد قيود محاسبية معلقة. لم تتم الموافقة.");
            }

            if (entity.PartyType == SettlementPartyType.Captain)
            {
                var position = await _safety.GetPositionAsync(entity.RequestedByUserId,
                    excludeHandoverId: entity.Id, currency: entity.Currency);
                if (position.HasUnfinishedAccounting)
                    throw new InvalidOperationException("لا يمكن اعتماد تسوية المندوب لوجود طلبات مسلّمة معلقة للمندوب قيد المعالجة المحاسبية.");

                if (position.SpendableCash < entity.Amount)
                    throw new InvalidOperationException("المبلغ محجوز لطلبات شراء أو تسوية أخرى. أكملها قبل تسليم العهدة.");

                var currentFloat = await _ledger.GetUserCashFloatBalanceAsync(entity.RequestedByUserId, entity.Currency);
                if (currentFloat + 0.001m < entity.Amount)
                    throw new InvalidOperationException($"عهدة المندوب الحالية ({currentFloat:N0} {entity.Currency}) أقل من المبلغ المطلوب تسويته ({entity.Amount:N0} {entity.Currency}).");

                var captainFloat = await _ledger.GetOrCreateUserAccountAsync(entity.RequestedByUserId, AccountType.Asset,
                    SystemAccountCodes.CaptainCashFloatPrefix, $"Cash Float - {entity.RequestedByName}", entity.Currency);
                var vault = await _ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault", AccountType.Asset, entity.Currency);

                // Smart netting: If this is a net handover request, offset driver wages up to the difference
                var wagesToOffset = 0m;
                Account wagesAcc = null;
                if (entity.Method == "cash_to_admin_net")
                {
                    wagesAcc = await _ledger.GetOrCreateUserAccountAsync(entity.RequestedByUserId, AccountType.Liability,
                        SystemAccountCodes.CaptainEarningsPrefix, $"Earnings - {entity.RequestedByName}", entity.Currency);
                    var wagesBal = await _ledger.GetAccountBalanceAsync(wagesAcc.Id);
                    wagesToOffset = Math.Min(currentFloat - entity.Amount, Math.Max(0m, wagesBal));
                }
                var totalFloatToClear = entity.Amount + wagesToOffset;

                var entries = new List<PostLedgerEntryRequest>();
                if (entity.Amount > 0m)
                {
                    entries.Add(new() { AccountId = vault.Id, Debit = entity.Amount, Currency = entity.Currency, Memo = $"Cash received for {entity.RequestNumber}" });
                }

                if (wagesToOffset > 0m)
                {
                    entries.Add(new PostLedgerEntryRequest
                    {
                        AccountId = wagesAcc.Id,
                        Debit = wagesToOffset,
                        Currency = entity.Currency,
                        Memo = $"Driver earnings offset against custody for {entity.RequestNumber}"
                    });
                }

                entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = captainFloat.Id,
                    Credit = totalFloatToClear,
                    Currency = entity.Currency,
                    Memo = $"Captain custody cleared by {entity.RequestNumber}"
                });

                var txn = await _ledger.PostTransactionAsync(new PostTransactionRequest
                {
                    ReferenceType = "CaptainSettlementRequest",
                    ReferenceId = entity.Id.ToString(),
                    IdempotencyKey = $"CaptainSettlementRequest-{entity.Id}",
                    Description = $"Cash received from captain {entity.RequestedByName}" + (wagesToOffset > 0m ? $" (wages offset: {wagesToOffset:N2} {entity.Currency})" : ""),
                    Entries = entries
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
            if (entity.Status != SettlementRequestStatus.Pending &&
                !(entity.PartyType == SettlementPartyType.CaptainEarnings && entity.Status == SettlementRequestStatus.Approved))
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

            if (_ordersContext != null && entity.MerchantAllocations.Any())
            {
                var allocMerchantIds = entity.MerchantAllocations.Select(a => a.MerchantId).Distinct().ToArray();
                if (await _ordersContext.Orders.AnyAsync(x => x.AccountingStatus == OrderAccountingStatus.PendingAccounting && x.OrderDetails.Any(d => allocMerchantIds.Contains(d.MerchantId))))
                {
                    throw new InvalidOperationException("لا يمكن صرف تسوية المتجر لوجود طلبات مسلّمة معلقة للمتجر قيد المعالجة المحاسبية.");
                }
            }

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
            if (!_context.Database.IsRelational() || _context.Database.CurrentTransaction != null)
                return await action();

            await using var transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var result = await action();
            await transaction.CommitAsync();
            return result;
        }

        private async Task<T> WithRequestDriverLockAsync<T>(Guid requestId, Func<Task<T>> action)
        {
            var request = await _context.SettlementRequests.AsNoTracking().FirstOrDefaultAsync(x => x.Id == requestId);
            if (request == null || request.PartyType == SettlementPartyType.Merchant) return await action();
            return await _safety.WithDriverLockAsync(request.RequestedByUserId, action);
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
