using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public class LedgerService : ILedgerService
    {
        private readonly AccountingDbContext _context;
        private readonly ILogger<LedgerService> _logger;

        public LedgerService(AccountingDbContext context, ILogger<LedgerService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public async Task<Account> GetOrCreateUserAccountAsync(
            Guid userId,
            AccountType type,
            string accountCodePrefix,
            string accountName,
            string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.OwnerUserId == userId &&
                                          a.Type == type &&
                                          a.AccountCode.StartsWith(accountCodePrefix) &&
                                          a.Currency == currency);

            if (account != null) return account;

            var codeSuffix = userId.ToString("N").ToUpperInvariant();
            var accountCode = $"{accountCodePrefix}{codeSuffix}";

            account = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = accountCode,
                Name = accountName,
                Type = type,
                Currency = currency,
                OwnerUserId = userId,
                IsActive = true
            };

            _context.Accounts.Add(account);
            await _context.SaveChangesAsync();
            return account;
        }

        public async Task<Account> GetOrCreateMerchantAccountAsync(
            int merchantId,
            string merchantName,
            string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.OwnerMerchantId == merchantId &&
                                          a.Type == AccountType.Liability &&
                                          a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix) &&
                                          a.Currency == currency);

            if (account != null) return account;

            var accountCode = $"{SystemAccountCodes.VendorPayablePrefix}{merchantId}";
            account = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = accountCode,
                Name = string.IsNullOrWhiteSpace(merchantName) ? $"Vendor #{merchantId}" : merchantName,
                Type = AccountType.Liability,
                Currency = currency,
                OwnerMerchantId = merchantId,
                IsActive = true
            };

            _context.Accounts.Add(account);
            await _context.SaveChangesAsync();
            return account;
        }

        public async Task<Account> GetOrCreateSystemAccountAsync(
            string accountCode,
            string accountName,
            AccountType type,
            string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.AccountCode == accountCode && a.Currency == currency);

            if (account != null) return account;

            account = new Account
            {
                Id = Guid.NewGuid(),
                AccountCode = accountCode,
                Name = accountName,
                Type = type,
                Currency = currency,
                IsActive = true
            };

            _context.Accounts.Add(account);
            await _context.SaveChangesAsync();
            return account;
        }

        public async Task<JournalTransactionDto> PostTransactionAsync(PostTransactionRequest request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));

            // 1. Idempotency Check
            if (!string.IsNullOrWhiteSpace(request.IdempotencyKey))
            {
                var existing = await _context.JournalTransactions
                    .Include(t => t.Entries)
                    .ThenInclude(e => e.Account)
                    .FirstOrDefaultAsync(t => t.IdempotencyKey == request.IdempotencyKey);

                if (existing != null)
                {
                    _logger.LogInformation("Idempotent replay for transaction {Key} - {Number}", request.IdempotencyKey, existing.TransactionNumber);
                    return MapToDto(existing);
                }
            }

            // 2. Structural Validation
            if (request.Entries == null || request.Entries.Count < 2)
            {
                throw new InvalidOperationException("A double-entry journal transaction must contain at least two entries (one debit and one credit).");
            }

            // 3. Entry Sanity Checks
            foreach (var entry in request.Entries)
            {
                if (entry.Debit < 0 || entry.Credit < 0)
                {
                    throw new InvalidOperationException("Negative debit or credit values are strictly prohibited in ledger entries.");
                }
                if (entry.Debit == 0 && entry.Credit == 0)
                {
                    throw new InvalidOperationException("A ledger entry must have either a non-zero debit or credit amount.");
                }
                if (entry.Debit > 0 && entry.Credit > 0)
                {
                    throw new InvalidOperationException("A single ledger entry cannot contain both debit and credit. Split into separate entries.");
                }
            }

            // 4. Validate accounts exist, are active, and match transaction currency
            var accountIds = request.Entries.Select(e => e.AccountId).Distinct().ToList();
            var accounts = await _context.Accounts.Where(a => accountIds.Contains(a.Id)).ToDictionaryAsync(a => a.Id);
            if (accounts.Count != accountIds.Count)
            {
                var missing = accountIds.Where(id => !accounts.ContainsKey(id));
                throw new InvalidOperationException($"The following ledger account IDs do not exist: {string.Join(", ", missing)}");
            }

            var inactive = accounts.Values.Where(a => !a.IsActive).ToList();
            if (inactive.Any())
            {
                throw new InvalidOperationException($"Cannot post to inactive ledger accounts: {string.Join(", ", inactive.Select(a => a.AccountCode))}");
            }

            foreach (var entry in request.Entries)
            {
                var account = accounts[entry.AccountId];
                var entryCurrency = (entry.Currency ?? "SYP").ToUpperInvariant();
                if (!string.Equals(account.Currency, entryCurrency, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException($"Currency mismatch on account {account.AccountCode}. Account currency is {account.Currency}, but entry currency is {entryCurrency}.");
                }
            }

            // 5. Multi-Currency Balance Validation (sum(Debits) == sum(Credits) per currency)
            var currencyGroups = request.Entries.GroupBy(e => (e.Currency ?? "SYP").ToUpperInvariant());
            foreach (var group in currencyGroups)
            {
                var sumDebit = group.Sum(e => e.Debit);
                var sumCredit = group.Sum(e => e.Credit);
                if (Math.Abs(sumDebit - sumCredit) > 0.001m)
                {
                    throw new InvalidOperationException(
                        $"Unbalanced ledger transaction for currency {group.Key}. Total Debits = {sumDebit:N2}, Total Credits = {sumCredit:N2}. Net difference must be 0.00.");
                }
            }

            // 6. Create and Save Transaction
            var txnNumber = string.IsNullOrWhiteSpace(request.TransactionNumber)
                ? $"TXN-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N").Substring(0, 6).ToUpperInvariant()}"
                : request.TransactionNumber;

            var transaction = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = txnNumber,
                PostedDate = DateTime.UtcNow,
                ReferenceType = request.ReferenceType ?? "General",
                ReferenceId = request.ReferenceId ?? "0",
                IdempotencyKey = request.IdempotencyKey,
                Description = request.Description
            };

            foreach (var entry in request.Entries)
            {
                transaction.Entries.Add(new LedgerEntry
                {
                    JournalTransactionId = transaction.Id,
                    AccountId = entry.AccountId,
                    Debit = entry.Debit,
                    Credit = entry.Credit,
                    Currency = (entry.Currency ?? "SYP").ToUpperInvariant(),
                    Memo = entry.Memo
                });
            }

            _context.JournalTransactions.Add(transaction);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Posted balanced journal transaction {TxnNumber} with {Count} entries.", txnNumber, transaction.Entries.Count);
            return MapToDto(transaction);
        }

        public async Task<JournalTransactionDto> PostOrderDeliveredSplitAsync(OrderDeliveredSplitRequest request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.MerchantSplits == null || !request.MerchantSplits.Any())
            {
                throw new InvalidOperationException($"Cannot execute split for Order #{request.OrderId}: Merchant splits list is empty.");
            }

            var currency = (request.Currency ?? "SYP").ToUpperInvariant();
            var idempotencyKey = $"OrderDelivered-{request.OrderId}";

            // Idempotency check
            var existing = await _context.JournalTransactions
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .FirstOrDefaultAsync(t => t.IdempotencyKey == idempotencyKey);

            if (existing != null)
            {
                _logger.LogInformation("OrderDelivered split for Order #{OrderId} already posted. Returning existing transaction.", request.OrderId);
                return MapToDto(existing);
            }

            // 1. Resolve Accounts
            Account settlementAssetAcc;
            if (request.IsCod)
            {
                settlementAssetAcc = await GetOrCreateUserAccountAsync(
                    request.CaptainUserId,
                    AccountType.Asset,
                    SystemAccountCodes.CaptainCashFloatPrefix,
                    string.IsNullOrWhiteSpace(request.CaptainName) ? $"Captain Float {request.CaptainUserId}" : $"Cash Float - {request.CaptainName}",
                    currency);
            }
            else
            {
                settlementAssetAcc = await GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.ElectronicPaymentGateway,
                    "Electronic Payment Gateway",
                    AccountType.Asset,
                    currency);
            }

            var captainEarningsAcc = await GetOrCreateUserAccountAsync(
                request.CaptainUserId,
                AccountType.Liability,
                SystemAccountCodes.CaptainEarningsPrefix,
                string.IsNullOrWhiteSpace(request.CaptainName) ? $"Captain Wages {request.CaptainUserId}" : $"Earnings - {request.CaptainName}",
                currency);

            var platformRevenueAcc = await GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue,
                "Platform Commission Revenue",
                AccountType.Revenue,
                currency);

            var totalProductCash = request.MerchantSplits.Sum(m => m.TotalAmount);
            var grossCashCollected = totalProductCash + (request.TotalsIncludeDeliveryFee ? 0m : request.DeliveryFee);

            var txnRequest = new PostTransactionRequest
            {
                ReferenceType = "OrderDelivery",
                ReferenceId = request.OrderId.ToString(),
                IdempotencyKey = idempotencyKey,
                Description = request.IsCod
                    ? $"Order #{request.OrderId} COD delivery split across {request.MerchantSplits.Count} merchant(s)"
                    : $"Order #{request.OrderId} electronic payment delivery split across {request.MerchantSplits.Count} merchant(s)"
            };

            // 2. Debit Asset Account (Captain Cash Float for COD, or Electronic Payment Gateway for electronic/prepaid)
            txnRequest.Entries.Add(new PostLedgerEntryRequest
            {
                AccountId = settlementAssetAcc.Id,
                Debit = grossCashCollected,
                Credit = 0m,
                Currency = currency,
                Memo = request.IsCod
                    ? $"Order #{request.OrderId} gross cash in custody (liability to platform)"
                    : $"Order #{request.OrderId} electronic payment received via gateway"
            });

            // 3. Credit each Vendor for product value minus commission
            foreach (var split in request.MerchantSplits)
            {
                if (split.IsPlatformOwned)
                {
                    var marketSales = await GetOrCreateSystemAccountAsync(
                        SystemAccountCodes.JtakMarketSalesRevenue,
                        "JTAK Market Sales Revenue",
                        AccountType.Revenue,
                        currency);
                    var platformOwnedRevenue = split.TotalAmount - (request.TotalsIncludeDeliveryFee ? split.CaptainEarningAmount : 0m);
                    if (platformOwnedRevenue > 0)
                    {
                        txnRequest.Entries.Add(new PostLedgerEntryRequest
                        {
                            AccountId = marketSales.Id,
                            Debit = 0m,
                            Credit = platformOwnedRevenue,
                            Currency = currency,
                            Memo = $"Order #{request.OrderId} JTAK Market sale"
                        });
                    }
                    continue;
                }

                var vendorAcc = await GetOrCreateMerchantAccountAsync(
                    split.MerchantId,
                    split.MerchantTitle,
                    currency);

                if (split.MerchantAmount > 0)
                {
                    txnRequest.Entries.Add(new PostLedgerEntryRequest
                    {
                        AccountId = vendorAcc.Id,
                        Debit = 0m,
                        Credit = split.MerchantAmount,
                        Currency = currency,
                        Memo = $"Order #{request.OrderId} net payable to merchant #{split.MerchantId}"
                    });
                }
            }

            // 4. Credit Captain Earnings for delivery fee wage
            var captainEarnings = request.TotalsIncludeDeliveryFee
                ? request.MerchantSplits.Sum(x => x.CaptainEarningAmount)
                : request.DeliveryFee;
            if (captainEarnings > 0)
            {
                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = captainEarningsAcc.Id,
                    Debit = 0m,
                    Credit = captainEarnings,
                    Currency = currency,
                    Memo = $"Order #{request.OrderId} courier delivery wage"
                });
            }

            // 5. Credit Platform Revenue for total commissions (or Debit Promotional Discount Expense if negative)
            var totalPlatformCommission = request.MerchantSplits.Where(m => !m.IsPlatformOwned)
                .Sum(m => m.PlatformCommission - (request.TotalsIncludeDeliveryFee ? m.CaptainEarningAmount : 0m));
            if (totalPlatformCommission > 0)
            {
                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = platformRevenueAcc.Id,
                    Debit = 0m,
                    Credit = totalPlatformCommission,
                    Currency = currency,
                    Memo = $"Order #{request.OrderId} platform commission revenue"
                });
            }
            else if (totalPlatformCommission < 0)
            {
                var discountExpenseAcc = await GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.PromotionalDiscountExpense,
                    "Platform Promotional Discount Expense",
                    AccountType.Expense,
                    currency);

                txnRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = discountExpenseAcc.Id,
                    Debit = Math.Abs(totalPlatformCommission),
                    Credit = 0m,
                    Currency = currency,
                    Memo = $"Order #{request.OrderId} platform promotional subsidy expense"
                });
            }

            return await PostTransactionAsync(txnRequest);
        }

        public async Task<JournalTransactionDto> PostOrderCancellationReversalAsync(int orderId, string reason)
        {
            var originalIdempotencyKey = $"OrderDelivered-{orderId}";
            var reversalIdempotencyKey = $"OrderCancellationReversal-{orderId}";

            // Check if original transaction exists
            var originalTxn = await _context.JournalTransactions
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .FirstOrDefaultAsync(t => t.IdempotencyKey == originalIdempotencyKey);

            if (originalTxn == null)
            {
                _logger.LogInformation("No delivery journal transaction found for Order #{OrderId} to reverse.", orderId);
                return null;
            }

            // Check if reversal was already posted (idempotent)
            var existingReversal = await _context.JournalTransactions
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .FirstOrDefaultAsync(t => t.IdempotencyKey == reversalIdempotencyKey);

            if (existingReversal != null)
            {
                _logger.LogInformation("Reversal for Order #{OrderId} already posted. Returning existing transaction.", orderId);
                return MapToDto(existingReversal);
            }

            // Build compensating reverse transaction: Invert Debits and Credits
            var reversalRequest = new PostTransactionRequest
            {
                ReferenceType = "OrderCancellationReversal",
                ReferenceId = orderId.ToString(),
                IdempotencyKey = reversalIdempotencyKey,
                Description = $"Compensating reversal for Order #{orderId}: {reason ?? "Cancelled"}"
            };

            foreach (var entry in originalTxn.Entries)
            {
                reversalRequest.Entries.Add(new PostLedgerEntryRequest
                {
                    AccountId = entry.AccountId,
                    Debit = entry.Credit,   // Inverted
                    Credit = entry.Debit,  // Inverted
                    Currency = entry.Currency,
                    Memo = $"Reversal: {entry.Memo}"
                });
            }

            var result = await PostTransactionAsync(reversalRequest);
            _logger.LogInformation("Posted compensating reverse transaction {Number} for Order #{OrderId}.", result.TransactionNumber, orderId);
            return result;
        }

        public async Task<decimal> GetAccountBalanceAsync(Guid accountId)
        {
            var account = await _context.Accounts.FirstOrDefaultAsync(a => a.Id == accountId);
            if (account == null) return 0m;

            var sums = await _context.LedgerEntries
                .Where(e => e.AccountId == accountId)
                .GroupBy(e => 1)
                .Select(g => new
                {
                    Debits = g.Sum(x => x.Debit),
                    Credits = g.Sum(x => x.Credit)
                })
                .FirstOrDefaultAsync();

            var debits = sums?.Debits ?? 0m;
            var credits = sums?.Credits ?? 0m;

            // Asset & Expense normal balance: Debit - Credit
            // Liability, Equity, Revenue normal balance: Credit - Debit
            if (account.Type == AccountType.Asset || account.Type == AccountType.Expense)
            {
                return debits - credits;
            }
            return credits - debits;
        }

        public async Task<decimal> GetUserCashFloatBalanceAsync(Guid captainUserId, string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.OwnerUserId == captainUserId &&
                                          a.Type == AccountType.Asset &&
                                          a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix) &&
                                          a.Currency == currency);

            if (account == null) return 0m;
            return await GetAccountBalanceAsync(account.Id);
        }

        public async Task<decimal> GetUserEarningsBalanceAsync(Guid captainUserId, string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.OwnerUserId == captainUserId &&
                                          a.Type == AccountType.Liability &&
                                          a.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix) &&
                                          a.Currency == currency);

            if (account == null) return 0m;
            return await GetAccountBalanceAsync(account.Id);
        }

        public async Task<decimal> GetMerchantPayableBalanceAsync(int merchantId, string currency = "SYP")
        {
            currency = (currency ?? "SYP").ToUpperInvariant();
            var account = await _context.Accounts
                .FirstOrDefaultAsync(a => a.OwnerMerchantId == merchantId &&
                                          a.Type == AccountType.Liability &&
                                          a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix) &&
                                          a.Currency == currency);

            if (account == null) return 0m;
            return await GetAccountBalanceAsync(account.Id);
        }

        public async Task<List<AccountStatementItemDto>> GetAccountStatementAsync(
            Guid accountId,
            DateTime? fromDate = null,
            DateTime? toDate = null)
        {
            var account = await _context.Accounts.FirstOrDefaultAsync(a => a.Id == accountId);
            if (account == null) return new List<AccountStatementItemDto>();

            var query = _context.LedgerEntries
                .Include(e => e.Transaction)
                .Where(e => e.AccountId == accountId);

            if (fromDate.HasValue) query = query.Where(e => e.Transaction.PostedDate >= fromDate.Value);
            if (toDate.HasValue) query = query.Where(e => e.Transaction.PostedDate <= toDate.Value);

            var entries = await query
                .OrderBy(e => e.Transaction.PostedDate)
                .ThenBy(e => e.Id)
                .ToListAsync();

            var result = new List<AccountStatementItemDto>();
            decimal running = 0m;

            foreach (var e in entries)
            {
                if (account.Type == AccountType.Asset || account.Type == AccountType.Expense)
                {
                    running += (e.Debit - e.Credit);
                }
                else
                {
                    running += (e.Credit - e.Debit);
                }

                result.Add(new AccountStatementItemDto
                {
                    EntryId = e.Id,
                    TransactionId = e.JournalTransactionId,
                    TransactionNumber = e.Transaction?.TransactionNumber,
                    PostedDate = e.Transaction?.PostedDate ?? e.CreatedDate,
                    ReferenceType = e.Transaction?.ReferenceType,
                    ReferenceId = e.Transaction?.ReferenceId,
                    Debit = e.Debit,
                    Credit = e.Credit,
                    RunningBalance = running,
                    Currency = e.Currency,
                    Memo = e.Memo
                });
            }

            return result;
        }

        public async Task<JournalTransactionDto> PostGatewaySettlementToBankAsync(decimal amount, string providerReference = null, string currency = "SYP")
        {
            if (amount <= 0m) throw new ArgumentException("Amount must be greater than zero.", nameof(amount));
            currency = (currency ?? "SYP").ToUpperInvariant();

            var clearingAcc = await GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ElectronicPaymentGateway,
                "Payment Gateway Clearing",
                AccountType.Asset,
                currency);

            var bankAcc = await GetOrCreateSystemAccountAsync(
                SystemAccountCodes.BankMain,
                "Main Commercial Bank Account",
                AccountType.Asset,
                currency);

            var idempotencyKey = string.IsNullOrWhiteSpace(providerReference)
                ? $"PgwSettlement-{Guid.NewGuid()}"
                : $"PgwSettlement-{providerReference.Trim()}";

            var existing = await _context.JournalTransactions
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .FirstOrDefaultAsync(t => t.IdempotencyKey == idempotencyKey);

            if (existing != null)
            {
                return MapToDto(existing);
            }

            var request = new PostTransactionRequest
            {
                ReferenceType = "GatewaySettlement",
                ReferenceId = providerReference ?? "BankTransfer",
                IdempotencyKey = idempotencyKey,
                Description = $"Transfer from payment gateway clearing account to main bank account ({providerReference ?? "Batch"})",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new()
                    {
                        AccountId = bankAcc.Id,
                        Debit = amount,
                        Credit = 0m,
                        Currency = currency,
                        Memo = $"Funds received in bank from gateway settlement {providerReference}"
                    },
                    new()
                    {
                        AccountId = clearingAcc.Id,
                        Debit = 0m,
                        Credit = amount,
                        Currency = currency,
                        Memo = $"Clearing account credit for bank transfer {providerReference}"
                    }
                }
            };

            return await PostTransactionAsync(request);
        }

        public async Task SeedSystemAccountsAsync()
        {
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Company Cash Vault (Main Safe)", AccountType.Asset);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.BankMain, "Main Commercial Bank Account", AccountType.Asset);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.ElectronicPaymentGateway, "Payment Gateway Clearing", AccountType.Asset);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission Revenue", AccountType.Revenue);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "Platform Delivery Markup Revenue", AccountType.Revenue);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.OperationalExpense, "Platform Operational Expense", AccountType.Expense);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.PromotionalDiscountExpense, "Promotional Discounts & Subsidies", AccountType.Expense);
            await GetOrCreateSystemAccountAsync(SystemAccountCodes.JtakMarketSalesRevenue, "JTAK Market Sales Revenue", AccountType.Revenue);
        }

        private static JournalTransactionDto MapToDto(JournalTransaction t)
        {
            return new JournalTransactionDto
            {
                Id = t.Id,
                TransactionNumber = t.TransactionNumber,
                PostedDate = t.PostedDate,
                ReferenceType = t.ReferenceType,
                ReferenceId = t.ReferenceId,
                IdempotencyKey = t.IdempotencyKey,
                Description = t.Description,
                Entries = t.Entries?.Select(e => new LedgerEntryDto
                {
                    Id = e.Id,
                    JournalTransactionId = e.JournalTransactionId,
                    AccountId = e.AccountId,
                    AccountCode = e.Account?.AccountCode,
                    AccountName = e.Account?.Name,
                    Debit = e.Debit,
                    Credit = e.Credit,
                    Currency = e.Currency,
                    Memo = e.Memo,
                    CreatedDate = e.CreatedDate
                }).ToList() ?? new List<LedgerEntryDto>()
            };
        }
    }
}
