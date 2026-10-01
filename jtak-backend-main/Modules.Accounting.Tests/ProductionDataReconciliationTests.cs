using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Services.Pricing;
using App.Shipping.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Shipping.Entities;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class ProductionDataReconciliationTests
    {
        private AccountingDbContext CreateInMemoryAccountingContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private OrdersDbContext CreateInMemoryOrdersContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new OrdersDbContext(options, null);
        }

        private CatalogDbContext CreateInMemoryCatalogContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new CatalogDbContext(options, null);
        }

        private ShippingDbContext CreateInMemoryShippingContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<ShippingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new ShippingDbContext(options, null);
        }

        [Fact]
        public async Task Discovery_DetectsDeliveryFeeDiscrepancy()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Seed order with delivery fee 5,000 SYP
            var order = new Order
            {
                Id = 101,
                UserId = Guid.NewGuid(),
                DeliveredAt = DateTime.UtcNow.AddHours(-2),
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // Seed a delivered-order journal with only 3,000 SYP posted to
            // delivery revenue (discrepancy: 2,000 SYP).
            var vault = await ledgerService.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            var deliveryRevenue = await ledgerService.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.PlatformDeliveryFeeRevenue, "Delivery Revenue", AccountType.Revenue);
            await ledgerService.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "OrderDelivery",
                ReferenceId = "101",
                IdempotencyKey = "OrderDelivered-101",
                Description = "Test mismatched delivery fee",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = vault.Id, Debit = 3000m, Currency = "SYP" },
                    new() { AccountId = deliveryRevenue.Id, Credit = 3000m, Currency = "SYP" }
                }
            });

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.DeliveryFeeMismatch }
            });

            Assert.Single(report.DeliveryFeeDiscrepancies);
            var item = report.DeliveryFeeDiscrepancies[0];
            Assert.Equal(101, item.OrderId);
            Assert.Equal(3000m, item.CurrentValue);
            Assert.Equal(5000m, item.ExpectedValue);
            Assert.Equal(-2000m, item.Variance);
        }

        [Fact]
        public async Task Discovery_DetectsMissingDeliveredLedgerTransaction()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Seed delivered order with details
            var order = new Order
            {
                Id = 102,
                UserId = Guid.NewGuid(),
                DeliveredAt = DateTime.UtcNow.AddHours(-5),
                DeliveryFee = 4000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 1, Quantity = 2, SingleFinalPrice = 15000m }
                }
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // No JournalTransaction exists for OrderDelivered-102
            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.MissingDeliveredLedgerTransaction }
            });

            Assert.Single(report.MissingDeliveredLedgerTransactions);
            var item = report.MissingDeliveredLedgerTransactions[0];
            Assert.Equal(102, item.OrderId);
            Assert.Equal(34000m, item.ExpectedValue); // 4000 fee + 30000 products
        }

        [Fact]
        public async Task Discovery_DetectsUnbalancedLedgerTransaction()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var account1 = new Account { Id = Guid.NewGuid(), AccountCode = "TEST-1", Name = "A1", Type = AccountType.Asset };
            var account2 = new Account { Id = Guid.NewGuid(), AccountCode = "TEST-2", Name = "A2", Type = AccountType.Revenue };
            await accountingDb.Accounts.AddRangeAsync(account1, account2);

            // Add an unbalanced transaction: Debit 50,000 vs Credit 40,000
            var txn = new JournalTransaction
            {
                Id = Guid.NewGuid(),
                TransactionNumber = "TXN-UNBALANCED-1",
                IdempotencyKey = "KEY-UNBALANCED-1",
                ReferenceType = "Order",
                ReferenceId = "103",
                Entries = new List<LedgerEntry>
                {
                    new LedgerEntry { AccountId = account1.Id, Debit = 50000m, Credit = 0m, Currency = "SYP" },
                    new LedgerEntry { AccountId = account2.Id, Debit = 0m, Credit = 40000m, Currency = "SYP" }
                }
            };
            await accountingDb.JournalTransactions.AddAsync(txn);
            await accountingDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.UnbalancedLedgerTransaction }
            });

            Assert.Single(report.UnbalancedLedgerTransactions);
            var item = report.UnbalancedLedgerTransactions[0];
            Assert.Equal(50000m, item.CurrentValue);
            Assert.Equal(40000m, item.ExpectedValue);
            Assert.Equal(10000m, item.Variance);
        }

        [Fact]
        public async Task Discovery_DetectsDriverCashCustodyMismatch()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var driverId = Guid.NewGuid();

            // Create captain float account with balance 70,000 SYP
            var floatAcc = await ledgerService.GetOrCreateUserAccountAsync(driverId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Captain Float");
            var vaultAcc = await ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);

            await ledgerService.PostTransactionAsync(new PostTransactionRequest
            {
                TransactionNumber = "INIT-FLOAT",
                IdempotencyKey = "INIT-FLOAT-KEY",
                Description = "Initial float",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest { AccountId = floatAcc.Id, Debit = 70000m, Credit = 0m },
                    new PostLedgerEntryRequest { AccountId = vaultAcc.Id, Debit = 0m, Credit = 70000m }
                }
            });

            // Seed delivered COD order totaling 40,000 SYP (variance: 30,000 SYP)
            var order = new Order
            {
                Id = 104,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveredAt = DateTime.UtcNow.AddDays(-1),
                PaymentMethod = PaymentMethod.PayOnDelivery,
                ActualCashCollected = 40000m,
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.DriverCashCustodyMismatch }
            });

            Assert.Single(report.DriverCashCustodyDiscrepancies);
            var item = report.DriverCashCustodyDiscrepancies[0];
            Assert.Equal(driverId, item.UserId);
            Assert.Equal(70000m, item.CurrentValue);
            Assert.Equal(40000m, item.ExpectedValue);
            Assert.Equal(30000m, item.Variance);
        }

        [Fact]
        public async Task Discovery_DetectsCompareAtPricingDiscrepancy()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Seed order with SinglePrice=20,000 (compare-at) and SingleFinalPrice=16,000 (actual sale)
            var order = new Order
            {
                Id = 105,
                UserId = Guid.NewGuid(),
                PurchaseDate = DateTime.UtcNow.AddDays(-3),
                DeliveredAt = DateTime.UtcNow.AddDays(-2),
                DeliveryFee = 3000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                ActualCashCollected = 43000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        Id = 10,
                        ProductId = 5,
                        ProductTitle = "Discounted Olive Oil",
                        Quantity = 2,
                        SinglePrice = 20000m,       // CompareAt price
                        SingleFinalPrice = 16000m    // Actual sale price
                    }
                }
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.CompareAtPricingMismatch }
            });

            Assert.Single(report.CompareAtPricingDiscrepancies);
            var item = report.CompareAtPricingDiscrepancies[0];
            Assert.Equal(105, item.OrderId);
            Assert.Equal(43000m, item.CurrentValue);  // compare-at subtotal + delivery
            Assert.Equal(35000m, item.ExpectedValue); // final subtotal + delivery
            Assert.Equal(8000m, item.Variance);       // 8,000 customer overcharge
        }

        [Fact]
        public async Task Discovery_DetectsZeroCaptainEarnings()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var courierId = Guid.NewGuid();

            var order = new Order
            {
                Id = 106,
                UserId = Guid.NewGuid(),
                DeliveryId = courierId,
                DeliveredAt = DateTime.UtcNow.AddHours(-12),
                DeliveryFee = 6000m,
                MoneySnapshotVersion = 1,
                CaptainEarning = 6000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // Seed bill where JTakAdditionalAmount = 0
            var bill = new Bill
            {
                OrderId = 106,
                MerchantId = 2,
                TotalAmount = 40000m,
                MerchantAmount = 36000m,
                JTakAmount = 4000m,
                JTakAdditionalAmount = 0m // Zero courier wage recorded!
            };
            await accountingDb.Bills.AddAsync(bill);
            await accountingDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.ZeroCaptainEarnings }
            });

            Assert.Single(report.ZeroCaptainEarningsDiscrepancies);
            var item = report.ZeroCaptainEarningsDiscrepancies[0];
            Assert.Equal(106, item.OrderId);
            Assert.Equal(courierId, item.UserId);
            Assert.Equal(6000m, item.ExpectedValue);
            Assert.Equal(-6000m, item.Variance);
        }

        [Fact]
        public async Task Discovery_DetectsCanceledOrderUnrestoredInventory()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var order = new Order
            {
                Id = 107,
                UserId = Guid.NewGuid(),
                OrderStatus = OrderStatus.Pending,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        Id = 55,
                        ProductId = 8,
                        ProductTitle = "Fresh Milk",
                        Quantity = 3,
                        OrderDetailStatus = OrderDetailStatus.CustomerCanceled // Canceled line
                    }
                }
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // Seed inventory movement: Reserve recorded, but no Release or Return recorded
            var movement = new InventoryMovement
            {
                OrderId = 107,
                OrderDetailId = 55,
                ProductId = 8,
                MerchantId = 1,
                ProductBatchId = 1,
                MovementType = InventoryMovementType.Reserve,
                Quantity = 3
            };
            await catalogDb.InventoryMovements.AddAsync(movement);
            await catalogDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.CanceledOrderUnrestoredInventory }
            });

            Assert.Single(report.CanceledOrdersUnrestoredInventory);
            var item = report.CanceledOrdersUnrestoredInventory[0];
            Assert.Equal(107, item.OrderId);
            Assert.Equal(3m, item.Variance);
        }

        [Fact]
        public async Task Discovery_DetectsDuplicateOrdersInRequestWindow()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var customerId = Guid.NewGuid();
            var now = DateTime.UtcNow;

            var order1 = new Order
            {
                Id = 108,
                UserId = customerId,
                PurchaseDate = now.AddMinutes(-2),
                DeliveryFee = 3000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 61, Quantity = 1, SingleFinalPrice = 25000m }
                }
            };

            var order2 = new Order
            {
                Id = 109,
                UserId = customerId,
                PurchaseDate = now.AddMinutes(-1), // 1 minute later, identical total (28,000 SYP)
                DeliveryFee = 3000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 62, Quantity = 1, SingleFinalPrice = 25000m }
                }
            };

            await ordersDb.Orders.AddRangeAsync(order1, order2);
            await ordersDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.DuplicateOrder }
            });

            Assert.Single(report.DuplicateOrders);
            var item = report.DuplicateOrders[0];
            Assert.Equal(109, item.OrderId);
            Assert.Equal(28000m, item.CurrentValue);
        }

        [Fact]
        public async Task Discovery_DetectsPeriodMismatchSales()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Delivered on March 31, 2026
            var order = new Order
            {
                Id = 110,
                UserId = Guid.NewGuid(),
                DeliveredAt = new DateTime(2026, 3, 31, 20, 0, 0, DateTimeKind.Utc),
                DeliveryFee = 4000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // Billed on April 3, 2026 (period mismatch across month boundary)
            var bill = new Bill
            {
                OrderId = 110,
                MerchantId = 3,
                CreatedDate = new DateTime(2026, 4, 3, 10, 0, 0, DateTimeKind.Utc),
                TotalAmount = 75000m,
                MerchantAmount = 67500m,
                JTakAmount = 7500m
            };
            await accountingDb.Bills.AddAsync(bill);
            await accountingDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.PeriodMismatchSales }
            });

            Assert.Single(report.PeriodMismatchSales);
            var item = report.PeriodMismatchSales[0];
            Assert.Equal(110, item.OrderId);
            Assert.Equal(3, item.MerchantId);
        }

        [Fact]
        public async Task Discovery_IsStrictlyReadOnly_DoesNotMutateDatabase()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Seed order with mismatch
            var order = new Order
            {
                Id = 111,
                UserId = Guid.NewGuid(),
                DeliveredAt = DateTime.UtcNow.AddHours(-1),
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            var preOrdersCount = await ordersDb.Orders.CountAsync();
            var preTxnsCount = await accountingDb.JournalTransactions.CountAsync();
            var preBatchesCount = await accountingDb.ReconciliationBatches.CountAsync();

            // Run full discovery
            var report = await reconService.RunDiscoveryAsync();
            Assert.NotNull(report);

            // Verify database counts remain completely unchanged
            Assert.Equal(preOrdersCount, await ordersDb.Orders.CountAsync());
            Assert.Equal(preTxnsCount, await accountingDb.JournalTransactions.CountAsync());
            Assert.Equal(preBatchesCount, await accountingDb.ReconciliationBatches.CountAsync());
        }

        [Fact]
        public async Task StagingAndApproval_RequiresFinanceApprovalBeforeExecution()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            // Seed delivered order with missing transaction
            var order = new Order
            {
                Id = 112,
                UserId = Guid.NewGuid(),
                DeliveredAt = DateTime.UtcNow.AddHours(-4),
                DeliveryFee = 4000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 71, Quantity = 1, SingleFinalPrice = 20000m }
                }
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // 1. Stage corrections
            var batchDto = await reconService.StageCorrectionsAsync(new StageCorrectionsRequest
            {
                Reason = "EOD Missing Orders Reconciliation",
                SourceSnapshotManifest = "SHA256:abc123snapshot"
            }, "AuditAdmin");

            Assert.NotNull(batchDto);
            Assert.Equal(ReconciliationBatchStatus.Staged, batchDto.Status);
            Assert.NotEmpty(batchDto.StagedCorrections);

            // Verify staged correction contains serialized JSON before/after states
            var stagedCorrection = batchDto.StagedCorrections.First();
            Assert.NotNull(stagedCorrection.BeforeStateJson);
            Assert.NotNull(stagedCorrection.ProposedAfterStateJson);
            Assert.Equal(StagedCorrectionStatus.PendingReview, stagedCorrection.Status);

            // 2. Attempt execution without approval -> MUST FAIL
            await Assert.ThrowsAsync<InvalidOperationException>(async () =>
            {
                await reconService.ExecuteRepairsAsync(batchDto.Id, "Operator");
            });

            // 3. Finance approval
            var approvedBatch = await reconService.ApproveBatchAsync(batchDto.Id, "FinanceManager", "All discrepancies verified with physical delivery slips.");
            Assert.Equal(ReconciliationBatchStatus.Approved, approvedBatch.Status);
            Assert.Equal("FinanceManager", approvedBatch.ApprovedBy);
            Assert.NotNull(approvedBatch.ApprovedAt);
            Assert.All(approvedBatch.StagedCorrections, c => Assert.Equal(StagedCorrectionStatus.Approved, c.Status));
        }

        [Fact]
        public async Task ExecuteRepairs_SkipsUnsafeGenericFinancialRepairs_AndIsIdempotent()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var mockBatchService = new Mock<IInventoryBatchService>();

            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, mockBatchService.Object, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var courierId = Guid.NewGuid();

            // Seed delivered order with missing transaction and zero captain earnings
            var order = new Order
            {
                Id = 113,
                UserId = Guid.NewGuid(),
                DeliveryId = courierId,
                DeliveredAt = DateTime.UtcNow.AddHours(-6),
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Success,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 81, Quantity = 1, SingleFinalPrice = 30000m }
                }
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            // Stage, approve, and execute
            var stagedBatch = await reconService.StageCorrectionsAsync(new StageCorrectionsRequest
            {
                Reason = "Automated test repair"
            }, "TestOperator");

            await reconService.ApproveBatchAsync(stagedBatch.Id, "FinanceApprover");

            // Execute repairs
            var execResult = await reconService.ExecuteRepairsAsync(stagedBatch.Id, "ExecutionEngine");

            Assert.Equal(ReconciliationBatchStatus.Completed, execResult.Status);
            Assert.Equal(0, execResult.AppliedCount);
            Assert.Equal(0, execResult.FailedCount);
            Assert.True(execResult.SkippedCount > 0);
            Assert.Empty(execResult.CreatedJournalTransactionNumbers);

            // Verify posted transactions balance to the penny: Sum(Debit) == Sum(Credit)
            var postedTxns = await accountingDb.JournalTransactions
                .Include(t => t.Entries)
                .Where(t => t.ReferenceType == "ReconciliationAdjustment")
                .ToListAsync();

            Assert.Empty(postedTxns);

            // IDEMPOTENCY TEST: Re-running execute on the completed batch must make 0 changes!
            var rerunResult = await reconService.ExecuteRepairsAsync(stagedBatch.Id, "ExecutionEngine");
            Assert.Equal(ReconciliationBatchStatus.Completed, rerunResult.Status);
            Assert.Equal(execResult.AppliedCount, rerunResult.AppliedCount);

            // Verify count of transactions did not double
            var postRerunTxnsCount = await accountingDb.JournalTransactions
                .Where(t => t.ReferenceType == "ReconciliationAdjustment")
                .CountAsync();
            Assert.Equal(postedTxns.Count, postRerunTxnsCount);

            // A generic variance must never invent a financial transaction;
            // the finding remains until the domain-specific accounting replay runs.
            var postRepairDiscovery = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.MissingDeliveredLedgerTransaction }
            });

            Assert.Contains(postRepairDiscovery.MissingDeliveredLedgerTransactions, x => x.OrderId == 113);
        }

        [Fact]
        public async Task Discovery_DetectsDuplicateDriverAssignments()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var driver1 = Guid.NewGuid();
            var driver2 = Guid.NewGuid();

            // Seed shipping orders for Order #114 with conflicting drivers
            await shippingDb.ShippingOrders.AddRangeAsync(
                new ShippingOrder { Id = 1, OrderId = 114, DriverId = driver1, Index = 1 },
                new ShippingOrder { Id = 2, OrderId = 114, DriverId = driver2, Index = 2 }
            );
            await shippingDb.SaveChangesAsync();

            var report = await reconService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
            {
                IssuesToScan = new List<ReconciliationIssueType> { ReconciliationIssueType.DuplicateDriverAssignment }
            });

            Assert.Single(report.DuplicateDriverAssignments);
            var item = report.DuplicateDriverAssignments[0];
            Assert.Equal(114, item.OrderId);
            Assert.Equal(2m, item.CurrentValue); // 2 distinct drivers
        }

        [Fact]
        public async Task ProductionReconciliationController_LifecycleEndToEnd()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingDb = CreateInMemoryAccountingContext(db);
            using var ordersDb = CreateInMemoryOrdersContext(db);
            using var catalogDb = CreateInMemoryCatalogContext(db);
            using var shippingDb = CreateInMemoryShippingContext(db);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var reconService = new ProductionReconciliationService(
                accountingDb, ordersDb, catalogDb, shippingDb, ledgerService, null, null,
                NullLogger<ProductionReconciliationService>.Instance);

            var writeEnabledConfig = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string>
                {
                    ["ProductionReconciliation:AllowWrites"] = "true"
                })
                .Build();
            var controller = new App.ApiControllers.V1.Admin.ProductionReconciliationController(
                reconService,
                configuration: writeEnabledConfig);

            // Seed order with delivery fee discrepancy
            var order = new Order
            {
                Id = 115,
                UserId = Guid.NewGuid(),
                DeliveredAt = DateTime.UtcNow.AddHours(-1),
                DeliveryFee = 7000m,
                OrderStatus = OrderStatus.Success
            };
            await ordersDb.Orders.AddAsync(order);
            await ordersDb.SaveChangesAsync();

            await accountingDb.Bills.AddAsync(new Bill
            {
                OrderId = 115,
                MerchantId = 5,
                TotalAmount = 40000m,
                MerchantAmount = 36000m,
                JTakAmount = 4000m,
                JTakAdditionalAmount = 3000m // Discrepancy: 4000 SYP
            });
            await accountingDb.SaveChangesAsync();

            // 1. Controller Discovery
            var discResult = await controller.RunDiscovery(new ReconciliationDiscoveryOptions());
            var okDisc = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(discResult.Result);
            var report = Assert.IsType<ReconciliationDiscoveryReportDto>(okDisc.Value);
            Assert.True(report.TotalIssuesDiscovered > 0);

            // 2. Controller Stage
            var stageResult = await controller.StageCorrections(new StageCorrectionsRequest
            {
                Reason = "Controller test staging",
                SourceSnapshotManifest = "snapshot-manifest-hash"
            });
            var okStage = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(stageResult.Result);
            var batchDto = Assert.IsType<ReconciliationBatchDto>(okStage.Value);
            Assert.Equal(ReconciliationBatchStatus.Staged, batchDto.Status);

            // 3. Controller Get Batches
            var batchesResult = await controller.GetBatches();
            var okBatches = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(batchesResult.Result);
            var batchesList = Assert.IsType<List<ReconciliationBatchSummaryDto>>(okBatches.Value);
            Assert.Single(batchesList);

            // 4. Controller Approve
            var approveResult = await controller.ApproveBatch(batchDto.Id, new ApproveReconciliationBatchRequest { Notes = "Approved by controller" });
            var okApprove = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(approveResult.Result);
            var approvedDto = Assert.IsType<ReconciliationBatchDto>(okApprove.Value);
            Assert.Equal(ReconciliationBatchStatus.Approved, approvedDto.Status);

            // 5. Controller Execute
            var execResult = await controller.ExecuteBatch(batchDto.Id);
            var okExec = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(execResult.Result);
            var resultDto = Assert.IsType<ReconciliationBatchExecutionResultDto>(okExec.Value);
            Assert.Equal(ReconciliationBatchStatus.Completed, resultDto.Status);
            Assert.Equal(0, resultDto.AppliedCount);
            Assert.True(resultDto.SkippedCount > 0);
            Assert.Equal(0, resultDto.FailedCount);

            // 6. Controller Report
            var reportResult = await controller.GetBatchReport(batchDto.Id);
            var okReport = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(reportResult.Result);
            var reportDto = Assert.IsType<ReconciliationBatchDto>(okReport.Value);
            Assert.Equal(ReconciliationBatchStatus.Completed, reportDto.Status);
        }
    }
}
