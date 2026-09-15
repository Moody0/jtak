using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using App.Shared.Entities;
using App.Shared.Entities.Enums;

namespace Modules.Accounting.Services
{
    public class EodReconciliationService : IEodReconciliationService
    {
        private readonly AccountingDbContext _context;
        private readonly ILedgerService _ledgerService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger<EodReconciliationService> _logger;

        public EodReconciliationService(
            AccountingDbContext context,
            ILedgerService ledgerService,
            UserManager<AppUser> userManager,
            ILogger<EodReconciliationService> logger)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _ledgerService = ledgerService ?? throw new ArgumentNullException(nameof(ledgerService));
            _userManager = userManager;
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<List<CaptainSettlementSummaryDto>> GetFleetSettlementSummariesAsync()
        {
            var list = new List<CaptainSettlementSummaryDto>();
            var captainInfoMap = new Dictionary<Guid, (string Name, string Phone)>();

            if (_userManager != null)
            {
                try
                {
                    var users = await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString());
                    foreach (var u in users)
                    {
                        captainInfoMap[u.Id] = (u.FullName ?? u.UserName, u.PhoneNumber);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not load delivery users from UserManager. Falling back to account codes.");
                }
            }

            var captainFloatAccounts = await _context.Accounts
                .Where(a => a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))
                .ToListAsync();

            foreach (var acc in captainFloatAccounts)
            {
                if (acc.OwnerUserId.HasValue && !captainInfoMap.ContainsKey(acc.OwnerUserId.Value))
                {
                    captainInfoMap[acc.OwnerUserId.Value] = (acc.Name, null);
                }
            }

            foreach (var kvp in captainInfoMap)
            {
                var cid = kvp.Key;
                var (name, phone) = kvp.Value;

                var floatAcc = await _context.Accounts.FirstOrDefaultAsync(a =>
                    a.OwnerUserId == cid &&
                    a.Type == AccountType.Asset &&
                    a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));

                var wagesAcc = await _context.Accounts.FirstOrDefaultAsync(a =>
                    a.OwnerUserId == cid &&
                    a.Type == AccountType.Liability &&
                    a.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix));

                decimal floatBal = 0m;
                if (floatAcc != null)
                {
                    floatBal = await _ledgerService.GetAccountBalanceAsync(floatAcc.Id);
                }

                decimal wagesBal = 0m;
                if (wagesAcc != null)
                {
                    wagesBal = await _ledgerService.GetAccountBalanceAsync(wagesAcc.Id);
                }

                var lastBatch = await _context.DailySettlementBatches
                    .Where(b => b.CaptainUserId == cid)
                    .OrderByDescending(b => b.BatchDate)
                    .FirstOrDefaultAsync();

                var orderCount = floatAcc != null
                    ? await _context.LedgerEntries.CountAsync(e => e.AccountId == floatAcc.Id && e.Debit > 0)
                    : 0;

                list.Add(new CaptainSettlementSummaryDto
                {
                    CaptainUserId = cid,
                    CaptainName = name,
                    PhoneNumber = phone,
                    CashFloatBalance = floatBal,
                    WagesEarnedBalance = wagesBal,
                    ExpectedNetCashDue = floatBal - wagesBal,
                    Currency = floatAcc?.Currency ?? "SYP",
                    LastSettlementDate = lastBatch?.BatchDate,
                    TotalDeliveredOrders = orderCount
                });
            }

            return list.OrderByDescending(x => x.CashFloatBalance).ToList();
        }

        public async Task<CaptainShiftDetailsDto> GetCaptainShiftDetailsAsync(Guid captainUserId)
        {
            var floatAcc = await _context.Accounts.FirstOrDefaultAsync(a =>
                a.OwnerUserId == captainUserId &&
                a.Type == AccountType.Asset &&
                a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));

            var wagesAcc = await _context.Accounts.FirstOrDefaultAsync(a =>
                a.OwnerUserId == captainUserId &&
                a.Type == AccountType.Liability &&
                a.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix));

            decimal floatBal = floatAcc != null ? await _ledgerService.GetAccountBalanceAsync(floatAcc.Id) : 0m;
            decimal wagesBal = wagesAcc != null ? await _ledgerService.GetAccountBalanceAsync(wagesAcc.Id) : 0m;

            string captainName = floatAcc?.Name ?? $"Captain {captainUserId}";
            if (_userManager != null)
            {
                var user = await _userManager.FindByIdAsync(captainUserId.ToString());
                if (user != null) captainName = user.FullName ?? user.UserName;
            }

            var lastBatch = await _context.DailySettlementBatches
                .Where(b => b.CaptainUserId == captainUserId)
                .OrderByDescending(b => b.BatchDate)
                .FirstOrDefaultAsync();

            var floatStmt = floatAcc != null ? await _ledgerService.GetAccountStatementAsync(floatAcc.Id) : new List<AccountStatementItemDto>();
            var wagesStmt = wagesAcc != null ? await _ledgerService.GetAccountStatementAsync(wagesAcc.Id) : new List<AccountStatementItemDto>();

            return new CaptainShiftDetailsDto
            {
                CaptainUserId = captainUserId,
                CaptainName = captainName,
                CashFloatBalance = floatBal,
                WagesEarnedBalance = wagesBal,
                ExpectedNetCashDue = floatBal - wagesBal,
                Currency = floatAcc?.Currency ?? "SYP",
                LastSettlementDate = lastBatch?.BatchDate,
                FloatStatement = floatStmt,
                EarningsStatement = wagesStmt
            };
        }

        public async Task<SettlementResultDto> SettleCaptainShiftAsync(SettleCaptainShiftRequest request, Guid handledByAdminId)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.CaptainUserId == Guid.Empty) throw new ArgumentException("CaptainUserId is required.", nameof(request));

            var currency = (request.Currency ?? "SYP").ToUpperInvariant();

            string captainName = $"Captain {request.CaptainUserId}";
            if (_userManager != null)
            {
                var user = await _userManager.FindByIdAsync(request.CaptainUserId.ToString());
                if (user != null) captainName = user.FullName ?? user.UserName;
            }

            // 1. Resolve Accounts
            var floatAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                request.CaptainUserId,
                AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix,
                $"Cash Float - {captainName}",
                currency);

            var wagesAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                request.CaptainUserId,
                AccountType.Liability,
                SystemAccountCodes.CaptainEarningsPrefix,
                $"Earnings - {captainName}",
                currency);

            var vaultAcc = await _ledgerService.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.CompanyMainVault,
                "Company Cash Vault",
                AccountType.Asset,
                currency);

            var floatBal = await _ledgerService.GetAccountBalanceAsync(floatAcc.Id);
            var wagesBal = await _ledgerService.GetAccountBalanceAsync(wagesAcc.Id);

            if (floatBal <= 0 && wagesBal <= 0 && request.PhysicalCashReceived <= 0)
            {
                throw new InvalidOperationException($"Captain {captainName} has zero cash float and zero wages balance to settle.");
            }

            var wagesToOffset = Math.Min(floatBal, Math.Max(0m, wagesBal));
            var expectedNetCash = floatBal - wagesToOffset;
            var discrepancy = request.PhysicalCashReceived - expectedNetCash;

            var txnRequest = new PostTransactionRequest
            {
                ReferenceType = "FleetSettlement",
                ReferenceId = request.CaptainUserId.ToString(),
                IdempotencyKey = $"Settlement-{request.CaptainUserId}-{DateTime.UtcNow:yyyyMMddHHmmss}",
                Description = $"EOD Fleet Settlement: Captain {captainName} remitted {request.PhysicalCashReceived:N2} {currency} (Expected: {expectedNetCash:N2}, Discrepancy: {discrepancy:N2})"
            };

            // Physical Cash received into Vault (Asset Debit)
            if (request.PhysicalCashReceived > 0)
            {
                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = vaultAcc.Id,
                    Debit = request.PhysicalCashReceived,
                    Credit = 0m,
                    Currency = currency,
                    Memo = $"Physical cash remitted to vault by captain {captainName}"
                });
            }

            // Clear Courier Wages Earned (Liability Debit)
            if (wagesToOffset > 0)
            {
                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = wagesAcc.Id,
                    Debit = wagesToOffset,
                    Credit = 0m,
                    Currency = currency,
                    Memo = $"Settling earned delivery wages for captain {captainName}"
                });
            }

            // Shortage: Cash shortage expense (Expense Debit)
            if (discrepancy < 0)
            {
                var shortageExpenseAcc = await _ledgerService.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.CashShortageExpense,
                    "Cash Shortage Expense",
                    AccountType.Expense,
                    currency);

                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = shortageExpenseAcc.Id,
                    Debit = Math.Abs(discrepancy),
                    Credit = 0m,
                    Currency = currency,
                    Memo = $"Cash shortage on shift settlement for captain {captainName}: {request.DiscrepancyReason ?? "Shortage"}"
                });
            }

            // Clear Courier Cash Float (Asset Credit)
            if (floatBal > 0)
            {
                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = floatAcc.Id,
                    Debit = 0m,
                    Credit = floatBal,
                    Currency = currency,
                    Memo = $"Clearing cash float in custody for captain {captainName}"
                });
            }

            // Overage: Cash overage revenue (Revenue Credit)
            if (discrepancy > 0)
            {
                var overageRevenueAcc = await _ledgerService.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.CashOverageRevenue,
                    "Cash Overage Revenue",
                    AccountType.Revenue,
                    currency);

                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = overageRevenueAcc.Id,
                    Debit = 0m,
                    Credit = discrepancy,
                    Currency = currency,
                    Memo = $"Cash surplus on shift settlement for captain {captainName}: {request.DiscrepancyReason ?? "Surplus"}"
                });
            }

            var txnDto = await _ledgerService.PostTransactionAsync(txnRequest);

            // Record Settlement Batch
            var batch = new DailySettlementBatch
            {
                Id = Guid.NewGuid(),
                BatchCode = $"BATCH-{DateTime.UtcNow:yyyyMMddHHmmss}-{request.CaptainUserId.ToString().Substring(0, 4).ToUpperInvariant()}",
                CaptainUserId = request.CaptainUserId,
                BatchDate = DateTime.UtcNow,
                TotalCashCollected = floatBal,
                TotalWagesEarned = wagesToOffset,
                NetCashRemitted = request.PhysicalCashReceived,
                DiscrepancyAmount = discrepancy,
                DiscrepancyReason = request.DiscrepancyReason,
                HandledByAdminId = handledByAdminId,
                SettlementTransactionId = txnDto.Id,
                Notes = request.Notes,
                IsLocked = true
            };

            _context.DailySettlementBatches.Add(batch);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Settled shift batch {BatchCode} for Captain {CaptainId} with discrepancy {Discrepancy:N2}",
                batch.BatchCode, request.CaptainUserId, discrepancy);

            return new SettlementResultDto
            {
                SettlementBatchId = batch.Id,
                BatchCode = batch.BatchCode,
                SettlementTransactionId = txnDto.Id,
                TransactionNumber = txnDto.TransactionNumber,
                CaptainUserId = request.CaptainUserId,
                CaptainName = captainName,
                TotalCashCollected = floatBal,
                TotalWagesEarned = wagesToOffset,
                ExpectedNetCash = expectedNetCash,
                PhysicalCashReceived = request.PhysicalCashReceived,
                DiscrepancyAmount = discrepancy,
                DiscrepancyReason = request.DiscrepancyReason,
                Notes = request.Notes,
                SettledAt = batch.BatchDate
            };
        }

        public async Task<List<DailySettlementBatchDto>> GetSettlementHistoryAsync(int count = 50)
        {
            var batches = await _context.DailySettlementBatches
                .OrderByDescending(b => b.BatchDate)
                .Take(count)
                .ToListAsync();

            var result = new List<DailySettlementBatchDto>();
            foreach (var b in batches)
            {
                string cName = $"Captain {b.CaptainUserId}";
                if (_userManager != null)
                {
                    var u = await _userManager.FindByIdAsync(b.CaptainUserId.ToString());
                    if (u != null) cName = u.FullName ?? u.UserName;
                }

                result.Add(new DailySettlementBatchDto
                {
                    Id = b.Id,
                    BatchCode = b.BatchCode,
                    CaptainUserId = b.CaptainUserId,
                    CaptainName = cName,
                    BatchDate = b.BatchDate,
                    TotalCashCollected = b.TotalCashCollected,
                    TotalWagesEarned = b.TotalWagesEarned,
                    NetCashRemitted = b.NetCashRemitted,
                    DiscrepancyAmount = b.DiscrepancyAmount,
                    DiscrepancyReason = b.DiscrepancyReason,
                    HandledByAdminId = b.HandledByAdminId,
                    SettlementTransactionId = b.SettlementTransactionId,
                    IsLocked = b.IsLocked,
                    Notes = b.Notes,
                    CreatedDate = b.CreatedDate
                });
            }
            return result;
        }
    }
}
