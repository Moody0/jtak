using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class LedgerServiceTests
    {
        private AccountingDbContext CreateInMemoryContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;

            return new AccountingDbContext(options, null);
        }

        [Fact]
        public async Task PostTransaction_BalancedEntries_Succeeds()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var merchantId = 42;

            var captainFloatAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Captain Cash Float");
            var vendorAccount = await service.GetOrCreateMerchantAccountAsync(
                merchantId, "Al-Huda Supermarket");
            var captainEarningsAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Captain Wages Payable");
            var platformRevenueAccount = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission Revenue", AccountType.Revenue);

            var request = new PostTransactionRequest
            {
                ReferenceType = "OrderDelivery",
                ReferenceId = "1001",
                IdempotencyKey = "OrderDelivered-1001",
                Description = "Order #1001 delivery split",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = captainFloatAccount.Id, Debit = 115000m, Credit = 0m, Memo = "Cash collected" },
                    new PostLedgerEntryRequest { AccountId = vendorAccount.Id, Debit = 0m, Credit = 95000m, Memo = "Net vendor payable" },
                    new PostLedgerEntryRequest { AccountId = captainEarningsAccount.Id, Debit = 0m, Credit = 15000m, Memo = "Delivery fee wage" },
                    new PostLedgerEntryRequest { AccountId = platformRevenueAccount.Id, Debit = 0m, Credit = 5000m, Memo = "Platform commission" }
                }
            };

            var txn = await service.PostTransactionAsync(request);

            Assert.NotNull(txn);
            Assert.Equal(4, txn.Entries.Count);

            var floatBalance = await service.GetAccountBalanceAsync(captainFloatAccount.Id);
            var vendorBalance = await service.GetAccountBalanceAsync(vendorAccount.Id);
            var earningsBalance = await service.GetAccountBalanceAsync(captainEarningsAccount.Id);
            var revenueBalance = await service.GetAccountBalanceAsync(platformRevenueAccount.Id);

            Assert.Equal(115000m, floatBalance);
            Assert.Equal(95000m, vendorBalance);
            Assert.Equal(15000m, earningsBalance);
            Assert.Equal(5000m, revenueBalance);
        }

        [Fact]
        public async Task PostTransaction_UnbalancedEntries_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            var request = new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 100m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = 80m }
                }
            };

            await Assert.ThrowsAsync<InvalidOperationException>(() => service.PostTransactionAsync(request));
        }

        [Fact]
        public async Task PostTransaction_NegativeOrZero_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            var request = new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = -50m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = -50m }
                }
            };

            await Assert.ThrowsAsync<InvalidOperationException>(() => service.PostTransactionAsync(request));
        }

        [Fact]
        public async Task PostTransaction_NonExistentAccountId_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var fakeAccountId = Guid.NewGuid();

            var request = new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 100m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = fakeAccountId, Debit = 0m, Credit = 100m }
                }
            };

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => service.PostTransactionAsync(request));
            Assert.Contains("do not exist", ex.Message);
        }

        [Fact]
        public async Task PostTransaction_InactiveAccount_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            // Deactivate acc2
            acc2.IsActive = false;
            await context.SaveChangesAsync();

            var request = new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 100m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = 100m }
                }
            };

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => service.PostTransactionAsync(request));
            Assert.Contains("inactive ledger accounts", ex.Message);
        }

        [Fact]
        public async Task PostTransaction_CurrencyMismatch_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var accSyp = await service.GetOrCreateSystemAccountAsync("1001", "Acc SYP", AccountType.Asset, "SYP");
            var accUsd = await service.GetOrCreateSystemAccountAsync("2001", "Acc USD", AccountType.Liability, "USD");

            // Post USD to an account configured as SYP
            var request = new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = accSyp.Id, Debit = 100m, Credit = 0m, Currency = "USD" },
                    new PostLedgerEntryRequest { AccountId = accUsd.Id, Debit = 0m, Credit = 100m, Currency = "USD" }
                }
            };

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => service.PostTransactionAsync(request));
            Assert.Contains("Currency mismatch", ex.Message);
        }

        [Fact]
        public async Task GetUserBalances_DistinctAccountPrefixes_PicksCorrectAccount()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var userId = Guid.NewGuid();

            // Create both Captain Earnings and Customer Wallet for the SAME user (both are Liability!)
            var captainEarningsAcc = await service.GetOrCreateUserAccountAsync(
                userId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Captain Wages");
            var customerWalletAcc = await service.GetOrCreateUserAccountAsync(
                userId, AccountType.Liability, SystemAccountCodes.CustomerWalletPrefix, "Customer Wallet");

            var vault = await service.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            // Post 15,000 to Captain Earnings
            await service.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "Wage",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = vault.Id, Debit = 15000m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = captainEarningsAcc.Id, Debit = 0m, Credit = 15000m }
                }
            });

            // Post 50,000 to Customer Wallet
            await service.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "Deposit",
                ReferenceId = "2",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = vault.Id, Debit = 50000m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = customerWalletAcc.Id, Debit = 0m, Credit = 50000m }
                }
            });

            // Verify GetUserEarningsBalanceAsync returns 15,000 NOT 50,000!
            var earnings = await service.GetUserEarningsBalanceAsync(userId);
            Assert.Equal(15000m, earnings);

            // Verify Customer Wallet balance on its specific account ID is 50,000
            var walletBal = await service.GetAccountBalanceAsync(customerWalletAcc.Id);
            Assert.Equal(50000m, walletBal);
        }

        [Fact]
        public async Task PostTransaction_IdempotencyKey_ReturnsExistingWithoutDuplication()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            var request = new PostTransactionRequest
            {
                ReferenceType = "OrderDelivery",
                ReferenceId = "555",
                IdempotencyKey = "Idempotent-Key-555",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 500m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = 500m }
                }
            };

            var txn1 = await service.PostTransactionAsync(request);
            var txn2 = await service.PostTransactionAsync(request);

            Assert.Equal(txn1.Id, txn2.Id);
            Assert.Equal(txn1.TransactionNumber, txn2.TransactionNumber);

            var totalEntries = await context.LedgerEntries.CountAsync();
            Assert.Equal(2, totalEntries);
        }

        [Fact]
        public async Task ImmutabilityInterceptor_BlocksUpdateOnLedgerEntry()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            await service.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 100m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = 100m }
                }
            });

            var entry = await context.LedgerEntries.FirstAsync();
            entry.Debit = 999m;

            await Assert.ThrowsAsync<InvalidOperationException>(() => context.SaveChangesAsync());
        }

        [Fact]
        public async Task ImmutabilityInterceptor_BlocksDeleteOnLedgerEntry()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var acc1 = await service.GetOrCreateSystemAccountAsync("1001", "Acc 1", AccountType.Asset);
            var acc2 = await service.GetOrCreateSystemAccountAsync("2001", "Acc 2", AccountType.Liability);

            await service.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "Test",
                ReferenceId = "1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = acc1.Id, Debit = 100m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = acc2.Id, Debit = 0m, Credit = 100m }
                }
            });

            var entry = await context.LedgerEntries.FirstAsync();
            context.LedgerEntries.Remove(entry);

            await Assert.ThrowsAsync<InvalidOperationException>(() => context.SaveChangesAsync());
        }

        [Fact]
        public async Task PostOrderDeliveredSplitAsync_SingleMerchant_CorrectlySplitsRevenueAndBalances()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 5001,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 10,
                        MerchantTitle = "Al-Sultan Sweets",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            };

            var txn = await service.PostOrderDeliveredSplitAsync(request);

            Assert.NotNull(txn);
            Assert.Equal(4, txn.Entries.Count);

            // Captain Cash Float balance = 115,000 SYP (Debits - gross cash collected)
            var floatAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var floatBalance = await service.GetAccountBalanceAsync(floatAccount.Id);
            Assert.Equal(115000m, floatBalance);

            // Merchant Payable balance = 90,000 SYP (Credits - net owed to merchant)
            var merchantAccount = await service.GetOrCreateMerchantAccountAsync(10, "Al-Sultan Sweets");
            var merchantBalance = await service.GetAccountBalanceAsync(merchantAccount.Id);
            Assert.Equal(90000m, merchantBalance);

            // Captain Earnings balance = 15,000 SYP (Credits - delivery wages owed to captain)
            var earningsAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Earnings");
            var earningsBalance = await service.GetAccountBalanceAsync(earningsAccount.Id);
            Assert.Equal(15000m, earningsBalance);

            // Platform Revenue balance = 10,000 SYP (Credits - platform commission)
            var revenueAccount = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission", AccountType.Revenue);
            var revenueBalance = await service.GetAccountBalanceAsync(revenueAccount.Id);
            Assert.Equal(10000m, revenueBalance);
        }

        [Fact]
        public async Task PostOrderDeliveredSplitAsync_MultiMerchant_AggregatesAndBalances()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 5002,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 20000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 11,
                        MerchantTitle = "Baker's Choice",
                        TotalAmount = 50000m,
                        MerchantAmount = 45000m,
                        PlatformCommission = 5000m
                    },
                    new MerchantSplitItem
                    {
                        MerchantId = 12,
                        MerchantTitle = "Green Grocer",
                        TotalAmount = 70000m,
                        MerchantAmount = 60000m,
                        PlatformCommission = 10000m
                    }
                }
            };

            var txn = await service.PostOrderDeliveredSplitAsync(request);

            Assert.NotNull(txn);
            // 1 Float Debit + 2 Merchant Credits + 1 Earnings Credit + 1 Revenue Credit = 5 entries
            Assert.Equal(5, txn.Entries.Count);

            var floatAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var floatBalance = await service.GetAccountBalanceAsync(floatAccount.Id);
            // Gross cash collected = 50000 + 70000 + 20000 = 140,000
            Assert.Equal(140000m, floatBalance);

            var revenueAccount = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission", AccountType.Revenue);
            var revenueBalance = await service.GetAccountBalanceAsync(revenueAccount.Id);
            // Commission = 5000 + 10000 = 15,000
            Assert.Equal(15000m, revenueBalance);
        }

        [Fact]
        public async Task PostOrderDeliveredSplitAsync_Idempotency_ReturnsExistingTransaction()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 5003,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 10000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 10,
                        MerchantTitle = "Al-Sultan",
                        TotalAmount = 50000m,
                        MerchantAmount = 45000m,
                        PlatformCommission = 5000m
                    }
                }
            };

            var txn1 = await service.PostOrderDeliveredSplitAsync(request);
            var txn2 = await service.PostOrderDeliveredSplitAsync(request);

            Assert.Equal(txn1.Id, txn2.Id);
            Assert.Equal(txn1.TransactionNumber, txn2.TransactionNumber);

            // Entries count in database should remain 4, not 8
            var entryCount = await context.LedgerEntries.CountAsync();
            Assert.Equal(4, entryCount);
        }

        [Fact]
        public async Task PostOrderCancellationReversalAsync_DeliveredOrder_RestoresZeroBalances()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 5004,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 10,
                        MerchantTitle = "Al-Sultan Sweets",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            };

            // 1. Deliver
            await service.PostOrderDeliveredSplitAsync(request);

            // 2. Cancel and reverse
            var reversalTxn = await service.PostOrderCancellationReversalAsync(5004, "Customer rejected order upon delivery");

            Assert.NotNull(reversalTxn);
            Assert.Equal("OrderCancellationReversal", reversalTxn.ReferenceType);
            Assert.Equal(4, reversalTxn.Entries.Count);

            // All account balances must now be exactly 0.00
            var floatAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var merchantAccount = await service.GetOrCreateMerchantAccountAsync(10, "Al-Sultan Sweets");
            var earningsAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Earnings");
            var revenueAccount = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission", AccountType.Revenue);

            Assert.Equal(0m, await service.GetAccountBalanceAsync(floatAccount.Id));
            Assert.Equal(0m, await service.GetAccountBalanceAsync(merchantAccount.Id));
            Assert.Equal(0m, await service.GetAccountBalanceAsync(earningsAccount.Id));
            Assert.Equal(0m, await service.GetAccountBalanceAsync(revenueAccount.Id));
        }

        [Fact]
        public async Task PostOrderCancellationReversalAsync_WhenNoDeliveryTxnExists_ReturnsNull()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var result = await service.PostOrderCancellationReversalAsync(99999, "Never delivered");
            Assert.Null(result);
        }

        [Fact]
        public async Task PostOrderDeliveredSplitAsync_NegativeCommission_BooksToPromotionalDiscountExpense()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 5005,
                CaptainUserId = captainId,
                CaptainName = "Ahmad Driver",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 10,
                        MerchantTitle = "Subsidized Merchant",
                        TotalAmount = 80000m,
                        MerchantAmount = 100000m,
                        PlatformCommission = -20000m // Platform promotional subsidy
                    }
                }
            };

            var txn = await service.PostOrderDeliveredSplitAsync(request);

            Assert.NotNull(txn);
            // 1 Float + 1 Merchant + 1 Earnings + 1 Promotional Discount Expense = 4 entries
            Assert.Equal(4, txn.Entries.Count);

            var subsidyAcc = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PromotionalDiscountExpense, "Promotional", AccountType.Expense);
            var merchantAcc = await service.GetOrCreateMerchantAccountAsync(10, "Subsidized Merchant");

            // Subsidy Expense has 20,000 debit balance
            Assert.Equal(20000m, await service.GetAccountBalanceAsync(subsidyAcc.Id));
            // Merchant gets full 100,000 credit
            Assert.Equal(100000m, await service.GetAccountBalanceAsync(merchantAcc.Id));
        }

        [Fact]
        public async Task PostOrderDeliveredSplitAsync_NonCod_DebitsElectronicPaymentGatewayAndCreditsMerchantsAndEarnings()
        {
            using var context = CreateInMemoryContext();
            var service = new LedgerService(context, NullLogger<LedgerService>.Instance);

            var captainId = Guid.NewGuid();
            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 7001,
                CaptainUserId = captainId,
                CaptainName = "Online Courier",
                DeliveryFee = 15000m,
                Currency = "SYP",
                IsCod = false, // Non-COD (Electronic payment / card / online)
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 20,
                        MerchantTitle = "Tech Store",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            };

            var txn = await service.PostOrderDeliveredSplitAsync(request);

            Assert.NotNull(txn);
            Assert.Equal(4, txn.Entries.Count);

            // Gross amount = 100,000 + 15,000 = 115,000
            // Electronic Payment Gateway should have a Debit balance of 115,000
            var gatewayAcc = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ElectronicPaymentGateway, "Electronic Payment Gateway", AccountType.Asset);
            var gatewayBalance = await service.GetAccountBalanceAsync(gatewayAcc.Id);
            Assert.Equal(115000m, gatewayBalance);

            // Captain Cash Float should be 0 because courier did NOT collect physical cash
            var floatAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var floatBalance = await service.GetAccountBalanceAsync(floatAccount.Id);
            Assert.Equal(0m, floatBalance);

            // Merchant Payable balance = 90,000 SYP
            var merchantAccount = await service.GetOrCreateMerchantAccountAsync(20, "Tech Store");
            var merchantBalance = await service.GetAccountBalanceAsync(merchantAccount.Id);
            Assert.Equal(90000m, merchantBalance);

            // Captain Earnings balance = 15,000 SYP
            var earningsAccount = await service.GetOrCreateUserAccountAsync(
                captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Earnings");
            var earningsBalance = await service.GetAccountBalanceAsync(earningsAccount.Id);
            Assert.Equal(15000m, earningsBalance);

            // Platform Commission Revenue = 10,000 SYP
            var revenueAccount = await service.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformCommissionRevenue, "Platform Commission", AccountType.Revenue);
            var revenueBalance = await service.GetAccountBalanceAsync(revenueAccount.Id);
            Assert.Equal(10000m, revenueBalance);
        }
    }
}
