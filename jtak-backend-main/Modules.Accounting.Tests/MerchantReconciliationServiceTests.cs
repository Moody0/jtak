using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Catalog.Data;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using CatalogMerchant = Modules.Catalog.Entities.Merchant;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class MerchantReconciliationServiceTests
    {
        private AccountingDbContext CreateInMemoryAccountingContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private CatalogDbContext CreateInMemoryCatalogContext()
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new CatalogDbContext(options, null);
        }

        private OrdersDbContext CreateInMemoryOrdersContext()
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        [Fact]
        public async Task Summary_AggregatesAuthoritativeLedgerBalances_Correctly()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            // 1. Seed Merchants
            var m1 = new CatalogMerchant { Id = 10, Title = "Al-Madina Grill", OwnerName = "Ahmad", Phone1 = "+963911111111", Active = true };
            var m2 = new CatalogMerchant { Id = 20, Title = "Fresh Bakery", OwnerName = "Kareem", Phone1 = "+963922222222", Active = true };
            var m3 = new CatalogMerchant { Id = 30, Title = "Inactive Store", OwnerName = "Hassan", Active = false }; // Inactive
            catalogDb.Merchants.AddRange(m1, m2, m3);
            await catalogDb.SaveChangesAsync();

            // 2. Post Orders through LedgerService
            // M1 Order: Gross 100,000, JTak 10,000, Net 90,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 1001,
                DeliveryFee = 5000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 10, MerchantTitle = "Al-Madina Grill", TotalAmount = 100000m, MerchantAmount = 90000m, PlatformCommission = 10000m }
                }
            });

            // M2 Order: Gross 50,000, JTak 5,000, Net 45,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 1002,
                DeliveryFee = 4000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 20, MerchantTitle = "Fresh Bakery", TotalAmount = 50000m, MerchantAmount = 45000m, PlatformCommission = 5000m }
                }
            });

            // 3. Create a Pending Settlement Request for M1 (20,000 SYP reserved)
            var req1 = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-TEST-001",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Pending,
                Amount = 20000m,
                Currency = "SYP",
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 10, MerchantTitle = "Al-Madina Grill", Amount = 20000m }
                }
            };
            accountingDb.SettlementRequests.Add(req1);
            await accountingDb.SaveChangesAsync();

            // 4. Get Summary
            var summary = await service.GetSummaryAsync();

            Assert.NotNull(summary);
            // Gross Payable: M1 (90,000) + M2 (45,000) = 135,000
            Assert.Equal(135000m, summary.TotalMerchantPayables);
            // Reserved: 20,000
            Assert.Equal(20000m, summary.TotalReservedSettlements);
            // Available: 135,000 - 20,000 = 115,000
            Assert.Equal(115000m, summary.TotalAvailableForSettlement);
            // JTak Share: 10,000 + 5,000 = 15,000
            Assert.Equal(15000m, summary.TotalJTakCommission);
            // Active Merchants: 2
            Assert.Equal(2, summary.ActiveMerchantsCount);
            // Pending Requests: 1
            Assert.Equal(1, summary.PendingRequestsCount);
        }

        [Fact]
        public async Task DataTable_PagingAndFiltering_CalculatesRealTimeFields()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            // 1. Seed 3 Active Merchants
            catalogDb.Merchants.AddRange(
                new CatalogMerchant { Id = 1, Title = "Al-Ameen Sweets", OwnerName = "Ameen", Phone1 = "+963911111", Active = true },
                new CatalogMerchant { Id = 2, Title = "Al-Baraka Market", OwnerName = "Baraka", Phone1 = "+963922222", Active = true },
                new CatalogMerchant { Id = 3, Title = "Crispy Chicken", OwnerName = "Tariq", Phone1 = "+963933333", Active = true }
            );
            await catalogDb.SaveChangesAsync();

            // 2. Post sales for Al-Ameen (ID 1): Gross 80,000, Net 72,000, JTak 8,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 2001,
                DeliveryFee = 5000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 1, MerchantTitle = "Al-Ameen Sweets", TotalAmount = 80000m, MerchantAmount = 72000m, PlatformCommission = 8000m }
                }
            });

            ordersDb.OrderDetails.Add(new OrderDetail
            {
                OrderId = 2001,
                MerchantId = 1,
                Quantity = 1,
                SingleFinalPrice = 80000m,
                SingleMerchantProfit = 72000m
            });
            await ordersDb.SaveChangesAsync();

            // 3. Add settlement reservation of 12,000 for Al-Ameen
            accountingDb.SettlementRequests.Add(new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-TEST-002",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Approved,
                Amount = 12000m,
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation { MerchantId = 1, MerchantTitle = "Al-Ameen Sweets", Amount = 12000m }
                }
            });
            await accountingDb.SaveChangesAsync();

            // 4. Query DataTable for "Al-Ameen"
            var searchResult = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest
            {
                Page = 1,
                PageSize = 10,
                SearchTerm = "Ameen"
            });

            Assert.NotNull(searchResult);
            Assert.Equal(1, searchResult.TotalRecords);
            Assert.Single(searchResult.Items);

            var item = searchResult.Items[0];
            Assert.Equal(1, item.MerchantId);
            Assert.Equal("Al-Ameen Sweets", item.MerchantName);
            Assert.Equal(80000m, item.GrossSales);
            Assert.Equal(8000m, item.JTakShare);
            Assert.Equal(72000m, item.MerchantNet);
            Assert.Equal(12000m, item.ReservedAmount);
            Assert.Equal(60000m, item.AvailableAmount); // 72,000 - 12,000
            Assert.Equal(72000m, item.CurrentBalance);
            Assert.Equal(SettlementRequestStatus.Approved, item.LastSettlementStatus);
        }

        [Fact]
        public async Task MerchantStatement_ChronologicalRunningBalance_WithNewestFirstOrdering()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            const int merchantId = 55;
            catalogDb.Merchants.Add(new CatalogMerchant { Id = merchantId, Title = "Sham Shawarma", Active = true });
            await catalogDb.SaveChangesAsync();

            var vendorAcc = await ledgerService.GetOrCreateMerchantAccountAsync(merchantId, "Sham Shawarma");
            var cashAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            // Day 1 (10:00 AM): Order 1 (+10,000 SYP Credit) -> Running Balance = 10,000
            var tx1 = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-001",
                PostedDate = new DateTime(2026, 9, 10, 10, 0, 0, DateTimeKind.Utc),
                ReferenceType = "Order",
                ReferenceId = "3001",
                Description = "Order #3001 sales credit",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = vendorAcc.Id, Credit = 10000m, Debit = 0m, Memo = "Vendor net credit" },
                    new LedgerEntry { AccountId = cashAcc.Id, Credit = 0m, Debit = 10000m, Memo = "Cash collected" }
                }
            };
            accountingDb.JournalTransactions.Add(tx1);

            // Day 2 (11:00 AM): Order 2 (+15,000 SYP Credit) -> Running Balance = 25,000
            var tx2 = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-002",
                PostedDate = new DateTime(2026, 9, 11, 11, 0, 0, DateTimeKind.Utc),
                ReferenceType = "Order",
                ReferenceId = "3002",
                Description = "Order #3002 sales credit",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = vendorAcc.Id, Credit = 15000m, Debit = 0m, Memo = "Vendor net credit" },
                    new LedgerEntry { AccountId = cashAcc.Id, Credit = 0m, Debit = 15000m, Memo = "Cash collected" }
                }
            };
            accountingDb.JournalTransactions.Add(tx2);

            // Day 3 (12:00 PM): Payout Settlement (-5,000 SYP Debit) -> Running Balance = 20,000
            var tx3 = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-003",
                PostedDate = new DateTime(2026, 9, 12, 12, 0, 0, DateTimeKind.Utc),
                ReferenceType = "SettlementRequest",
                ReferenceId = "SET-TEST-300",
                Description = "Settlement payout voucher SET-TEST-300",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = vendorAcc.Id, Credit = 0m, Debit = 5000m, Memo = "Vendor payout debit" },
                    new LedgerEntry { AccountId = cashAcc.Id, Credit = 5000m, Debit = 0m, Memo = "Vault credit" }
                }
            };
            accountingDb.JournalTransactions.Add(tx3);

            // Day 4 (01:00 PM): Order 3 (+8,000 SYP Credit) -> Running Balance = 28,000
            var tx4 = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-004",
                PostedDate = new DateTime(2026, 9, 13, 13, 0, 0, DateTimeKind.Utc),
                ReferenceType = "Order",
                ReferenceId = "3003",
                Description = "Order #3003 sales credit",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = vendorAcc.Id, Credit = 8000m, Debit = 0m, Memo = "Vendor net credit" },
                    new LedgerEntry { AccountId = cashAcc.Id, Credit = 0m, Debit = 8000m, Memo = "Cash collected" }
                }
            };
            accountingDb.JournalTransactions.Add(tx4);
            await accountingDb.SaveChangesAsync();

            // Fetch Statement
            var statement = await service.GetMerchantStatementAsync(merchantId, new MerchantStatementRequestDto());

            Assert.NotNull(statement);
            Assert.Equal(28000m, statement.CurrentBalance);
            Assert.Equal(4, statement.Items.Count);

            // Verify NEWEST-FIRST server ordering with exact chronological running balance:
            // Item 0: Day 4 (TXN-004) -> Credit 8,000, Debit 0, Running Balance = 28,000
            Assert.Equal("TXN-004", statement.Items[0].TransactionNumber);
            Assert.Equal(8000m, statement.Items[0].Credit);
            Assert.Equal(0m, statement.Items[0].Debit);
            Assert.Equal(28000m, statement.Items[0].RunningBalance);

            // Item 1: Day 3 (TXN-003) -> Credit 0, Debit 5,000, Running Balance = 20,000
            Assert.Equal("TXN-003", statement.Items[1].TransactionNumber);
            Assert.Equal(0m, statement.Items[1].Credit);
            Assert.Equal(5000m, statement.Items[1].Debit);
            Assert.Equal(20000m, statement.Items[1].RunningBalance);

            // Item 2: Day 2 (TXN-002) -> Credit 15,000, Debit 0, Running Balance = 25,000
            Assert.Equal("TXN-002", statement.Items[2].TransactionNumber);
            Assert.Equal(15000m, statement.Items[2].Credit);
            Assert.Equal(0m, statement.Items[2].Debit);
            Assert.Equal(25000m, statement.Items[2].RunningBalance);

            // Item 3: Day 1 (TXN-001) -> Credit 10,000, Debit 0, Running Balance = 10,000
            Assert.Equal("TXN-001", statement.Items[3].TransactionNumber);
            Assert.Equal(10000m, statement.Items[3].Credit);
            Assert.Equal(0m, statement.Items[3].Debit);
            Assert.Equal(10000m, statement.Items[3].RunningBalance);
        }

        [Fact]
        public async Task MerchantStatement_SearchByTransactionNumber_TXN()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            const int merchantId = 77;
            catalogDb.Merchants.Add(new CatalogMerchant { Id = merchantId, Title = "Damascus Market", Active = true });
            await catalogDb.SaveChangesAsync();

            var vendorAcc = await ledgerService.GetOrCreateMerchantAccountAsync(merchantId, "Damascus Market");
            var cashAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            accountingDb.JournalTransactions.AddRange(
                new JournalTransaction
                {
                    Id = Guid.NewGuid(),
                    TransactionNumber = "TXN-20260918-001A",
                    PostedDate = DateTime.UtcNow.AddHours(-2),
                    ReferenceType = "Order",
                    ReferenceId = "4001",
                    Description = "Normal order",
                    Entries = new List<LedgerEntry> { new LedgerEntry { AccountId = vendorAcc.Id, Credit = 5000m, Memo = "Vendor credit" } }
                },
                new JournalTransaction
                {
                    Id = Guid.NewGuid(),
                    TransactionNumber = "TXN-20260918-002B",
                    PostedDate = DateTime.UtcNow.AddHours(-1),
                    ReferenceType = "Order",
                    ReferenceId = "4002",
                    Description = "Target special movement",
                    Entries = new List<LedgerEntry> { new LedgerEntry { AccountId = vendorAcc.Id, Credit = 12000m, Memo = "Vendor credit" } }
                }
            );
            await accountingDb.SaveChangesAsync();

            // Search by exact TXN number
            var result = await service.GetMerchantStatementAsync(merchantId, new MerchantStatementRequestDto
            {
                SearchTerm = "TXN-20260918-002B"
            });

            Assert.NotNull(result);
            Assert.Single(result.Items);
            Assert.Equal("TXN-20260918-002B", result.Items[0].TransactionNumber);
            Assert.Equal(12000m, result.Items[0].Credit);
        }

        [Fact]
        public async Task LiveEquivalent_MeatStation_And_Settlement_SET20260917184759F27A32()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            const int meatStationId = 26;
            const string meatStationTitle = "محطة اللحوم";
            const string settlementReqNumber = "SET-20260917184759-F27A32";
            const decimal settlementAmount = 1125m;

            // 1. Seed Merchant "محطة اللحوم" (Production Merchant #26 -> 2010-VND-26)
            catalogDb.Merchants.Add(new CatalogMerchant
            {
                Id = meatStationId,
                Title = meatStationTitle,
                OwnerName = "Abu Samer",
                Phone1 = "+963955555555",
                Active = true
            });
            await catalogDb.SaveChangesAsync();

            // 2. Order Delivered: Gross 10,000 SYP, JTAK share 1,000 SYP, Net 9,000 SYP
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 5001,
                DeliveryFee = 3000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = meatStationId,
                        MerchantTitle = meatStationTitle,
                        TotalAmount = 10000m,
                        MerchantAmount = 9000m,
                        PlatformCommission = 1000m
                    }
                }
            });

            // 3. Settlement Request Created: Status = Pending (1,125 SYP)
            var settlementRequest = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = settlementReqNumber,
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Pending,
                Amount = settlementAmount,
                Currency = "SYP",
                Method = "حوالة سيريتل كاش",
                AccountDetails = "0955555555",
                CreatedDate = DateTime.UtcNow.AddHours(-3),
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation
                    {
                        MerchantId = meatStationId,
                        MerchantTitle = meatStationTitle,
                        Amount = settlementAmount
                    }
                }
            };
            accountingDb.SettlementRequests.Add(settlementRequest);
            await accountingDb.SaveChangesAsync();

            // --- PHASE 1: Verify Pending State ---
            var stmtPending = await service.GetMerchantStatementAsync(meatStationId, new MerchantStatementRequestDto());
            Assert.Equal(9000m, stmtPending.CurrentBalance);
            Assert.Equal(1125m, stmtPending.ReservedAmount);
            Assert.Equal(7875m, stmtPending.AvailableAmount); // 9,000 - 1,125
            Assert.Equal(0m, stmtPending.ApprovedAwaitingReceiptAmount);

            // --- PHASE 2: Status changed to Approved ---
            settlementRequest.Status = SettlementRequestStatus.Approved;
            settlementRequest.ReviewedAt = DateTime.UtcNow.AddHours(-2);
            await accountingDb.SaveChangesAsync();

            var stmtApproved = await service.GetMerchantStatementAsync(meatStationId, new MerchantStatementRequestDto());
            Assert.Equal(9000m, stmtApproved.CurrentBalance);
            Assert.Equal(1125m, stmtApproved.ReservedAmount);
            Assert.Equal(7875m, stmtApproved.AvailableAmount);
            Assert.Equal(1125m, stmtApproved.ApprovedAwaitingReceiptAmount);

            // --- PHASE 3: Completed Settlement Payout (Posting Debit to VendorPayable) ---
            var vendorAcc = await ledgerService.GetOrCreateMerchantAccountAsync(meatStationId, meatStationTitle);
            var vaultAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            var payoutTx = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-SET-PAYOUT-001",
                PostedDate = DateTime.UtcNow.AddMinutes(5),
                ReferenceType = "SettlementRequest",
                ReferenceId = settlementReqNumber,
                Description = $"تسوية مستحقات التاجر محطة اللحوم بموجب طلب التسوية {settlementReqNumber}",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = vendorAcc.Id, Debit = settlementAmount, Credit = 0m, Memo = "Vendor payout debit" },
                    new LedgerEntry { AccountId = vaultAcc.Id, Debit = 0m, Credit = settlementAmount, Memo = "Vault credit" }
                }
            };
            accountingDb.JournalTransactions.Add(payoutTx);

            settlementRequest.Status = SettlementRequestStatus.Completed;
            settlementRequest.CompletedAt = DateTime.UtcNow.AddMinutes(-30);
            settlementRequest.LedgerTransactionId = payoutTx.Id;
            await accountingDb.SaveChangesAsync();

            // --- PHASE 4: Verify Final Authoritative Balance & Statement ---
            var stmtCompleted = await service.GetMerchantStatementAsync(meatStationId, new MerchantStatementRequestDto());
            Assert.Equal(7875m, stmtCompleted.CurrentBalance); // 9,000 - 1,125 = 7,875
            Assert.Equal(0m, stmtCompleted.ReservedAmount);     // Completed clears reservation
            Assert.Equal(7875m, stmtCompleted.AvailableAmount);
            Assert.Equal(0m, stmtCompleted.ApprovedAwaitingReceiptAmount);

            // Statement has 2 transactions: Payout (Debit 1,125) and Order (Credit 9,000)
            Assert.Equal(2, stmtCompleted.Items.Count);
            // Latest is Payout
            Assert.Equal(1125m, stmtCompleted.Items[0].Debit);
            Assert.Equal(7875m, stmtCompleted.Items[0].RunningBalance);
            Assert.Equal(settlementReqNumber, stmtCompleted.Items[0].SettlementRequestNumber);
            Assert.Contains(settlementReqNumber, stmtCompleted.Items[0].Description);

            // Settlement History item is present
            Assert.Single(stmtCompleted.SettlementHistory);
            Assert.Equal(settlementReqNumber, stmtCompleted.SettlementHistory[0].RequestNumber);
            Assert.Equal(SettlementRequestStatus.Completed, stmtCompleted.SettlementHistory[0].Status);
            Assert.Equal(1125m, stmtCompleted.SettlementHistory[0].Amount);
        }

        [Fact]
        public async Task MerchantStatement_StrictIsolation_NoCrossMerchantDataLeakage()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            catalogDb.Merchants.AddRange(
                new CatalogMerchant { Id = 100, Title = "Store A", Active = true },
                new CatalogMerchant { Id = 200, Title = "Store B", Active = true }
            );
            await catalogDb.SaveChangesAsync();

            // Post Order for Store A
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 6001,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 100, MerchantTitle = "Store A", TotalAmount = 50000m, MerchantAmount = 45000m, PlatformCommission = 5000m }
                }
            });

            // Post Order for Store B
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 6002,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 200, MerchantTitle = "Store B", TotalAmount = 70000m, MerchantAmount = 63000m, PlatformCommission = 7000m }
                }
            });

            var stmtA = await service.GetMerchantStatementAsync(100, new MerchantStatementRequestDto());
            var stmtB = await service.GetMerchantStatementAsync(200, new MerchantStatementRequestDto());

            Assert.Equal(45000m, stmtA.CurrentBalance);
            Assert.Single(stmtA.Items);
            Assert.Equal("Store A", stmtA.MerchantName);

            Assert.Equal(63000m, stmtB.CurrentBalance);
            Assert.Single(stmtB.Items);
            Assert.Equal("Store B", stmtB.MerchantName);
        }

        [Fact]
        public async Task GetDataTableAsync_FullReconciliationContract_Merchant26_AllFieldsAndSearchVerified()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var catalogDb = CreateInMemoryCatalogContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var service = new MerchantReconciliationService(accountingDb, catalogDb, ordersDb, ledgerService, NullLogger<MerchantReconciliationService>.Instance);

            const int merchantId = 26;
            const string merchantTitle = "محطة اللحوم";
            const string phone = "+963955555526";

            // 1. Seed Merchant #26
            catalogDb.Merchants.Add(new CatalogMerchant
            {
                Id = merchantId,
                Title = merchantTitle,
                OwnerName = "Abu Samer Al-Laham",
                Phone1 = phone,
                Active = true
            });
            await catalogDb.SaveChangesAsync();

            // 2. Post Delivered Order
            ordersDb.OrderDetails.Add(new OrderDetail
            {
                Id = 9901,
                OrderId = 7001,
                MerchantId = merchantId,
                Quantity = 2,
                SinglePrice = 15000m,
                SingleFinalPrice = 15000m,
                SingleMerchantProfit = 13500m
            });
            await ordersDb.SaveChangesAsync();

            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 7001,
                DeliveryFee = 3000m,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = merchantId,
                        MerchantTitle = merchantTitle,
                        TotalAmount = 30000m,
                        MerchantAmount = 27000m,
                        PlatformCommission = 3000m
                    }
                }
            });

            // 3. Settlement Request with Approved Status (Awaiting Receipt)
            var settleReq = new SettlementRequest
            {
                Id = Guid.NewGuid(),
                RequestNumber = "SET-20260917-00026",
                PartyType = SettlementPartyType.Merchant,
                Status = SettlementRequestStatus.Approved,
                Amount = 5000m,
                Currency = "SYP",
                Method = "حوالة شام كاش",
                AccountDetails = "SHAM-2626",
                CreatedDate = DateTime.UtcNow.AddHours(-1),
                ReviewedAt = DateTime.UtcNow.AddMinutes(-30),
                ReviewedByAdminId = Guid.NewGuid(),
                MerchantAllocations = new List<SettlementRequestMerchantAllocation>
                {
                    new SettlementRequestMerchantAllocation
                    {
                        MerchantId = merchantId,
                        MerchantTitle = merchantTitle,
                        Amount = 5000m
                    }
                }
            };
            accountingDb.SettlementRequests.Add(settleReq);
            await accountingDb.SaveChangesAsync();

            // --- CONTRACT ASSERTION ON DATATABLE ROW ---
            var result = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest { Page = 1, PageSize = 10 });

            Assert.NotNull(result);
            Assert.Single(result.Items);
            var row = result.Items[0];

            // 1. Merchant Identity & Contact
            Assert.Equal(merchantId, row.MerchantId);
            Assert.Equal(merchantTitle, row.MerchantName);
            Assert.Equal("Abu Samer Al-Laham", row.OwnerName);
            Assert.Equal(phone, row.Phone);

            // 2. Orders & Financial Breakdown
            Assert.Equal(1, row.OrdersCount);
            Assert.Equal(30000m, row.GrossSales);
            Assert.Equal(3000m, row.JTakShare);
            Assert.Equal(27000m, row.MerchantNet);

            // 3. Balances, Reserved, Approved Awaiting, Available
            Assert.Equal(27000m, row.CurrentBalance); // 2010-VND-26 Ledger balance
            Assert.Equal(5000m, row.ReservedAmount);
            Assert.Equal(5000m, row.ApprovedAwaitingReceiptAmount);
            Assert.Equal(22000m, row.AvailableAmount); // 27,000 - 5,000

            // 4. Last Settlement Metadata
            Assert.Equal("SET-20260917-00026", row.LastSettlementRequestNumber);
            Assert.Equal(SettlementRequestStatus.Approved, row.LastSettlementStatus);
            Assert.NotNull(row.LastSettlementDate);

            // --- SEARCH VERIFICATION ---
            // A. Search by Name
            var searchByName = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest { SearchTerm = "محطة اللحوم" });
            Assert.Single(searchByName.Items);

            // B. Search by Merchant ID
            var searchById = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest { SearchTerm = "26" });
            Assert.Single(searchById.Items);
            Assert.Equal(26, searchById.Items[0].MerchantId);

            // C. Search by Phone
            var searchByPhone = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest { SearchTerm = "5555526" });
            Assert.Single(searchByPhone.Items);

            // D. Search with no match
            var searchNoMatch = await service.GetDataTableAsync(new MerchantReconciliationDataTableRequest { SearchTerm = "9999999" });
            Assert.Empty(searchNoMatch.Items);
        }
    }
}
