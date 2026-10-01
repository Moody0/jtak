using App.ApiControllers.V1.Delivery;
using App.ApiModels;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.Hubs;
using App.Shared.Services.Pricing;
using App.Shipping.Data;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Moq;
using Solf.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class DriverDispatchClaimAndPrivacyTests
    {
        private OrdersDbContext CreateInMemoryOrdersContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private AccountingDbContext CreateInMemoryAccountingContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private ShippingDbContext CreateInMemoryShippingContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<ShippingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new ShippingDbContext(options, null);
        }

        private DeliveryService CreateDeliveryService(
            ShippingDbContext shippingDb,
            IMemoryCache cache = null,
            IUserService userService = null)
        {
            var uow = new ShippingUnitOfWork(shippingDb);
            var repo = new TrackableRepository<ShippingOrder, ShippingDbContext>(shippingDb);
            var memCache = cache ?? new MemoryCache(new MemoryCacheOptions());
            var uService = userService ?? new Mock<IUserService>().Object;
            return new DeliveryService(repo, uow, memCache, uService);
        }

        private OrdersController CreateOrdersController(
            OrdersDbContext ordersDb,
            AccountingDbContext accountingDb,
            ShippingDbContext shippingDb,
            DeliveryService deliveryService,
            UserManager<AppUser> userManager = null,
            IOrderService orderService = null)
        {
            var auow = new AccountingUnitOfWork(accountingDb);
            var ouow = new OrdersUnitOfWork(ordersDb);
            var notificationMock = new Mock<INotificationService>();
            var merchantMock = new Mock<IMerchantService>();
            var productMock = new Mock<IProductService>();
            var billMock = new Mock<IBillService>();
            var balanceMock = new Mock<IBalanceService>();
            var ledgerMock = new Mock<ILedgerService>();
            var batchMock = new Mock<IInventoryBatchService>();
            var trackingHubMock = new Mock<IHubContext<TrackingHub>>();
            var mapperMock = new Mock<IMapper>();
            var moneyService = new OrderMoneyCalculationService();

            // Default merchant stops setup
            merchantMock.Setup(m => m.GetMerchantStops(It.IsAny<int[]>()))
                .ReturnsAsync((int[] ids) => ids.Select(id => (Lat: 33.51m, Lng: 36.29m, MerchantId: id)).ToArray());

            if (orderService == null)
            {
                var oServiceMock = new Mock<IOrderService>();
                oServiceMock.Setup(s => s.GetMerchantIds(It.IsAny<int>()))
                    .ReturnsAsync(new[] { 10 });
                orderService = oServiceMock.Object;
            }

            // Setup tracking hub clients mock to prevent NRE
            var hubClientsMock = new Mock<IHubClients>();
            var clientProxyMock = new Mock<IClientProxy>();
            hubClientsMock.Setup(h => h.Group(It.IsAny<string>())).Returns(clientProxyMock.Object);
            trackingHubMock.Setup(h => h.Clients).Returns(hubClientsMock.Object);

            var mgr = userManager ?? CreateMockUserManager();

            return new OrdersController(
                unitOfWork: null,
                auow: auow,
                ouow: ouow,
                notificationService: notificationMock.Object,
                userManager: mgr,
                merchantService: merchantMock.Object,
                productService: productMock.Object,
                deliveryService: deliveryService,
                service: orderService,
                billService: billMock.Object,
                balanceService: balanceMock.Object,
                ledgerService: ledgerMock.Object,
                batchService: batchMock.Object,
                trackingHub: trackingHubMock.Object,
                mapper: mapperMock.Object,
                logger: null,
                moneyCalculationService: moneyService);
        }

        private UserManager<AppUser> CreateMockUserManager(Dictionary<Guid, AppUser> users = null)
        {
            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManagerMock = new Mock<UserManager<AppUser>>(userStoreMock.Object, null, null, null, null, null, null, null, null);

            userManagerMock.Setup(m => m.FindByIdAsync(It.IsAny<string>()))
                .ReturnsAsync((string id) =>
                {
                    if (Guid.TryParse(id, out var gId) && users != null && users.TryGetValue(gId, out var u))
                        return u;

                    return new AppUser
                    {
                        Id = Guid.TryParse(id, out var parsed) ? parsed : Guid.NewGuid(),
                        FullName = $"Captain {id}",
                        UserName = $"driver_{id}",
                        MaxCashFloat = 50000m,
                        IsActive = true
                    };
                });

            return userManagerMock.Object;
        }

        private void SetDriverContext(OrdersController controller, Guid driverId)
        {
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, driverId.ToString()),
                        new Claim("sub", driverId.ToString())
                    }, "TestAuth"))
                }
            };
        }

        [Fact]
        public async Task OnlineDeliveryRecipients_ExcludeOfflineAndInactiveDrivers()
        {
            using var shippingDb = CreateInMemoryShippingContext();
            var onlineDriverId = Guid.NewGuid();
            var offlineDriverId = Guid.NewGuid();
            var inactiveDriverId = Guid.NewGuid();
            var userService = new Mock<IUserService>();
            userService.Setup(s => s.ListFromRoles(AppRoleName.Delivery.ToString()))
                .ReturnsAsync(new[]
                {
                    new AppUser { Id = onlineDriverId, IsActive = true },
                    new AppUser { Id = offlineDriverId, IsActive = true },
                    new AppUser { Id = inactiveDriverId, IsActive = false }
                });
            var deliveryService = CreateDeliveryService(shippingDb, userService: userService.Object);
            await deliveryService.SetDutyStatus(onlineDriverId, true);
            await deliveryService.SetDutyStatus(offlineDriverId, false);

            var recipients = await deliveryService.GetOnlineDeliveryIds();

            Assert.Equal(new[] { onlineDriverId }, recipients);
        }

        // =========================================================================
        // Test 1: Fifty parallel drivers claiming one order yield exactly one winner
        // =========================================================================
        [Fact]
        public async Task FiftyParallelDrivers_ClaimingOneOrder_YieldsExactlyOneWinner()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = null,
                DeliveryFee = 3000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                RowVersion = 0,
                CreatedDate = DateTime.UtcNow,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 10,
                        ProductId = 100,
                        Quantity = 1,
                        SinglePrice = 12000m,
                        SingleFinalPrice = 12000m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            int driverCount = 50;
            var driverIds = Enumerable.Range(1, driverCount).Select(_ => Guid.NewGuid()).ToArray();
            foreach (var driverId in driverIds)
                await deliveryService.SetDutyStatus(driverId, true);
            var successResults = new ConcurrentBag<Guid>();
            var failureResults = new ConcurrentBag<string>();

            // Run 50 parallel driver claims
            var tasks = driverIds.Select(async driverId =>
            {
                // Each concurrent task gets its own controller instance pointing to the shared DbContext
                var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService);
                SetDriverContext(controller, driverId);

                var response = await controller.ClaimOrder(order.Id);
                if (response.Value)
                {
                    successResults.Add(driverId);
                }
                else if (response.Result is BadRequestObjectResult badRequest)
                {
                    var err = badRequest.Value as ApiErr;
                    failureResults.Add(err != null ? string.Join("; ", err.Errors) : (badRequest.Value?.ToString() ?? ""));
                }
            });

            await Task.WhenAll(tasks);

            // Assertions
            Assert.Single(successResults);
            Assert.Equal(49, failureResults.Count);
            Assert.All(failureResults, msg => Assert.Contains("تم استلام هذا الطلب بالفعل من قبل كابتن آخر", msg));

            // Verify order in database
            var winnerId = successResults.First();
            var finalOrder = await ordersDb.Orders.FirstAsync(x => x.Id == order.Id);
            Assert.Equal(winnerId, finalOrder.DeliveryId);
            Assert.Equal(1, finalOrder.RowVersion);
        }

        // =========================================================================
        // Test 2: Route creation retry produces no duplicate stops
        // =========================================================================
        [Fact]
        public async Task RepeatedClaimOrRouteCreation_DoesNotCreateDuplicateStops()
        {
            var dbName = Guid.NewGuid().ToString();
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var driverId = Guid.NewGuid();
            int orderId = 55;

            var merchantStops = new[]
            {
                new ShippingOrderDto
                {
                    OrderId = orderId,
                    DriverId = driverId,
                    MerchantId = 10,
                    Lat = 33.51m,
                    Lng = 36.28m,
                    StopType = ShippingStopType.Pickup,
                    StopTitle = "Store 10"
                }
            };

            var customerStop = new ShippingOrderDto
            {
                OrderId = orderId,
                DriverId = driverId,
                Lat = 33.52m,
                Lng = 36.30m,
                StopType = ShippingStopType.Dropoff,
                StopTitle = "Customer House"
            };

            // Call AddOrder first time
            await deliveryService.AddOrder(driverId, orderId, merchantStops, customerStop);

            var stopsAfterFirst = await shippingDb.ShippingOrders
                .Where(x => x.OrderId == orderId && x.DriverId == driverId)
                .ToListAsync();
            Assert.Equal(2, stopsAfterFirst.Count); // 1 pickup + 1 dropoff

            // Call AddOrder second time (simulating network retry)
            await deliveryService.AddOrder(driverId, orderId, merchantStops, customerStop);

            var stopsAfterRetry = await shippingDb.ShippingOrders
                .Where(x => x.OrderId == orderId && x.DriverId == driverId)
                .ToListAsync();

            // Idempotency: Still exactly 2 stops in DB, not 4
            Assert.Equal(2, stopsAfterRetry.Count);

            // In-memory status also contains exactly 2 pending stops
            var status = await deliveryService.GetDeliveryStatus(driverId);
            Assert.Equal(2, status.PendingOrders.Count(x => x.OrderId == orderId));
        }

        // =========================================================================
        // Test 3: Configured cash float limit is enforced exactly (not hardcoded 5000)
        // =========================================================================
        [Fact]
        public async Task DriverCashFloatLimit_EnforcesConfiguredMaxCashFloat()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var driverAId = Guid.NewGuid();
            var driverBId = Guid.NewGuid();
            await deliveryService.SetDutyStatus(driverAId, true);
            await deliveryService.SetDutyStatus(driverBId, true);

            var users = new Dictionary<Guid, AppUser>
            {
                [driverAId] = new AppUser { Id = driverAId, FullName = "Driver A", MaxCashFloat = 10000m, IsActive = true },
                [driverBId] = new AppUser { Id = driverBId, FullName = "Driver B", MaxCashFloat = 50000m, IsActive = true }
            };
            var userManager = CreateMockUserManager(users);

            // Order with 15,000 SYP COD cash to collect
            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = null,
                DeliveryFee = 3000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 10,
                        ProductId = 101,
                        Quantity = 1,
                        SinglePrice = 12000m,
                        SingleFinalPrice = 12000m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            // Driver A has MaxCashFloat = 10,000 SYP, order COD is 15,000 SYP -> Must be rejected
            var controllerA = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, userManager);
            SetDriverContext(controllerA, driverAId);

            var resultA = await controllerA.ClaimOrder(order.Id);
            Assert.False(resultA.Value);
            var badRequestA = Assert.IsType<BadRequestObjectResult>(resultA.Result);
            var errA = Assert.IsType<ApiErr>(badRequestA.Value);
            var errText = string.Join("; ", errA.Errors);
            Assert.Contains("سقف العهدة النقدية المسموح به لك", errText);
            Assert.Contains("10,000", errText);

            // Driver B has MaxCashFloat = 50,000 SYP, order COD is 15,000 SYP -> Must succeed
            var controllerB = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, userManager);
            SetDriverContext(controllerB, driverBId);

            var resultB = await controllerB.ClaimOrder(order.Id);
            Assert.True(resultB.Value);

            var claimedOrder = await ordersDb.Orders.FirstAsync(x => x.Id == order.Id);
            Assert.Equal(driverBId, claimedOrder.DeliveryId);
        }

        // =========================================================================
        // Test 4: Unassigned available orders mask customer PII and coarsen coordinates
        // =========================================================================
        [Fact]
        public async Task UnassignedAvailableOrders_MaskCustomerPII_AndCoarsenCoordinates()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = null,
                User = "Ahmad Secret Customer",
                Phonenumber = "+963991234567",
                Address = "Mazzeh Villas, Building 14, 3rd Floor",
                Lat = 33.513829m,
                Lng = 36.276521m,
                DeliveryFee = 2500m,
                PurchaseDate = DateTime.UtcNow,
                CreatedDate = DateTime.UtcNow,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 5,
                        ProductId = 20,
                        Quantity = 1,
                        SinglePrice = 5000m,
                        SingleFinalPrice = 5000m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            // Setup OrderService for controller
            var oUow = new OrdersUnitOfWork(ordersDb);
            var oRepo = new TrackableRepository<Order, OrdersDbContext>(ordersDb);
            var dRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(ordersDb);
            var lRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(ordersDb);
            var orderService = new OrderService(oUow, new Mock<IMapper>().Object, CreateMockUserManager(), oRepo, lRepo, dRepo);

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, orderService: orderService);
            var driverId = Guid.NewGuid();
            await deliveryService.SetDutyStatus(driverId, true);
            SetDriverContext(controller, driverId);

            var availableResponse = await controller.PostAvailable(new MetronicTable { PageNumber = 1, PageSize = 10 });
            var tableResult = availableResponse.Value;

            Assert.NotNull(tableResult);
            Assert.NotEmpty(tableResult.Items);

            var availableOrder = tableResult.Items.First(x => x.Id == order.Id);

            // Verify Customer PII is masked before assignment
            Assert.Null(availableOrder.Phonenumber);
            Assert.Equal("عميل جتك", availableOrder.User);
            Assert.Equal("المنطقة العامة (مخفي حتى الاستلام)", availableOrder.Address);

            // Verify GPS coordinates are coarsened to 2 decimal places (~1.1km grid)
            Assert.Equal(33.51m, availableOrder.Lat);
            Assert.Equal(36.28m, availableOrder.Lng);
        }

        [Fact]
        public async Task OfflineDriver_CannotClaimAvailableOrder()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);
            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = null,
                CreatedDate = DateTime.UtcNow,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { MerchantId = 10, ProductId = 100, Quantity = 1, SinglePrice = 100m,
                        SingleFinalPrice = 100m, OrderDetailStatus = OrderDetailStatus.ReadyForPickup }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            var driverId = Guid.NewGuid();
            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService);
            SetDriverContext(controller, driverId);

            var response = await controller.ClaimOrder(order.Id);

            Assert.False(response.Value);
            var badRequest = Assert.IsType<BadRequestObjectResult>(response.Result);
            var error = Assert.IsType<ApiErr>(badRequest.Value);
            Assert.Contains("يجب بدء وردية التوصيل", string.Join("; ", error.Errors));
            Assert.Null((await ordersDb.Orders.FirstAsync(x => x.Id == order.Id)).DeliveryId);
        }

        [Fact]
        public async Task Driver_CanClaimTimedOutOfferUntilMatchingWindowEnds()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersConnection = new SqliteConnection("Data Source=:memory:");
            await ordersConnection.OpenAsync();
            var ordersOptions = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseSqlite(ordersConnection).Options;
            using var ordersDb = new OrdersDbContext(ordersOptions, null);
            await ordersDb.Database.EnsureCreatedAsync();
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);
            var driverId = Guid.NewGuid();
            await deliveryService.SetDutyStatus(driverId, true);

            var now = DateTime.UtcNow;
            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = null,
                DeliveryFee = 3000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CourierMatchingStartedAtUtc = now.AddSeconds(-30),
                CourierMatchingDeadlineAtUtc = now.AddMinutes(2).AddSeconds(30),
                CourierMatchingRound = 1,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 10,
                        ProductId = 100,
                        Quantity = 1,
                        SinglePrice = 12000m,
                        SingleFinalPrice = 12000m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();
            ordersDb.OrderDispatchOffers.Add(new OrderDispatchOffer
            {
                OrderId = order.Id,
                DriverId = driverId,
                MatchingRound = 1,
                WaveNumber = 1,
                OfferedAtUtc = now.AddSeconds(-26),
                ExpiresAtUtc = now.AddSeconds(-1),
                RespondedAtUtc = now,
                Status = OrderDispatchOfferStatus.TimedOut
            });
            await ordersDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService);
            SetDriverContext(controller, driverId);

            var response = await controller.ClaimOrder(order.Id);

            var claimError = response.Result is BadRequestObjectResult badRequest &&
                             badRequest.Value is ApiErr apiError
                ? string.Join("; ", apiError.Errors)
                : response.Result?.ToString();
            Assert.True(response.Value, claimError);
            Assert.Equal(driverId, (await ordersDb.Orders.SingleAsync(x => x.Id == order.Id)).DeliveryId);
            Assert.Equal(OrderDispatchOfferStatus.Accepted,
                (await ordersDb.OrderDispatchOffers.AsNoTracking().SingleAsync(x => x.OrderId == order.Id)).Status);
        }

        [Fact]
        public async Task OfflineDriver_DoesNotReceiveAvailableOrders()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);
            var driverId = Guid.NewGuid();
            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService);
            SetDriverContext(controller, driverId);

            var response = await controller.PostAvailable(new MetronicTable { PageNumber = 1, PageSize = 10 });

            var ok = Assert.IsType<OkObjectResult>(response.Result);
            var result = Assert.IsType<TableResponseModel<DeliveryOrderDto>>(ok.Value);
            Assert.Empty(result.Items);
            Assert.Equal(0, result.TotalRecords);
        }

        // =========================================================================
        // Test 5: Claimed orders expose full PII to assigned driver, forbidden to others
        // =========================================================================
        [Fact]
        public async Task ClaimedOrders_ExposeFullCustomerPII_ToAssignedDriverOnly()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var driverAId = Guid.NewGuid();
            var driverBId = Guid.NewGuid();

            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = driverAId, // Assigned to Driver A
                DeliveryUser = "Driver A",
                User = "Ahmad Secret Customer",
                Phonenumber = "+963991234567",
                Address = "Mazzeh Villas, Building 14, 3rd Floor",
                Lat = 33.513829m,
                Lng = 36.276521m,
                DeliveryFee = 2500m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 5,
                        ProductId = 20,
                        Quantity = 1,
                        SinglePrice = 5000m,
                        SingleFinalPrice = 5000m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            var oUow = new OrdersUnitOfWork(ordersDb);
            var oRepo = new TrackableRepository<Order, OrdersDbContext>(ordersDb);
            var dRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(ordersDb);
            var lRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(ordersDb);
            var orderService = new OrderService(oUow, new Mock<IMapper>().Object, CreateMockUserManager(), oRepo, lRepo, dRepo);

            // Driver A (Assigned Driver) views order details
            var controllerA = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, orderService: orderService);
            SetDriverContext(controllerA, driverAId);

            var getResultA = await controllerA.Get(order.Id);
            var orderDetailsA = getResultA.Value;

            Assert.NotNull(orderDetailsA);
            Assert.Equal("+963991234567", orderDetailsA.Phonenumber);
            Assert.Equal("Mazzeh Villas, Building 14, 3rd Floor", orderDetailsA.Address);
            Assert.Equal(33.513829m, orderDetailsA.Lat);
            Assert.Equal(36.276521m, orderDetailsA.Lng);

            // Driver B (Unassigned Driver) tries to view order details -> Must be Forbidden (403)
            var controllerB = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, orderService: orderService);
            SetDriverContext(controllerB, driverBId);

            var getResultB = await controllerB.Get(order.Id);
            Assert.IsType<ForbidResult>(getResultB.Result);
        }

        // =========================================================================
        // Test 6: Delivery responses include complete canonical money and delivery fee
        // =========================================================================
        [Fact]
        public async Task DeliveryResponses_IncludeCompleteCanonicalMoneyAndFee()
        {
            var dbName = Guid.NewGuid().ToString();
            using var ordersDb = CreateInMemoryOrdersContext(dbName);
            using var accountingDb = CreateInMemoryAccountingContext(dbName);
            using var shippingDb = CreateInMemoryShippingContext(dbName);
            var deliveryService = CreateDeliveryService(shippingDb);

            var driverId = Guid.NewGuid();

            var order = new Order
            {
                OrderStatus = OrderStatus.Success,
                DeliveryId = driverId,
                DeliveryUser = "Captain",
                DeliveryFee = 4000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail
                    {
                        MerchantId = 8,
                        Quantity = 2,
                        SinglePrice = 10000m,
                        SingleFinalPrice = 8500m,
                        OrderDetailStatus = OrderDetailStatus.ReadyForPickup
                    },
                    new OrderDetail
                    {
                        MerchantId = 8,
                        Quantity = 1,
                        SinglePrice = 5000m,
                        SingleFinalPrice = 5000m,
                        OrderDetailStatus = OrderDetailStatus.MerchantRejected // Rejected line item
                    }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            var oUow = new OrdersUnitOfWork(ordersDb);
            var oRepo = new TrackableRepository<Order, OrdersDbContext>(ordersDb);
            var dRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(ordersDb);
            var lRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(ordersDb);
            var orderService = new OrderService(oUow, new Mock<IMapper>().Object, CreateMockUserManager(), oRepo, lRepo, dRepo);

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, deliveryService, orderService: orderService);
            SetDriverContext(controller, driverId);

            var getResult = await controller.Get(order.Id);
            var deliveryOrder = getResult.Value;

            Assert.NotNull(deliveryOrder);
            Assert.Equal(4000m, deliveryOrder.DeliveryFee);
            Assert.NotNull(deliveryOrder.Money);

            // Canonical calculation: Accepted items = 2 * 8500 = 17,000. DeliveryFee = 4,000. GrandTotal = 21,000.
            Assert.Equal(17000m, deliveryOrder.Money.ProductSubtotal);
            Assert.Equal(4000m, deliveryOrder.Money.DeliveryFee);
            Assert.Equal(21000m, deliveryOrder.Money.GrandTotal);
            Assert.Equal(21000m, deliveryOrder.CashToCollect);
        }

        // =========================================================================
        // Test 7: Server restart preserves duty state or safely marks unknown offline
        // =========================================================================
        [Fact]
        public async Task ServerRestart_PreservesDutyStateOrMarksOffline()
        {
            var dbName = Guid.NewGuid().ToString();
            var driverId = Guid.NewGuid();
            var unknownDriverId = Guid.NewGuid();

            // Phase A: First server lifetime - driver comes online and updates GPS location
            using (var shippingDb1 = CreateInMemoryShippingContext(dbName))
            {
                var cache1 = new MemoryCache(new MemoryCacheOptions());
                var service1 = CreateDeliveryService(shippingDb1, cache1);

                await service1.SetDutyStatus(driverId, true);
                await service1.UpdateDeliveryLocation(driverId, (33.5138m, 36.2765m), heading: 90, speed: 25);

                var liveStatus = await service1.GetDeliveryStatus(driverId);
                Assert.True(liveStatus.IsOnline);
                Assert.NotNull(liveStatus.ShiftStartedAt);
                Assert.NotNull(liveStatus.LastLocationUpdatedAt);
            }

            // Phase B: Simulate full server restart (new service instance with fresh/empty memory cache)
            using (var shippingDb2 = CreateInMemoryShippingContext(dbName))
            {
                var cache2 = new MemoryCache(new MemoryCacheOptions()); // Empty cache!
                var service2 = CreateDeliveryService(shippingDb2, cache2);

                // Driver who had duty persisted should be reloaded from DB as online with location restored
                var restoredStatus = await service2.GetDeliveryStatus(driverId);
                Assert.True(restoredStatus.IsOnline);
                Assert.NotNull(restoredStatus.ShiftStartedAt);
                Assert.Equal(33.5138m, restoredStatus.Loc.Lat);
                Assert.Equal(36.2765m, restoredStatus.Loc.Lng);
                Assert.NotNull(restoredStatus.LastLocationUpdatedAt);

                // Unknown driver who never set duty should safely default to offline
                var unknownStatus = await service2.GetDeliveryStatus(unknownDriverId);
                Assert.False(unknownStatus.IsOnline);
                Assert.Null(unknownStatus.ShiftStartedAt);
            }
        }

        // =========================================================================
        // Test 8: Stale GPS location is excluded from dispatch candidate pool
        // =========================================================================
        [Fact]
        public async Task StaleGpsLocation_IsExcludedFromDispatch()
        {
            var dbName = Guid.NewGuid().ToString();
            using var shippingDb = CreateInMemoryShippingContext(dbName);

            var courierFreshId = Guid.NewGuid();
            var courierStaleId = Guid.NewGuid();

            var deliveryUsers = new[]
            {
                new AppUser { Id = courierFreshId, FullName = "Fresh Courier", IsActive = true },
                new AppUser { Id = courierStaleId, FullName = "Stale Courier", IsActive = true }
            };

            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userServiceMock = new Mock<IUserService>();
            userServiceMock.Setup(u => u.ListFromRoles(AppRoleName.Delivery.ToString()))
                .ReturnsAsync(deliveryUsers);

            var deliveryService = CreateDeliveryService(shippingDb, userService: userServiceMock.Object);

            // Setup fresh courier (GPS updated 2 minutes ago)
            await deliveryService.SetDutyStatus(courierFreshId, true);
            await deliveryService.UpdateDeliveryLocation(courierFreshId, (33.51m, 36.28m));

            // Setup stale courier (GPS updated 45 minutes ago)
            await deliveryService.SetDutyStatus(courierStaleId, true);
            await deliveryService.UpdateDeliveryLocation(courierStaleId, (33.50m, 36.27m));

            // Manually age the stale courier's location timestamp in DB & cache
            var staleDuty = await shippingDb.DriverDuties.FirstAsync(x => x.DriverId == courierStaleId);
            staleDuty.LastLocationUpdatedAt = DateTime.UtcNow.AddMinutes(-45);
            await shippingDb.SaveChangesAsync();

            var staleStatus = await deliveryService.GetDeliveryStatus(courierStaleId);
            staleStatus.LastLocationUpdatedAt = DateTime.UtcNow.AddMinutes(-45);

            // Dispatch pick
            var merchantStops = new[] { (Lat: 33.51m, Lng: 36.28m, MerchantId: 10) };
            var best = await deliveryService.PickBestDelivery(merchantStops);

            // Stale courier must be rejected/excluded; fresh courier must be picked
            Assert.Equal(courierFreshId, best.Id);
        }
    }
}
