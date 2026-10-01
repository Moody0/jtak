using App.ApiControllers.V1.Warehouse;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using App.Shared.Services.Pricing;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using Moq;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class MerchantAcceptanceAndInventoryTransitionTests
    {
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

        private (CatalogDbContext catDb, InventoryBatchService batchService, OrdersDbContext ordersDb, OrderTransitionService transitionService) CreateServices(
            CatalogDbContext catDb = null,
            OrdersDbContext ordersDb = null)
        {
            var cDb = catDb ?? CreateInMemoryCatalogContext();
            var cUow = new CatalogUnitOfWork(cDb);
            var batchService = new InventoryBatchService(cDb, cUow);

            var oDb = ordersDb ?? CreateInMemoryOrdersContext();
            var oUow = new OrdersUnitOfWork(oDb);
            var orderRepo = new TrackableRepository<Order, OrdersDbContext>(oDb);
            var orderDetailRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(oDb);
            var logRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(oDb);
            var transitionService = new OrderTransitionService(oUow, orderRepo, orderDetailRepo, logRepo);
            return (cDb, batchService, oDb, transitionService);
        }

        [Fact]
        public async Task AcceptThenReady_DeductsStockOnce_And_RecordsDeductionMovement()
        {
            var (catDb, batchService, ordersDb, transitionService) = CreateServices();

            // 1. Setup batch with 20 on hand
            var batch = new ProductBatch
            {
                Id = 1,
                ProductId = 100,
                MerchantId = 5,
                BatchNumber = "BATCH-001",
                Barcode = "BAR-001",
                QuantityOnHand = 20,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                ExpirationDate = DateTime.UtcNow.AddMonths(6)
            };
            catDb.ProductBatches.Add(batch);
            await catDb.SaveChangesAsync();

            // 2. Setup Order and Detail
            var order = new Order
            {
                Id = 101,
                UserId = Guid.NewGuid(),
                OrderStatus = OrderStatus.Success,
                PurchaseDate = DateTime.UtcNow
            };
            var detail = new OrderDetail
            {
                Id = 501,
                OrderId = 101,
                ProductId = 100,
                MerchantId = 5,
                Quantity = 4,
                OrderDetailStatus = OrderDetailStatus.Pending,
                SinglePrice = 1000m,
                SingleFinalPrice = 1000m
            };
            ordersDb.Orders.Add(order);
            ordersDb.OrderDetails.Add(detail);
            await ordersDb.SaveChangesAsync();

            var resResult = await batchService.ReserveStockFEFOAsync(101, 501, 100, 5, 4);
            Assert.NotEmpty(resResult);
            Assert.Equal(4, resResult.Sum(r => r.Quantity));

            var batchAfterReserve = await catDb.ProductBatches.FindAsync(1);
            Assert.Equal(20, batchAfterReserve.QuantityOnHand);
            Assert.Equal(4, batchAfterReserve.QuantityReserved);

            // 4. Merchant accepts order
            var acceptResult = await transitionService.TransitionMerchantOrderAsync(101, 5, OrderDetailStatus.MerchantAccepted);
            Assert.True(acceptResult.Success);
            Assert.False(acceptResult.IsNoOp);

            var detailAfterAccept = await ordersDb.OrderDetails.FindAsync(501);
            Assert.Equal(OrderDetailStatus.MerchantAccepted, detailAfterAccept.OrderDetailStatus);

            // 5. Merchant marks ready for pickup & deducts stock
            var readyResult = await transitionService.TransitionMerchantOrderAsync(101, 5, OrderDetailStatus.ReadyForPickup);
            Assert.True(readyResult.Success);

            await batchService.DeductReservedStockAsync(101, merchantId: 5);

            // 6. Verify stock balances and movements
            var batchAfterReady = await catDb.ProductBatches.FindAsync(1);
            Assert.Equal(16, batchAfterReady.QuantityOnHand);
            Assert.Equal(0, batchAfterReady.QuantityReserved);

            var movements = await batchService.GetInventoryMovementsAsync(batchId: 1);
            Assert.Equal(2, movements.Count); // Reserve and Deduction
            var deductionMovement = movements.FirstOrDefault(m => m.MovementType == InventoryMovementType.Deduction);
            Assert.NotNull(deductionMovement);
            Assert.Equal(4, deductionMovement.Quantity);
            Assert.Equal(20, deductionMovement.QuantityOnHandBefore);
            Assert.Equal(16, deductionMovement.QuantityOnHandAfter);
            Assert.Equal(4, deductionMovement.QuantityReservedBefore);
            Assert.Equal(0, deductionMovement.QuantityReservedAfter);
        }

        [Fact]
        public async Task RepeatedReadyRequests_DoNotDoubleDeduct_AreIdempotent()
        {
            var (catDb, batchService, ordersDb, transitionService) = CreateServices();

            var batch = new ProductBatch
            {
                Id = 2,
                ProductId = 200,
                MerchantId = 5,
                BatchNumber = "BATCH-002",
                Barcode = "BAR-002",
                QuantityOnHand = 10,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                ExpirationDate = DateTime.UtcNow.AddMonths(6)
            };
            catDb.ProductBatches.Add(batch);
            await catDb.SaveChangesAsync();

            var order = new Order { Id = 102, UserId = Guid.NewGuid(), OrderStatus = OrderStatus.Success };
            var detail = new OrderDetail
            {
                Id = 502,
                OrderId = 102,
                ProductId = 200,
                MerchantId = 5,
                Quantity = 3,
                OrderDetailStatus = OrderDetailStatus.MerchantAccepted,
                SinglePrice = 500m,
                SingleFinalPrice = 500m
            };
            ordersDb.Orders.Add(order);
            ordersDb.OrderDetails.Add(detail);
            await ordersDb.SaveChangesAsync();

            await batchService.ReserveStockFEFOAsync(102, 502, 200, 5, 3);

            // First Ready
            await transitionService.TransitionMerchantOrderAsync(102, 5, OrderDetailStatus.ReadyForPickup);
            await batchService.DeductReservedStockAsync(102, merchantId: 5);

            var batchAfterFirstReady = await catDb.ProductBatches.FindAsync(2);
            Assert.Equal(7, batchAfterFirstReady.QuantityOnHand);
            Assert.Equal(0, batchAfterFirstReady.QuantityReserved);

            // Repeated Ready (retry)
            var secondReadyResult = await transitionService.TransitionMerchantOrderAsync(102, 5, OrderDetailStatus.ReadyForPickup);
            Assert.True(secondReadyResult.Success);
            Assert.True(secondReadyResult.IsNoOp); // Idempotent no-op

            await batchService.DeductReservedStockAsync(102, merchantId: 5);

            // Stock remains 7, not double deducted!
            var batchAfterSecondReady = await catDb.ProductBatches.FindAsync(2);
            Assert.Equal(7, batchAfterSecondReady.QuantityOnHand);
            Assert.Equal(0, batchAfterSecondReady.QuantityReserved);

            var movements = await batchService.GetInventoryMovementsAsync(batchId: 2);
            Assert.Single(movements.Where(m => m.MovementType == InventoryMovementType.Deduction));
        }

        [Fact]
        public async Task CancelBeforeReady_ReleasesReservation_UnreservesStock()
        {
            var (catDb, batchService, ordersDb, transitionService) = CreateServices();

            var batch = new ProductBatch
            {
                Id = 3,
                ProductId = 300,
                MerchantId = 7,
                BatchNumber = "BATCH-003",
                Barcode = "BAR-003",
                QuantityOnHand = 25,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                ExpirationDate = DateTime.UtcNow.AddMonths(12)
            };
            catDb.ProductBatches.Add(batch);
            await catDb.SaveChangesAsync();

            var order = new Order { Id = 103, UserId = Guid.NewGuid(), OrderStatus = OrderStatus.Success };
            var detail = new OrderDetail
            {
                Id = 503,
                OrderId = 103,
                ProductId = 300,
                MerchantId = 7,
                Quantity = 5,
                OrderDetailStatus = OrderDetailStatus.Pending,
                SinglePrice = 800m,
                SingleFinalPrice = 800m
            };
            ordersDb.Orders.Add(order);
            ordersDb.OrderDetails.Add(detail);
            await ordersDb.SaveChangesAsync();

            await batchService.ReserveStockFEFOAsync(103, 503, 300, 7, 5);

            // Cancel before ready
            await batchService.ReleaseReservationAsync(103, reason: "Customer cancelled before preparation", merchantId: 7);
            await transitionService.TransitionMerchantOrderAsync(103, 7, OrderDetailStatus.CustomerCanceled, reason: "Customer cancelled");

            var batchAfterCancel = await catDb.ProductBatches.FindAsync(3);
            Assert.Equal(25, batchAfterCancel.QuantityOnHand);
            Assert.Equal(0, batchAfterCancel.QuantityReserved);

            var movements = await batchService.GetInventoryMovementsAsync(batchId: 3);
            var releaseMovement = movements.FirstOrDefault(m => m.MovementType == InventoryMovementType.Release);
            Assert.NotNull(releaseMovement);
            Assert.Equal(5, releaseMovement.Quantity);
            Assert.Equal(5, releaseMovement.QuantityReservedBefore);
            Assert.Equal(0, releaseMovement.QuantityReservedAfter);
        }

        [Fact]
        public async Task CancelAfterReady_CreatesReturnMovement_AndRestoresSellableStock()
        {
            var (catDb, batchService, ordersDb, transitionService) = CreateServices();

            var batch = new ProductBatch
            {
                Id = 4,
                ProductId = 400,
                MerchantId = 8,
                BatchNumber = "BATCH-004",
                Barcode = "BAR-004",
                QuantityOnHand = 15,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                ExpirationDate = DateTime.UtcNow.AddMonths(12)
            };
            catDb.ProductBatches.Add(batch);
            await catDb.SaveChangesAsync();

            var order = new Order { Id = 104, UserId = Guid.NewGuid(), OrderStatus = OrderStatus.Success };
            var detail = new OrderDetail
            {
                Id = 504,
                OrderId = 104,
                ProductId = 400,
                MerchantId = 8,
                Quantity = 6,
                OrderDetailStatus = OrderDetailStatus.MerchantAccepted,
                SinglePrice = 1200m,
                SingleFinalPrice = 1200m
            };
            ordersDb.Orders.Add(order);
            ordersDb.OrderDetails.Add(detail);
            await ordersDb.SaveChangesAsync();

            // Reserve & deduct upon ready
            await batchService.ReserveStockFEFOAsync(104, 504, 400, 8, 6);
            await transitionService.TransitionMerchantOrderAsync(104, 8, OrderDetailStatus.ReadyForPickup);
            await batchService.DeductReservedStockAsync(104, merchantId: 8);

            var batchDeducted = await catDb.ProductBatches.FindAsync(4);
            Assert.Equal(9, batchDeducted.QuantityOnHand); // 15 - 6 = 9
            Assert.Equal(0, batchDeducted.QuantityReserved);

            // Now order is canceled / returned AFTER readiness!
            await batchService.ReleaseReservationAsync(104, reason: "Order canceled post-preparation", merchantId: 8);

            // Sellable stock is restored to 15!
            var batchRestored = await catDb.ProductBatches.FindAsync(4);
            Assert.Equal(15, batchRestored.QuantityOnHand);

            var movements = await batchService.GetInventoryMovementsAsync(batchId: 4);
            var returnMovement = movements.FirstOrDefault(m => m.MovementType == InventoryMovementType.Return);
            Assert.NotNull(returnMovement);
            Assert.Equal(6, returnMovement.Quantity);
            Assert.Equal(9, returnMovement.QuantityOnHandBefore);
            Assert.Equal(15, returnMovement.QuantityOnHandAfter);
        }

        [Fact]
        public async Task FailedDelivery_ProcessReturnInventory_TracksDispositions()
        {
            var (catDb, batchService, _, _) = CreateServices();

            var batch = new ProductBatch
            {
                Id = 5,
                ProductId = 500,
                MerchantId = 9,
                BatchNumber = "BATCH-005",
                Barcode = "BAR-005",
                QuantityOnHand = 10,
                QuantityReserved = 0,
                Status = BatchStatus.Active,
                ExpirationDate = DateTime.UtcNow.AddMonths(12)
            };
            catDb.ProductBatches.Add(batch);
            await catDb.SaveChangesAsync();

            // Create reservations for 3 items:
            // detail 505: 2 units (will be restocked)
            // detail 506: 1 unit (damaged)
            // detail 507: 1 unit (missing)
            await batchService.ReserveStockFEFOAsync(105, 505, 500, 9, 2);
            await batchService.ReserveStockFEFOAsync(105, 506, 500, 9, 1);
            await batchService.ReserveStockFEFOAsync(105, 507, 500, 9, 1);

            // Deduct all 3 reservations on preparation/shipping
            await batchService.DeductReservedStockAsync(105, merchantId: 9);

            var batchDeducted = await catDb.ProductBatches.FindAsync(5);
            Assert.Equal(6, batchDeducted.QuantityOnHand); // 10 - 4 = 6

            // 1. Restock 2 items -> OnHand increases from 6 to 8
            await batchService.ProcessReturnInventoryAsync(105, 505, "Customer rejected unopened", returnToStock: true, disposition: "Restocked", merchantId: 9);
            var batchRestocked = await catDb.ProductBatches.FindAsync(5);
            Assert.Equal(8, batchRestocked.QuantityOnHand);

            // 2. Mark 1 item damaged -> OnHand stays 8, logs Damage movement
            await batchService.ProcessReturnInventoryAsync(105, 506, "Broken packaging during transport", returnToStock: false, disposition: "Damaged", merchantId: 9);
            var batchDamaged = await catDb.ProductBatches.FindAsync(5);
            Assert.Equal(8, batchDamaged.QuantityOnHand);

            // 3. Mark 1 item missing -> OnHand stays 8, logs Missing movement
            await batchService.ProcessReturnInventoryAsync(105, 507, "Lost in transit", returnToStock: false, disposition: "Missing", merchantId: 9);
            var batchMissing = await catDb.ProductBatches.FindAsync(5);
            Assert.Equal(8, batchMissing.QuantityOnHand);

            var movements = await batchService.GetInventoryMovementsAsync(batchId: 5);
            Assert.Contains(movements, m => m.MovementType == InventoryMovementType.Return && m.Quantity == 2);
            Assert.Contains(movements, m => m.MovementType == InventoryMovementType.Damage && m.Quantity == 1);
            Assert.Contains(movements, m => m.MovementType == InventoryMovementType.Missing && m.Quantity == 1);
        }

        [Fact]
        public async Task TransitionService_RejectsIllegalStatusJumps()
        {
            var (_, _, ordersDb, transitionService) = CreateServices();

            // Legal transitions
            Assert.True(transitionService.CanTransition(OrderDetailStatus.Pending, OrderDetailStatus.MerchantAccepted));
            Assert.True(transitionService.CanTransition(OrderDetailStatus.MerchantAccepted, OrderDetailStatus.ReadyForPickup));
            Assert.True(transitionService.CanTransition(OrderDetailStatus.ReadyForPickup, OrderDetailStatus.ShippingStarted));
            Assert.True(transitionService.CanTransition(OrderDetailStatus.ShippingStarted, OrderDetailStatus.Delivered));

            // Terminal status reversals must be rejected
            Assert.False(transitionService.CanTransition(OrderDetailStatus.Delivered, OrderDetailStatus.Pending));
            Assert.False(transitionService.CanTransition(OrderDetailStatus.Delivered, OrderDetailStatus.CustomerCanceled));
            Assert.False(transitionService.CanTransition(OrderDetailStatus.MerchantRejected, OrderDetailStatus.MerchantAccepted));
            Assert.False(transitionService.CanTransition(OrderDetailStatus.CustomerCanceled, OrderDetailStatus.Delivered));

            // Test execution throws InvalidOperationException on illegal transition
            var order = new Order { Id = 106, UserId = Guid.NewGuid(), OrderStatus = OrderStatus.Success };
            var detail = new OrderDetail
            {
                Id = 506,
                OrderId = 106,
                ProductId = 600,
                MerchantId = 1,
                Quantity = 1,
                OrderDetailStatus = OrderDetailStatus.Delivered
            };
            ordersDb.Orders.Add(order);
            ordersDb.OrderDetails.Add(detail);
            await ordersDb.SaveChangesAsync();

            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                transitionService.TransitionOrderDetailAsync(106, 506, OrderDetailStatus.Pending));
        }

        [Fact]
        public void OrderDetailDto_ExposesFinancialAndStatusTransparencyFields()
        {
            var detail = new OrderDetail
            {
                Id = 701,
                OrderId = 201,
                ProductId = 801,
                MerchantId = 12,
                Quantity = 5,
                SinglePrice = 2000m,
                SingleFinalPrice = 1800m,
                SingleMerchantProfit = 1500m,
                SingleAdditionalProfit = 300m,
                OrderDetailStatus = OrderDetailStatus.MerchantAccepted
            };

            var dto = detail.ToDto();

            Assert.Equal(1500m, dto.SingleMerchantProfit);
            Assert.Equal(300m, dto.SingleAdditionalProfit);
            Assert.True(dto.IsAccepted);
            Assert.False(dto.IsRejected);
            Assert.False(dto.IsCanceled);
            Assert.Equal(5, dto.AcceptedQuantity);
            Assert.Equal(0, dto.RejectedQuantity);
            Assert.Equal(7500m, dto.MerchantPayable); // 5 * 1500 = 7500
        }

        [Fact]
        public async Task WarehouseOrdersController_PostMine_ReturnsHistoricalOrdersBeyondThreeDays()
        {
            var ordersDb = CreateInMemoryOrdersContext();
            var uow = new OrdersUnitOfWork(ordersDb);

            var oldDetail = new OrderDetail
            {
                Id = 881,
                OrderId = 991,
                MerchantId = 42,
                ProductId = 111,
                Quantity = 2,
                SinglePrice = 5000m,
                SingleFinalPrice = 5000m,
                OrderDetailStatus = OrderDetailStatus.Delivered
            };
            var oldOrder = new Order
            {
                Id = 991,
                UserId = Guid.NewGuid(),
                OrderStatus = OrderStatus.Success,
                PurchaseDate = DateTime.UtcNow.AddDays(-30), // 30 days ago
                DeliveryFee = 2500m,
                OrderDetails = new List<OrderDetail> { oldDetail }
            };
            ordersDb.Orders.Add(oldOrder);
            await ordersDb.SaveChangesAsync();

            var orderRepo = new TrackableRepository<Order, OrdersDbContext>(ordersDb);
            var logRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(ordersDb);
            var detailRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(ordersDb);

            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManagerMock = new Mock<UserManager<AppUser>>(userStoreMock.Object, null, null, null, null, null, null, null, null);
            var mapperMock = new Mock<IMapper>();
            var orderService = new OrderService(uow, mapperMock.Object, userManagerMock.Object, orderRepo, logRepo, detailRepo);
            var orderDetailService = new OrderDetailService(detailRepo);

            var merchantServiceMock = new Mock<IMerchantService>();
            merchantServiceMock.Setup(m => m.GetMerchantIds(It.IsAny<Guid>())).ReturnsAsync(new[] { 42 });

            var notificationMock = new Mock<INotificationService>();
            var productServiceMock = new Mock<IProductService>();
            var deliveryServiceMock = new Mock<IDeliveryService>();
            var batchServiceMock = new Mock<IInventoryBatchService>();

            var controller = new OrdersController(
                uow,
                userManagerMock.Object,
                notificationMock.Object,
                merchantServiceMock.Object,
                orderService,
                productServiceMock.Object,
                orderDetailService,
                deliveryServiceMock.Object,
                batchServiceMock.Object,
                mapperMock.Object);

            var merchantUserId = Guid.NewGuid();
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, merchantUserId.ToString()),
                new Claim("sub", merchantUserId.ToString())
            }, "TestAuth"));
            controller.ControllerContext = new Microsoft.AspNetCore.Mvc.ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var request = new MetronicTable
            {
                PageNumber = 1,
                PageSize = 10
            };

            var result = await controller.PostMine(request);

            Assert.NotNull(result?.Value);
            Assert.Contains(result.Value.Items, o => o.Id == 991);
        }
    }
}
