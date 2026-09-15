using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class EodReconciliationServiceTests
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
        public async Task SettleCaptainShiftAsync_ExactCash_ClearsBalancesAndRemitsToVault()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var captainId = Guid.NewGuid();

            // 1. Deliver an order: Float = 115,000, Wages = 15,000, Net Due = 100,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7001,
                CaptainUserId = captainId,
                CaptainName = "Samer Courier",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 5,
                        MerchantTitle = "Tasty Food",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            });

            // 2. Courier hands over exact 100,000 SYP to accountant
            var request = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 100000m,
                Currency = "SYP",
                Notes = "End of evening shift"
            };

            var adminId = Guid.NewGuid();
            var result = await eodService.SettleCaptainShiftAsync(request, adminId);

            Assert.NotNull(result);
            Assert.Equal(100000m, result.PhysicalCashReceived);
            Assert.Equal(100000m, result.ExpectedNetCash);
            Assert.Equal(0m, result.DiscrepancyAmount);

            // Verify account balances after settlement
            var floatAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var wagesAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Wages");
            var vaultAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            var floatBal = await ledgerService.GetAccountBalanceAsync(floatAcc.Id);
            var wagesBal = await ledgerService.GetAccountBalanceAsync(wagesAcc.Id);
            var vaultBal = await ledgerService.GetAccountBalanceAsync(vaultAcc.Id);

            // Float & Wages cleared to 0
            Assert.Equal(0m, floatBal);
            Assert.Equal(0m, wagesBal);
            // Vault has the physical cash
            Assert.Equal(100000m, vaultBal);

            // Verify batch entity saved
            var batch = await context.DailySettlementBatches.FirstOrDefaultAsync(b => b.CaptainUserId == captainId);
            Assert.NotNull(batch);
            Assert.True(batch.IsLocked);
            Assert.Equal(100000m, batch.NetCashRemitted);
        }

        [Fact]
        public async Task SettleCaptainShiftAsync_CashShortage_PostsToShortageExpense()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var captainId = Guid.NewGuid();

            // Order delivered: Float = 115,000, Wages = 15,000, Expected Net = 100,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7002,
                CaptainUserId = captainId,
                CaptainName = "Samer Courier",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 5,
                        MerchantTitle = "Tasty Food",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            });

            // Courier is short by 5,000: hands over 95,000
            var request = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 95000m,
                Currency = "SYP",
                Notes = "Lost 5000 change",
                DiscrepancyReason = "Lost cash change during run"
            };

            var result = await eodService.SettleCaptainShiftAsync(request, Guid.NewGuid());

            Assert.Equal(-5000m, result.DiscrepancyAmount);
            Assert.Equal(95000m, result.PhysicalCashReceived);

            var floatAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var wagesAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Wages");
            var vaultAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            var shortageAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashShortageExpense, "Shortage", AccountType.Expense);

            Assert.Equal(0m, await ledgerService.GetAccountBalanceAsync(floatAcc.Id));
            Assert.Equal(0m, await ledgerService.GetAccountBalanceAsync(wagesAcc.Id));
            Assert.Equal(95000m, await ledgerService.GetAccountBalanceAsync(vaultAcc.Id));
            // Cash shortage expense has 5000 debit balance
            Assert.Equal(5000m, await ledgerService.GetAccountBalanceAsync(shortageAcc.Id));
        }

        [Fact]
        public async Task SettleCaptainShiftAsync_CashOverage_PostsToOverageRevenue()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var captainId = Guid.NewGuid();

            // Expected Net = 100,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7003,
                CaptainUserId = captainId,
                CaptainName = "Samer Courier",
                DeliveryFee = 15000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 5,
                        MerchantTitle = "Tasty Food",
                        TotalAmount = 100000m,
                        MerchantAmount = 90000m,
                        PlatformCommission = 10000m
                    }
                }
            });

            // Courier hands over 103,000 (Overage of 3,000)
            var request = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 103000m,
                Currency = "SYP",
                Notes = "Tip retained or extra customer cash",
                DiscrepancyReason = "Customer tip handed to company"
            };

            var result = await eodService.SettleCaptainShiftAsync(request, Guid.NewGuid());

            Assert.Equal(3000m, result.DiscrepancyAmount);

            var vaultAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            var overageAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashOverageRevenue, "Overage", AccountType.Revenue);

            Assert.Equal(103000m, await ledgerService.GetAccountBalanceAsync(vaultAcc.Id));
            Assert.Equal(3000m, await ledgerService.GetAccountBalanceAsync(overageAcc.Id));
        }

        [Fact]
        public async Task GetFleetSettlementSummariesAsync_AggregatesFleetCorrectly()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var cap1 = Guid.NewGuid();
            var cap2 = Guid.NewGuid();

            // Cap 1: Float 50,000, Wages 5,000 -> Net 45,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7010,
                CaptainUserId = cap1,
                CaptainName = "Captain Alpha",
                DeliveryFee = 5000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 1, MerchantTitle = "Shop", TotalAmount = 45000m, MerchantAmount = 40000m, PlatformCommission = 5000m }
                }
            });

            // Cap 2: Float 80,000, Wages 10,000 -> Net 70,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7011,
                CaptainUserId = cap2,
                CaptainName = "Captain Beta",
                DeliveryFee = 10000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 1, MerchantTitle = "Shop", TotalAmount = 70000m, MerchantAmount = 60000m, PlatformCommission = 10000m }
                }
            });

            var summaries = await eodService.GetFleetSettlementSummariesAsync();

            Assert.Equal(2, summaries.Count);
            // Cap 2 has higher float, so appears first
            Assert.Equal(cap2, summaries[0].CaptainUserId);
            Assert.Equal(80000m, summaries[0].CashFloatBalance);
            Assert.Equal(10000m, summaries[0].WagesEarnedBalance);
            Assert.Equal(70000m, summaries[0].ExpectedNetCashDue);

            Assert.Equal(cap1, summaries[1].CaptainUserId);
            Assert.Equal(50000m, summaries[1].CashFloatBalance);
            Assert.Equal(5000m, summaries[1].WagesEarnedBalance);
            Assert.Equal(45000m, summaries[1].ExpectedNetCashDue);
        }

        [Fact]
        public async Task SettleCaptainShiftAsync_WhenWagesExceedFloat_OffsetsUpToFloatWithoutCorruptingVault()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var captainId = Guid.NewGuid();

            // 1. Order delivered: Float = 5,000, Wages = 5,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7020,
                CaptainUserId = captainId,
                CaptainName = "Courier Wages High",
                DeliveryFee = 5000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 1, MerchantTitle = "Shop", TotalAmount = 0m, MerchantAmount = 0m, PlatformCommission = 0m }
                }
            });

            // 2. Extra 10,000 bonus wage credited (Float stays 5,000, Wages becomes 15,000)
            var wagesAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Wages");
            var expenseAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.OperationalExpense, "Bonus", AccountType.Expense);
            await ledgerService.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "DriverBonus",
                ReferenceId = "BONUS-1",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = expenseAcc.Id, Debit = 10000m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = wagesAcc.Id, Debit = 0m, Credit = 10000m }
                }
            });

            // Courier hands in 0 cash
            var request = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 0m,
                Currency = "SYP",
                Notes = "Courier retained entire 5000 float against 15000 wage"
            };

            var result = await eodService.SettleCaptainShiftAsync(request, Guid.NewGuid());

            Assert.Equal(0m, result.ExpectedNetCash);
            Assert.Equal(0m, result.DiscrepancyAmount);

            var floatAcc = await ledgerService.GetOrCreateUserAccountAsync(captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");

            // Float cleared to 0
            Assert.Equal(0m, await ledgerService.GetAccountBalanceAsync(floatAcc.Id));
            // 10,000 unpaid wages remain safely in the earnings account
            Assert.Equal(10000m, await ledgerService.GetAccountBalanceAsync(wagesAcc.Id));
        }

        [Fact]
        public async Task SettleCaptainShiftAsync_WhenZeroFloatAndZeroCash_ThrowsDescriptiveException()
        {
            using var context = CreateInMemoryContext();
            var ledgerService = new LedgerService(context, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(context, ledgerService, null, NullLogger<EodReconciliationService>.Instance);

            var captainId = Guid.NewGuid();

            var request = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 0m,
                Currency = "SYP"
            };

            await Assert.ThrowsAsync<InvalidOperationException>(() => eodService.SettleCaptainShiftAsync(request, Guid.NewGuid()));
        }
    }
}
