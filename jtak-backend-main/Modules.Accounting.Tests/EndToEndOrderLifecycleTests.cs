using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
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
using Modules.Orders.Services;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Xunit;
using OrderStatus = Modules.Orders.Entities.OrderStatus;
using PaymentMethod = Modules.Orders.Entities.PaymentMethod;

namespace Modules.Accounting.Tests
{
    public class EndToEndOrderLifecycleTests
    {
        private AccountingDbContext CreateAccountingContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private OrdersDbContext CreateOrdersContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new OrdersDbContext(options, null);
        }

        private CatalogDbContext CreateCatalogContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new CatalogDbContext(options, null);
        }

        private ShippingDbContext CreateShippingContext(string dbName)
        {
            var options = new DbContextOptionsBuilder<ShippingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName)
                .Options;
            return new ShippingDbContext(options, null);
        }

        private (InventoryBatchService batchService, OrderTransitionService transitionService) CreateServices(CatalogDbContext cDb, OrdersDbContext oDb)
        {
            var cUow = new CatalogUnitOfWork(cDb);
            var batchService = new InventoryBatchService(cDb, cUow);

            var oUow = new OrdersUnitOfWork(oDb);
            var orderRepo = new TrackableRepository<Order, OrdersDbContext>(oDb);
            var orderDetailRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(oDb);
            var logRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(oDb);
            var transitionService = new OrderTransitionService(oUow, orderRepo, orderDetailRepo, logRepo);

            return (batchService, transitionService);
        }

        [Fact]
        public async Task Test01_FullLifecycle_FromCheckout_ToSettlement_ReconciledToPenny()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingContext = CreateAccountingContext(db);
            using var ordersContext = CreateOrdersContext(db);
            using var catalogContext = CreateCatalogContext(db);

            var moneyCalc = new OrderMoneyCalculationService();
            var ledgerService = new LedgerService(accountingContext, NullLogger<LedgerService>.Instance);
            await ledgerService.SeedSystemAccountsAsync();

            var (batchService, transitionService) = CreateServices(catalogContext, ordersContext);

            // 1. Setup Product Batch Stock
            var productBatch = new ProductBatch
            {
                Id = 1,
                ProductId = 101,
                MerchantId = 77,
                BatchNumber = "BATCH-2026-A1",
                Barcode = "BC-101",
                QuantityOnHand = 50,
                QuantityReserved = 0,
                ExpirationDate = DateTime.UtcNow.AddMonths(6)
            };
            catalogContext.ProductBatches.Add(productBatch);
            await catalogContext.SaveChangesAsync();

            // 2. Safe Order Checkout & FEFO Stock Reservation
            var customerId = Guid.NewGuid();
            var merchantId = 77;
            var orderId = 5001;

            var order = new Order
            {
                Id = orderId,
                UserId = customerId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Pending,
                PurchaseDate = DateTime.UtcNow,
                IdempotencyKey = "IDEMP-E2E-001",
                AccountingStatus = OrderAccountingStatus.NotApplicable
            };
            ordersContext.Orders.Add(order);

            var detail = new OrderDetail
            {
                Id = 1,
                OrderId = orderId,
                ProductId = 101,
                MerchantId = merchantId,
                Quantity = 3,
                SinglePrice = 12000m,       // compare-at crossed-out
                SingleFinalPrice = 10000m,  // canonical selling price
                OrderDetailStatus = OrderDetailStatus.Pending
            };
            ordersContext.OrderDetails.Add(detail);
            await ordersContext.SaveChangesAsync();

            // FEFO stock reservation
            var reserved = await batchService.ReserveStockFEFOAsync(orderId, detail.Id, detail.ProductId, merchantId, detail.Quantity);
            Assert.NotEmpty(reserved);

            var batchAfterReserve = await catalogContext.ProductBatches.FindAsync(productBatch.Id);
            Assert.Equal(3, batchAfterReserve.QuantityReserved);
            Assert.Equal(50, batchAfterReserve.QuantityOnHand);

            // 3. Merchant Acceptance & Readiness
            var acceptResult = await transitionService.TransitionMerchantOrderAsync(orderId, merchantId, OrderDetailStatus.MerchantAccepted);
            Assert.True(acceptResult.Success);

            var readyResult = await transitionService.TransitionMerchantOrderAsync(orderId, merchantId, OrderDetailStatus.ReadyForPickup);
            Assert.True(readyResult.Success);

            // Stock deduction upon ready for pickup
            await batchService.DeductReservedStockAsync(orderId, merchantId: merchantId);

            var batchAfterDeduct = await catalogContext.ProductBatches.FindAsync(productBatch.Id);
            Assert.Equal(0, batchAfterDeduct.QuantityReserved);
            Assert.Equal(47, batchAfterDeduct.QuantityOnHand);

            // 4. Courier Dispatch & Custody
            var driverId = Guid.NewGuid();
            order.DeliveryId = driverId;
            order.DeliveryUser = "Captain E2E";
            order.RowVersion++;
            order.OrderStatus = OrderStatus.Success;
            detail.OrderDetailStatus = OrderDetailStatus.ShippingStarted;
            await ordersContext.SaveChangesAsync();

            // 5. Courier Delivery & Ledger Double-Entry Balancing
            var money = moneyCalc.CalculateOrderMoney(order.OrderDetails, order.DeliveryFee, order.PaymentMethod);
            Assert.Equal(30000m, money.ProductSubtotal); // 3 * 10000
            Assert.Equal(5000m, money.DeliveryFee);
            Assert.Equal(35000m, money.GrandTotal);
            Assert.Equal(35000m, money.CashToCollect);

            var splitRequest = new OrderDeliveredSplitRequest
            {
                OrderId = orderId,
                CaptainUserId = driverId,
                CaptainName = "E2E-Delivery",
                DeliveryFee = money.DeliveryFee,
                DeliveryFeeIsPlatformRevenue = true,
                TotalsIncludeDeliveryFee = false,
                ActualCashCollected = money.CashToCollect,
                CaptainEarning = 4000m,
                Currency = "SYP",
                IsCod = true,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = merchantId,
                        MerchantTitle = "E2E-Merchant",
                        TotalAmount = 30000m,
                        PlatformCommission = 3000m,
                        MerchantAmount = 27000m,
                        IsPlatformOwned = false
                    }
                }
            };

            var journalEntry = await ledgerService.PostOrderDeliveredSplitAsync(splitRequest);

            Assert.NotNull(journalEntry);
            Assert.Equal(orderId.ToString(), journalEntry.ReferenceId);

            // Verify Ledger Balance Debits == Credits to the penny
            var lines = journalEntry.Entries.ToList();
            var totalDebits = lines.Sum(l => l.Debit);
            var totalCredits = lines.Sum(l => l.Credit);
            Assert.Equal(totalDebits, totalCredits);

            // Mark order posted
            order.OrderStatus = OrderStatus.Success;
            order.AccountingStatus = OrderAccountingStatus.Posted;
            order.ActualCashCollected = money.CashToCollect;
            detail.OrderDetailStatus = OrderDetailStatus.Delivered;
            await ordersContext.SaveChangesAsync();

            // 6. Verify Settlement is unblocked
            var retryService = new OrderAccountingRetryService(ordersContext, accountingContext, ledgerService, NullLogger<OrderAccountingRetryService>.Instance);
            var pendingOrders = await retryService.RetryPendingAccountingOrdersAsync();
            Assert.Equal(0, pendingOrders.TotalFound); // Zero pending accounting orders
        }

        [Fact]
        public async Task Test02_PartialFulfillmentLifecycle_WithMerchantRejection_AdjustsMoneyAndInformsCourier()
        {
            var db = Guid.NewGuid().ToString();
            using var ordersContext = CreateOrdersContext(db);
            using var catalogContext = CreateCatalogContext(db);

            var moneyCalc = new OrderMoneyCalculationService();
            var cUow = new CatalogUnitOfWork(catalogContext);
            var batchService = new InventoryBatchService(catalogContext, cUow);

            // Setup batch for item 1 & 2
            var batch1 = new ProductBatch { Id = 11, ProductId = 201, MerchantId = 88, BatchNumber = "B1", Barcode = "BC1", QuantityOnHand = 10, QuantityReserved = 0, ExpirationDate = DateTime.UtcNow.AddMonths(1) };
            var batch2 = new ProductBatch { Id = 12, ProductId = 202, MerchantId = 88, BatchNumber = "B2", Barcode = "BC2", QuantityOnHand = 10, QuantityReserved = 0, ExpirationDate = DateTime.UtcNow.AddMonths(1) };
            catalogContext.ProductBatches.AddRange(batch1, batch2);
            await catalogContext.SaveChangesAsync();

            var orderId = 5002;
            var order = new Order
            {
                Id = orderId,
                UserId = Guid.NewGuid(),
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryFee = 3000m,
                OrderStatus = OrderStatus.Pending,
                PurchaseDate = DateTime.UtcNow
            };
            ordersContext.Orders.Add(order);

            var detail1 = new OrderDetail
            {
                Id = 11,
                OrderId = orderId,
                ProductId = 201,
                MerchantId = 88,
                Quantity = 2,
                SingleFinalPrice = 5000m,
                OrderDetailStatus = OrderDetailStatus.Pending
            };
            var detail2 = new OrderDetail
            {
                Id = 12,
                OrderId = orderId,
                ProductId = 202,
                MerchantId = 88,
                Quantity = 1,
                SingleFinalPrice = 8000m,
                OrderDetailStatus = OrderDetailStatus.Pending
            };
            ordersContext.OrderDetails.AddRange(detail1, detail2);
            await ordersContext.SaveChangesAsync();

            await batchService.ReserveStockFEFOAsync(orderId, detail1.Id, detail1.ProductId, 88, detail1.Quantity);
            await batchService.ReserveStockFEFOAsync(orderId, detail2.Id, detail2.ProductId, 88, detail2.Quantity);

            // Merchant accepts item 1, rejects item 2 (out of stock)
            detail1.OrderDetailStatus = OrderDetailStatus.MerchantAccepted;
            detail2.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
            await ordersContext.SaveChangesAsync();

            // Release reservation for rejected item 2
            await batchService.ReleaseReservationAsync(orderId, detail2.Id);

            var batch2Refreshed = await catalogContext.ProductBatches.FindAsync(batch2.Id);
            Assert.Equal(0, batch2Refreshed.QuantityReserved); // unreserved

            // Recalculate order money on server
            var activeDetails = new[] { detail1 }; // only accepted items
            var adjustedMoney = moneyCalc.CalculateOrderMoney(activeDetails, order.DeliveryFee, order.PaymentMethod);

            Assert.Equal(10000m, adjustedMoney.ProductSubtotal); // 2 * 5000 (item 2 excluded)
            Assert.Equal(3000m, adjustedMoney.DeliveryFee);
            Assert.Equal(13000m, adjustedMoney.GrandTotal);
            Assert.Equal(13000m, adjustedMoney.CashToCollect); // Net COD cash to collect

            // Verify DTO metrics calculation
            var orderDto = new OrderDto
            {
                Id = orderId,
                OrderDetails = new[]
                {
                    new OrderDetailDto { Id = 11, OrderDetailStatus = OrderDetailStatus.MerchantAccepted, SingleFinalPrice = 5000m, Quantity = 2 },
                    new OrderDetailDto { Id = 12, OrderDetailStatus = OrderDetailStatus.MerchantRejected, SingleFinalPrice = 8000m, Quantity = 1 }
                },
                DeliveryFee = 3000m
            };

            Assert.True(orderDto.HasPartialFulfillment);
            Assert.Equal(8000m, orderDto.RejectedItemsTotal);
            Assert.Equal(10000m, orderDto.AdjustedProductSubtotal);
            Assert.Equal(13000m, orderDto.AdjustedGrandTotal);
            Assert.Equal(18000m, orderDto.OriginalProductSubtotal);
        }

        [Fact]
        public async Task Test03_HighConcurrencyStress_ParallelStockReservationsAndDriverClaims()
        {
            var db = Guid.NewGuid().ToString();
            using var catalogContext = CreateCatalogContext(db);

            // Batch with exactly 10 units available
            var batch = new ProductBatch
            {
                Id = 31,
                ProductId = 301,
                MerchantId = 55,
                BatchNumber = "BATCH-STRESS",
                Barcode = "BC-STRESS",
                QuantityOnHand = 10,
                QuantityReserved = 0,
                ExpirationDate = DateTime.UtcNow.AddMonths(2)
            };
            catalogContext.ProductBatches.Add(batch);
            await catalogContext.SaveChangesAsync();

            // 20 parallel reservation attempts of 2 units each (total 40 units requested, only 10 exist)
            var tasks = Enumerable.Range(1, 20).Select(async i =>
            {
                using var threadContext = CreateCatalogContext(db);
                var threadUow = new CatalogUnitOfWork(threadContext);
                var threadBatchService = new InventoryBatchService(threadContext, threadUow);
                try
                {
                    return await threadBatchService.ReserveStockFEFOAsync(6000 + i, i, 301, 55, 2);
                }
                catch
                {
                    return new List<BatchReservationDto>();
                }
            });

            var results = await Task.WhenAll(tasks);
            var successes = results.Count(r => r != null && r.Any());
            var failures = results.Count(r => r == null || !r.Any());

            // Exactly 5 reservations can succeed (5 * 2 = 10), and 15 must fail
            Assert.Equal(5, successes);
            Assert.Equal(15, failures);

            using var verifyContext = CreateCatalogContext(db);
            var batchEnd = await verifyContext.ProductBatches.FindAsync(batch.Id);
            Assert.NotNull(batchEnd);
            Assert.Equal(10, batchEnd.QuantityReserved);
            Assert.Equal(10, batchEnd.QuantityOnHand);
        }

        [Fact]
        public async Task Test04_TransientLedgerFailure_LeavesPendingAccounting_ThenRecoversViaRetryQueue()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingContext = CreateAccountingContext(db);
            using var ordersContext = CreateOrdersContext(db);

            var realLedgerService = new LedgerService(accountingContext, NullLogger<LedgerService>.Instance);
            await realLedgerService.SeedSystemAccountsAsync();

            var driverId = Guid.NewGuid();
            var orderId = 7001;

            var order = new Order
            {
                Id = orderId,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryFee = 4000m,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = DateTime.UtcNow,
                AccountingStatus = OrderAccountingStatus.PendingAccounting,
                ActualCashCollected = 24000m,
                PurchaseDate = DateTime.UtcNow
            };
            ordersContext.Orders.Add(order);

            var detail = new OrderDetail
            {
                Id = 71,
                OrderId = orderId,
                ProductId = 401,
                MerchantId = 99,
                Quantity = 2,
                SingleFinalPrice = 10000m,
                OrderDetailStatus = OrderDetailStatus.Delivered
            };
            ordersContext.OrderDetails.Add(detail);
            await ordersContext.SaveChangesAsync();

            accountingContext.Bills.Add(new Bill
            {
                OrderId = orderId,
                MerchantId = 99,
                TotalAmount = 20000m,
                MerchantAmount = 18000m,
                JTakAmount = 2000m,
                JTakAdditionalAmount = 0m,
                PaymentMethod = 0,
                DueDate = DateTime.UtcNow
            });
            await accountingContext.SaveChangesAsync();

            // Order is in PendingAccounting state
            Assert.Equal(OrderAccountingStatus.PendingAccounting, order.AccountingStatus);

            // Execute scheduled recovery retry service
            var retryService = new OrderAccountingRetryService(ordersContext, accountingContext, realLedgerService, NullLogger<OrderAccountingRetryService>.Instance);
            var retryResult = await retryService.RetryPendingAccountingOrdersAsync(maxBatchSize: 10);

            Assert.Equal(1, retryResult.TotalFound);
            Assert.Equal(1, retryResult.Succeeded);
            Assert.Equal(0, retryResult.Failed);

            // Order is now successfully posted
            var updatedOrder = await ordersContext.Orders.FindAsync(orderId);
            Assert.Equal(OrderAccountingStatus.Posted, updatedOrder.AccountingStatus);
            Assert.NotNull(updatedOrder.AccountingPostedAt);

            // Ledger entry exists and is balanced
            var journal = await accountingContext.JournalTransactions
                .Include(j => j.Entries)
                .FirstOrDefaultAsync(j => j.ReferenceId == orderId.ToString());
            Assert.NotNull(journal);
            Assert.Equal(journal.Entries.Sum(e => e.Debit), journal.Entries.Sum(e => e.Credit));
        }

        [Fact]
        public async Task Test05_ContinuousInvariantAuditWorker_ExecutesPeriodicSweep_AndEmitsTelemetry()
        {
            var db = Guid.NewGuid().ToString();
            using var accountingContext = CreateAccountingContext(db);
            using var ordersContext = CreateOrdersContext(db);
            using var catalogContext = CreateCatalogContext(db);
            using var shippingContext = CreateShippingContext(db);

            var ledgerService = new LedgerService(accountingContext, NullLogger<LedgerService>.Instance);
            await ledgerService.SeedSystemAccountsAsync();

            var moneyCalc = new OrderMoneyCalculationService();
            var cUow = new CatalogUnitOfWork(catalogContext);
            var batchService = new InventoryBatchService(catalogContext, cUow);

            var reconService = new ProductionReconciliationService(
                accountingContext,
                ordersContext,
                catalogContext,
                shippingContext,
                ledgerService,
                batchService,
                moneyCalc,
                NullLogger<ProductionReconciliationService>.Instance);

            var auditService = new ContinuousInvariantAuditService(reconService, NullLogger<ContinuousInvariantAuditService>.Instance);

            // 1. Initial sweep on clean system -> 100% healthy
            var cleanResult = await auditService.PerformAuditSweepAsync();
            Assert.True(cleanResult.IsHealthy);
            Assert.Equal(0, cleanResult.TotalIssuesFound);
            Assert.Empty(cleanResult.CriticalAlerts);

            // 2. Introduce an invariant violation: delivered order without ledger entry
            var dirtyOrder = new Order
            {
                Id = 8001,
                UserId = Guid.NewGuid(),
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryFee = 5000m,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = DateTime.UtcNow,
                PurchaseDate = DateTime.UtcNow
            };
            ordersContext.Orders.Add(dirtyOrder);
            ordersContext.OrderDetails.Add(new OrderDetail
            {
                Id = 81,
                OrderId = 8001,
                ProductId = 501,
                MerchantId = 33,
                Quantity = 1,
                SingleFinalPrice = 15000m,
                OrderDetailStatus = OrderDetailStatus.Delivered
            });
            await ordersContext.SaveChangesAsync();

            // 3. Second sweep detects the violation
            var detectedResult = await auditService.PerformAuditSweepAsync();
            Assert.False(detectedResult.IsHealthy);
            Assert.True(detectedResult.TotalIssuesFound > 0);
            Assert.Contains(detectedResult.CriticalAlerts, a => a.Contains("MissingDeliveredLedgerTransaction"));
        }

        [Fact]
        public void Test06_OrderFeatureFlagService_CanaryWhitelistingAndFallback()
        {
            var configData = new Dictionary<string, string>
            {
                { "Features:CanonicalMoneyEngine", "true" },
                { "Features:StrictMerchantRadius", "false" },
                { "Features:AtomicDriverClaim", "true" },
                { "Features:StrictProofOfDelivery", "true" },
                { "Features:PeriodicAccountingRetry", "true" },
                { "Features:ContinuousInvariantAudit", "true" },
                { "Features:AuditIntervalMinutes", "30" },
                { "Features:CanaryWhitelistMerchantIds:0", "42" },
                { "Features:CanaryWhitelistDriverIds:0", "11111111-1111-1111-1111-111111111111" }
            };

            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(configData)
                .Build();

            var flagService = new OrderFeatureFlagService(configuration);

            // Default checks
            Assert.True(flagService.IsCanonicalMoneyEngineEnabled());
            Assert.False(flagService.IsStrictMerchantRadiusEnabled()); // globally false
            Assert.True(flagService.IsAtomicDriverClaimEnabled());
            Assert.True(flagService.IsStrictProofOfDeliveryEnabled());
            Assert.True(flagService.IsPeriodicAccountingRetryEnabled());
            Assert.True(flagService.IsContinuousInvariantAuditEnabled());
            Assert.Equal(30, flagService.GetAuditIntervalMinutes());

            // Canary whitelist overrides global false
            Assert.True(flagService.IsStrictMerchantRadiusEnabled(merchantId: 42)); // whitelisted
            Assert.False(flagService.IsStrictMerchantRadiusEnabled(merchantId: 99)); // not whitelisted

            // Canary driver whitelist
            var whitelistedDriver = Guid.Parse("11111111-1111-1111-1111-111111111111");
            var regularDriver = Guid.NewGuid();
            Assert.True(flagService.IsAtomicDriverClaimEnabled(whitelistedDriver));
            Assert.True(flagService.IsAtomicDriverClaimEnabled(regularDriver));
        }
    }
}
