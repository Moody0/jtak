using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiControllers.V1.Customer.Orders;
using App.ApiModels;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using App.Shared.Services.Extentions;
using App.Shared.Services.Pricing;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class SafeCheckoutAndOrderCreationTests
    {
        private OrdersDbContext CreateInMemoryOrdersContext()
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private CatalogDbContext CreateInMemoryCatalogContext()
        {
            var options = new DbContextOptionsBuilder<CatalogDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new CatalogDbContext(options, null);
        }

        private (CartController controller, OrdersDbContext db, CatalogDbContext catalogDb, AppUser testUser) CreateTestController(
            OrdersDbContext ordersDb = null,
            CatalogDbContext catDb = null,
            Action<Mock<IMerchantService>> configureMerchant = null,
            Action<Mock<IProductService>> configureProduct = null,
            Action<Mock<IInventoryBatchService>> configureBatch = null,
            Action<Mock<INotificationService>> configureNotification = null,
            TimeProvider timeProvider = null,
            IDriverPricingService driverPricingService = null)
        {
            var db = ordersDb ?? CreateInMemoryOrdersContext();
            var catalogDb = catDb ?? CreateInMemoryCatalogContext();

            var uow = new OrdersUnitOfWork(db);
            var orderRepo = new TrackableRepository<Order, OrdersDbContext>(db);
            var logRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(db);
            var detailRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(db);

            var testUser = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Rami Customer",
                UserName = "+963991234567",
                PhoneNumber = "+963991234567",
                IsActive = true
            };

            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManagerMock = new Mock<UserManager<AppUser>>(userStoreMock.Object, null, null, null, null, null, null, null, null);
            userManagerMock.Setup(m => m.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(testUser);
            userManagerMock.Setup(m => m.FindByIdAsync(It.IsAny<string>())).ReturnsAsync(testUser);
            userManagerMock.Setup(m => m.FindByNameAsync(It.IsAny<string>())).ReturnsAsync(testUser);
            userManagerMock.Setup(m => m.GetUsersInRoleAsync(It.IsAny<string>())).ReturnsAsync(new List<AppUser>());

            var mapperMock = new Mock<IMapper>();
            var orderService = new OrderService(uow, mapperMock.Object, userManagerMock.Object, orderRepo, logRepo, detailRepo);
            var orderDetailService = new OrderDetailService(detailRepo);

            var defaultMerchant = new Modules.Catalog.Entities.Merchant
            {
                Id = 10,
                Title = "Al-Sham Supermarket",
                Active = true,
                MinOrderAmount = 10000m,
                ShippingCoverageInMeters = 10000, // 10km
                Lat = 33.5138m,
                Lng = 36.2765m,
                DeliveryFee = 3000m
            };
            catalogDb.Merchants.Add(defaultMerchant);
            catalogDb.SaveChanges();

            var merchantMock = new Mock<IMerchantService>();
            merchantMock.Setup(m => m.Queryable()).Returns(catalogDb.Merchants);
            merchantMock.Setup(m => m.FindAsync(10)).ReturnsAsync(defaultMerchant);
            merchantMock.Setup(m => m.GetMerchantProductPrice(10, 101)).ReturnsAsync(new MerchantProductDto
            {
                MerchantId = 10,
                MerchantPrice = 12000m,
                ProfitOutOfMerchantPricePercent = 10m
            });
            merchantMock.Setup(m => m.GetUsdRate()).ReturnsAsync(0m);
            merchantMock.Setup(m => m.GetOwnerId(10)).ReturnsAsync(Guid.NewGuid());

            configureMerchant?.Invoke(merchantMock);

            var productMock = new Mock<IProductService>();
            productMock.Setup(p => p.GetProduct(101)).ReturnsAsync(new ProductLiteDto
            {
                Id = 101,
                Title = "Olive Oil Extra Virgin 1L",
                Unit = "Bottle"
            });
            configureProduct?.Invoke(productMock);

            var batchMock = new Mock<IInventoryBatchService>();
            batchMock.Setup(b => b.ReserveStockFEFOAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()))
                .ReturnsAsync(new List<BatchReservationDto>());
            configureBatch?.Invoke(batchMock);

            var notifMock = new Mock<INotificationService>();
            configureNotification?.Invoke(notifMock);

            var calcService = new OrderMoneyCalculationService();
            var logger = NullLogger<CartController>.Instance;

            var controller = new CartController(
                uow,
                notifMock.Object,
                userManagerMock.Object,
                productMock.Object,
                orderService,
                orderDetailService,
                merchantMock.Object,
                batchMock.Object,
                logger,
                mapperMock.Object,
                calcService,
                timeProvider ?? new FixedTimeProvider(new DateTimeOffset(2026, 9, 22, 12, 0, 0, TimeSpan.Zero)),
                driverPricingService);

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, testUser.Id.ToString()),
                new Claim(ClaimTypes.Name, testUser.UserName)
            };
            var identity = new ClaimsIdentity(claims, "TestAuth");
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }
            };

            return (controller, db, catalogDb, testUser);
        }

        private sealed class FixedTimeProvider : TimeProvider
        {
            private readonly DateTimeOffset _utcNow;

            public FixedTimeProvider(DateTimeOffset utcNow)
            {
                _utcNow = utcNow;
            }

            public override DateTimeOffset GetUtcNow() => _utcNow;
        }

        [Fact]
        public void HomsDeliveryArea_UsesMapCoordinatesAndCoversCitySuburbs()
        {
            Assert.Equal(25000.0, HomsDeliveryArea.RadiusMeters);
            Assert.True(HomsDeliveryArea.Contains(34.7333m, 36.7167m)); // centre
            Assert.True(HomsDeliveryArea.Contains(34.7444m, 36.67292m)); // Al-Waer
            Assert.True(HomsDeliveryArea.Contains(34.68508m, 36.69004m)); // Kafr Aya
            Assert.True(HomsDeliveryArea.Contains(34.70299m, 36.75728m)); // Fairouzeh
            Assert.True(HomsDeliveryArea.Contains(34.9300m, 36.7167m)); // about 22 km north
            Assert.False(HomsDeliveryArea.Contains(35.0000m, 36.7167m)); // about 30 km north
            Assert.False(HomsDeliveryArea.Contains(33.5138m, 36.2765m)); // Damascus
            Assert.False(HomsDeliveryArea.Contains(0m, 0m));
        }

        [Theory]
        [InlineData(false, false)]
        [InlineData(true, false)]
        [InlineData(false, true)]
        [InlineData(true, true)]
        public async Task SubmitOrder_DualCheckout_SeparatesMoneyAndReplay_OrRollsBackBoth(bool marketStockFails, bool relational)
        {
            using var connection = new SqliteConnection("Data Source=:memory:");
            OrdersDbContext relationalDb = null;
            if (relational)
            {
                await connection.OpenAsync();
                relationalDb = new OrdersDbContext(new DbContextOptionsBuilder<OrdersDbContext>()
                    .UseSqlite(connection).Options, new HttpContextAccessor());
                await relationalDb.Database.EnsureCreatedAsync();
            }
            var pricing = new Mock<IDriverPricingService>();
            pricing.Setup(x => x.GetSettingAsync()).ReturnsAsync(new DriverPricingSetting
            { Mode = DriverPricingMode.Fixed, FixedAmount = 6500m });
            pricing.Setup(x => x.CalculateCaptainEarning(It.IsAny<DriverPricingSetting>(),
                It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>()))
                .Returns(6500m);
            var released = new List<int>();
            var (controller, orders, _, customer) = CreateTestController(
                ordersDb: relationalDb,
                driverPricingService: pricing.Object,
                configureBatch: batch =>
                {
                    if (marketStockFails)
                        batch.Setup(x => x.ReserveStockFEFOAsync(It.IsAny<int>(), It.IsAny<int>(),
                            102, 11, It.IsAny<int>(), It.IsAny<int>()))
                            .ThrowsAsync(new InvalidOperationException("Market stock exhausted"));
                    batch.Setup(x => x.ReleaseReservationAsync(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<string>(), It.IsAny<int?>()))
                        .Callback<int, int?, string, int?>((id, detail, reason, merchant) => released.Add(id))
                        .Returns(Task.CompletedTask);
                },
                configureMerchant: merchants =>
                {
                    var market = new Modules.Catalog.Entities.Merchant
                    {
                        Id = 11, Title = "JTAK Market", MerchantKind = MerchantKind.Grocery,
                        Active = true, DeliveryFee = 4000m, MinOrderAmount = 5000m
                    };
                    merchants.Setup(m => m.FindAsync(11)).ReturnsAsync(market);
                    merchants.Setup(m => m.GetMerchantProductPrice(11, 102)).ReturnsAsync(new MerchantProductDto
                    {
                        MerchantId = 11, MerchantPrice = 12000m, ProfitOutOfMerchantPricePercent = 10m
                    });
                },
                configureProduct: products => products.Setup(p => p.GetProduct(102)).ReturnsAsync(new ProductLiteDto
                {
                    Id = 102, Title = "Market Product", Unit = "Pack"
                }));

            var items = new[]
            {
                new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 },
                new CartItem { ProductId = 102, MerchantId = 11, Quantity = 1 }
            };

            // 1. GetCalc succeeds and returns combined delivery fee (3000 + 4000 = 7000)
            var calcResult = await controller.GetCalc(34.7333m, 36.7167m, items);
            Assert.NotNull(calcResult.Value);
            Assert.Equal(7000m, calcResult.Value.DeliveryFee);
            Assert.Equal(13000m, calcResult.Value.Money.CaptainEarning);

            // 2. SubmitOrder succeeds and creates 2 separate orders
            var submit = new CartSubmit
            {
                IdempotencyKey = "dual-order-key-1",
                Phonenumber = customer.PhoneNumber,
                Lat = 34.7333m, Lng = 36.7167m,
                Address = "Homs",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = items
            };
            var actionResult = await controller.SubmitOrder(submit);
            if (marketStockFails)
            {
                Assert.IsType<BadRequestObjectResult>(actionResult.Result);
                // The test provider uses the domain's soft-delete cleanup;
                // production relational transactions roll both inserts back.
                Assert.Empty(await orders.Orders.Where(o => o.DeletionDate == null).ToListAsync());
                Assert.Empty(await orders.OrderDetails.ToListAsync());
                Assert.Empty(await orders.OrderOutboxMessages.ToListAsync());
                Assert.Equal(2, released.Distinct().Count());
                return;
            }
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var returnedDto = Assert.IsType<OrderDto>(okResult.Value);

            // Sibling orders returned
            Assert.NotNull(returnedDto.SiblingOrders);
            Assert.Equal(2, returnedDto.SiblingOrders.Count);

            // Database has exactly 2 orders created
            var dbOrders = await orders.Orders.Include(x => x.OrderDetails).OrderBy(x => x.Id).ToListAsync();
            Assert.All(dbOrders, created =>
            {
                Assert.Matches("^[0-9]{4}$", created.DeliveryOtp);
                Assert.Null(created.DeliveryOtpExpiresAt);
            });
            Assert.Equal(2, dbOrders.Count);

            var restOrder = dbOrders.First(x => x.IdempotencyKey.EndsWith("_rest"));
            var mktOrder = dbOrders.First(x => x.IdempotencyKey.EndsWith("_mkt"));

            // Both orders belong to the same user
            Assert.Equal(customer.Id, restOrder.UserId);
            Assert.Equal(customer.Id, mktOrder.UserId);
            Assert.Equal(customer.FullName, restOrder.User);
            Assert.Equal(customer.FullName, mktOrder.User);

            // Each order is separate and has its merchant's details
            Assert.Equal(3000m, restOrder.DeliveryFee);
            Assert.Single(restOrder.OrderDetails);
            Assert.Equal(10, restOrder.OrderDetails.First().MerchantId);
            Assert.Equal(101, restOrder.OrderDetails.First().ProductId);

            Assert.Equal(4000m, mktOrder.DeliveryFee);
            Assert.Single(mktOrder.OrderDetails);
            Assert.Equal(11, mktOrder.OrderDetails.First().MerchantId);
            Assert.Equal(102, mktOrder.OrderDetails.First().ProductId);

            Assert.Equal((int)MerchantKind.Restaurant, returnedDto.SiblingOrders[0].MerchantKind);
            Assert.Equal((int)MerchantKind.Grocery, returnedDto.SiblingOrders[1].MerchantKind);
            foreach (var child in returnedDto.SiblingOrders)
            {
                Assert.Equal(6500m, child.Money.CaptainEarning);
                Assert.Equal(child.OrderDetails.Sum(d => d.TotalFinalPrice) + child.DeliveryFee, child.CashToCollect);
            }
            Assert.Equal(calcResult.Value.CashToCollect, returnedDto.SiblingOrders.Sum(o => o.CashToCollect));
            var messageCount = await orders.OrderOutboxMessages.CountAsync();
            var replay = Assert.IsType<OrderDto>(Assert.IsType<OkObjectResult>((await controller.SubmitOrder(submit)).Result).Value);
            Assert.Equal(returnedDto.RelatedOrderIds, replay.RelatedOrderIds);
            Assert.Equal(returnedDto.SiblingOrders.Select(o => o.Money.CaptainEarning), replay.SiblingOrders.Select(o => o.Money.CaptainEarning));
            Assert.All(replay.SiblingOrders, o => Assert.Equal(Modules.Orders.Entities.PaymentMethod.PayOnDelivery, o.PaymentMethod));
            Assert.Equal(2, await orders.Orders.CountAsync());
            Assert.Equal(messageCount, await orders.OrderOutboxMessages.CountAsync());

            var transition = new OrderTransitionService(new OrdersUnitOfWork(orders),
                new TrackableRepository<Order, OrdersDbContext>(orders),
                new TrackableRepository<OrderDetail, OrdersDbContext>(orders),
                new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(orders));
            await transition.TransitionMerchantOrderAsync(mktOrder.Id, 11, OrderDetailStatus.MerchantRejected);
            Assert.All(restOrder.OrderDetails, d => Assert.Equal(OrderDetailStatus.Pending, d.OrderDetailStatus));
            Assert.All(mktOrder.OrderDetails, d => Assert.Equal(OrderDetailStatus.MerchantRejected, d.OrderDetailStatus));
        }

        [Fact]
        public async Task SubmitOrder_SnapshotsAdminConfiguredDriverEarning()
        {
            var pricing = new Mock<IDriverPricingService>();
            pricing.Setup(x => x.GetSettingAsync()).ReturnsAsync(new DriverPricingSetting
            {
                Mode = DriverPricingMode.Fixed,
                FixedAmount = 6500m
            });
            pricing.Setup(x => x.CalculateCaptainEarning(
                    It.IsAny<DriverPricingSetting>(),
                    It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>(), It.IsAny<decimal>()))
                .Returns(6500m);

            var (controller, orders, _, customer) = CreateTestController(driverPricingService: pricing.Object);
            var items = new[] { new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 } };

            var preview = await controller.GetCalc(34.7333m, 36.7167m, items);
            Assert.Equal(6500m, preview.Value.Money.CaptainEarning);
            Assert.Equal(0m, preview.Value.Money.PlatformDeliveryRevenue);
            Assert.Equal(3500m, preview.Value.Money.DriverEarningSubsidy);

            var submit = new CartSubmit
            {
                IdempotencyKey = "driver-pricing-snapshot",
                Phonenumber = customer.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Homs",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = items
            };
            var response = await controller.SubmitOrder(submit);
            Assert.IsType<OkObjectResult>(response.Result);

            var savedOrder = await orders.Orders.SingleAsync();
            Assert.Equal(6500m, savedOrder.CaptainEarning);
            var snapshot = OrderMoneySnapshot.Deserialize(savedOrder.MoneySnapshotJson);
            Assert.Equal(6500m, snapshot.CaptainEarning);
            Assert.Equal(3500m, snapshot.DriverEarningSubsidy);
            pricing.Verify(x => x.GetSettingAsync(), Times.Exactly(2));
            pricing.Verify(x => x.CalculateCaptainEarning(
                It.IsAny<DriverPricingSetting>(),
                34.7333m, 36.7167m, 33.5138m, 36.2765m, 3000m), Times.Exactly(2));
        }

        [Fact]
        public async Task SubmitOrder_RejectsTwoRestaurantsInOneOrder()
        {
            var (controller, orders, _, customer) = CreateTestController(
                configureMerchant: merchants =>
                {
                    var rest2 = new Modules.Catalog.Entities.Merchant
                    {
                        Id = 12, Title = "Burger House", MerchantKind = MerchantKind.Restaurant,
                        Active = true, DeliveryFee = 3500m
                    };
                    merchants.Setup(m => m.FindAsync(12)).ReturnsAsync(rest2);
                    merchants.Setup(m => m.GetMerchantProductPrice(12, 103)).ReturnsAsync(new MerchantProductDto
                    {
                        MerchantId = 12, MerchantPrice = 15000m
                    });
                },
                configureProduct: products => products.Setup(p => p.GetProduct(103)).ReturnsAsync(new ProductLiteDto
                {
                    Id = 103, Title = "Burger Meal", Unit = "Piece"
                }));

            var items = new[]
            {
                new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 },
                new CartItem { ProductId = 103, MerchantId = 12, Quantity = 1 }
            };

            var calcRes = await controller.GetCalc(34.7333m, 36.7167m, items);
            Assert.IsType<BadRequestObjectResult>(calcRes.Result);

            var submit = new CartSubmit
            {
                IdempotencyKey = "two-restaurants-rejected",
                Phonenumber = customer.PhoneNumber,
                Lat = 34.7333m, Lng = 36.7167m,
                Address = "Homs",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = items
            };
            var result = await controller.SubmitOrder(submit);
            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Equal(0, await orders.Orders.CountAsync());
        }

        [Fact]
        public async Task SubmitOrder_RejectsTwoMarketsInOneOrder()
        {
            var (controller, orders, _, customer) = CreateTestController(
                configureMerchant: merchants =>
                {
                    var mkt1 = new Modules.Catalog.Entities.Merchant
                    {
                        Id = 21, Title = "Market A", MerchantKind = MerchantKind.Grocery,
                        Active = true, DeliveryFee = 3000m
                    };
                    var mkt2 = new Modules.Catalog.Entities.Merchant
                    {
                        Id = 22, Title = "Market B", MerchantKind = MerchantKind.Store,
                        Active = true, DeliveryFee = 3000m
                    };
                    merchants.Setup(m => m.FindAsync(21)).ReturnsAsync(mkt1);
                    merchants.Setup(m => m.FindAsync(22)).ReturnsAsync(mkt2);
                    merchants.Setup(m => m.GetMerchantProductPrice(21, 201)).ReturnsAsync(new MerchantProductDto
                    {
                        MerchantId = 21, MerchantPrice = 10000m
                    });
                    merchants.Setup(m => m.GetMerchantProductPrice(22, 202)).ReturnsAsync(new MerchantProductDto
                    {
                        MerchantId = 22, MerchantPrice = 10000m
                    });
                },
                configureProduct: products =>
                {
                    products.Setup(p => p.GetProduct(201)).ReturnsAsync(new ProductLiteDto { Id = 201, Title = "Prod 1", Unit = "Pack" });
                    products.Setup(p => p.GetProduct(202)).ReturnsAsync(new ProductLiteDto { Id = 202, Title = "Prod 2", Unit = "Pack" });
                });

            var items = new[]
            {
                new CartItem { ProductId = 201, MerchantId = 21, Quantity = 1 },
                new CartItem { ProductId = 202, MerchantId = 22, Quantity = 1 }
            };

            var calcRes = await controller.GetCalc(34.7333m, 36.7167m, items);
            Assert.IsType<BadRequestObjectResult>(calcRes.Result);

            var submit = new CartSubmit
            {
                IdempotencyKey = "two-markets-rejected",
                Phonenumber = customer.PhoneNumber,
                Lat = 34.7333m, Lng = 36.7167m,
                Address = "Homs",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = items
            };
            var result = await controller.SubmitOrder(submit);
            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Equal(0, await orders.Orders.CountAsync());
        }

        [Fact]
        public async Task Test01_SubmitOrder_TwoSubmissionsWithSameIdempotencyKey_CreatesExactlyOneOrder()
        {
            var db = CreateInMemoryOrdersContext();
            var (controller, _, _, testUser) = CreateTestController(db);

            var submitRequest = new CartSubmit
            {
                // This old address label and the merchant's 10 km radius must not
                // override a delivery pin in Homs.
                IdempotencyKey = "key_test_001",
                Phonenumber = testUser.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Mazzeh, Damascus",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 101, MerchantId = 10, Quantity = 2 }
                }
            };

            // First submission
            var response1 = await controller.SubmitOrder(submitRequest);
            var okResult1 = Assert.IsType<OkObjectResult>(response1.Result);
            var order1 = Assert.IsType<OrderDto>(okResult1.Value);
            Assert.True(order1.Id > 0);
            Assert.Equal("key_test_001", order1.IdempotencyKey);

            // Second simultaneous or immediate submission with SAME idempotency key
            var response2 = await controller.SubmitOrder(submitRequest);
            var okResult2 = Assert.IsType<OkObjectResult>(response2.Result);
            var order2 = Assert.IsType<OrderDto>(okResult2.Value);

            // Both requests must return the EXACT same order ID
            Assert.Equal(order1.Id, order2.Id);

            // Exactly ONE order must exist in the database for this idempotency key
            var totalOrdersInDb = await db.Orders.CountAsync(o => o.IdempotencyKey == "key_test_001");
            Assert.Equal(1, totalOrdersInDb);

            // One merchant event and one admin event are created once, even
            // when the client retries the checkout request.
            var outboxMessages = await db.OrderOutboxMessages
                .Where(x => x.OrderId == order1.Id)
                .ToListAsync();
            Assert.Equal(2, outboxMessages.Count);
            Assert.Equal(2, outboxMessages.Select(x => x.BusinessKey).Distinct().Count());
        }

        [Fact]
        public async Task Test02_SubmitOrder_RetryAfterTimeout_ReturnsExistingOrderWithoutDuplication()
        {
            var db = CreateInMemoryOrdersContext();
            var (controller, _, _, testUser) = CreateTestController(db);

            var submitRequest = new CartSubmit
            {
                IdempotencyKey = "key_timeout_retry_999",
                Phonenumber = testUser.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Damascus Center",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 }
                }
            };

            // Initial attempt
            var firstAttempt = await controller.SubmitOrder(submitRequest);
            var firstOrder = Assert.IsType<OrderDto>(((OkObjectResult)firstAttempt.Result).Value);

            // Simulated client timeout and retry with identical body
            var retryAttempt = await controller.SubmitOrder(submitRequest);
            var retriedOrder = Assert.IsType<OrderDto>(((OkObjectResult)retryAttempt.Result).Value);

            Assert.Equal(firstOrder.Id, retriedOrder.Id);
            Assert.Equal(firstOrder.Money.GrandTotal, retriedOrder.Money.GrandTotal);
            Assert.Equal(firstOrder.CashToCollect, retriedOrder.CashToCollect);

            var ordersCount = await db.Orders.CountAsync(o => o.UserId == testUser.Id);
            Assert.Equal(1, ordersCount);
        }

        [Fact]
        public async Task Test03_SubmitOrder_NotificationFailure_DoesNotFailOrDuplicateCheckout()
        {
            var db = CreateInMemoryOrdersContext();
            var (controller, _, _, testUser) = CreateTestController(
                db,
                configureNotification: notifMock =>
                {
                    notifMock.Setup(n => n.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
                        .ThrowsAsync(new InvalidOperationException("Firebase notification gateway timed out"));
                });

            var submitRequest = new CartSubmit
            {
                IdempotencyKey = "key_notif_fail_safe",
                Phonenumber = testUser.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Abu Rummaneh, Damascus",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 }
                }
            };

            // Act: Submit order while notifications fail
            var response = await controller.SubmitOrder(submitRequest);

            // Assert: Order MUST still succeed (200 OK)
            var okResult = Assert.IsType<OkObjectResult>(response.Result);
            var order = Assert.IsType<OrderDto>(okResult.Value);
            Assert.True(order.Id > 0);
            Assert.Equal(OrderStatus.Success, order.OrderStatus);

            // And DB has the committed order
            var persistedOrder = await db.Orders.FirstOrDefaultAsync(o => o.Id == order.Id);
            Assert.NotNull(persistedOrder);
            Assert.Equal(OrderStatus.Success, persistedOrder.OrderStatus);
            Assert.Matches("^[0-9]{4}$", persistedOrder.DeliveryOtp);
            Assert.Equal(order.DeliveryOtp, persistedOrder.DeliveryOtp);
            Assert.Null(persistedOrder.DeliveryOtpExpiresAt);

            // Notifications are durable work now; checkout never calls the
            // gateway directly and cannot lose the event on a transient error.
            var queued = await db.OrderOutboxMessages
                .Where(x => x.OrderId == order.Id && x.ProcessedAtUtc == null)
                .ToListAsync();
            Assert.Equal(2, queued.Count);
        }

        [Fact]
        public async Task Test04_SubmitOrder_OutsideHomsArea_IsRejectedRegardlessOfAddressText()
        {
            var db = CreateInMemoryOrdersContext();
            var (controller, _, _, testUser) = CreateTestController(db);

            // The address text says Homs, but the selected map pin is outside its delivery area.
            var outOfRadiusSubmit = new CartSubmit
            {
                IdempotencyKey = "key_out_of_radius_01",
                Phonenumber = testUser.PhoneNumber,
                Lat = 33.8500m,
                Lng = 36.5000m,
                Address = "حمص، محافظة حمص",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 101, MerchantId = 10, Quantity = 1 }
                }
            };

            var response = await controller.SubmitOrder(outOfRadiusSubmit);

            // Assert: Must return 400 Bad Request
            var badRequest = Assert.IsType<BadRequestObjectResult>(response.Result);
            var err = Assert.IsType<ApiErr>(badRequest.Value);
            Assert.Contains("خارج منطقة التغطية في حمص", err.Errors.First());

            // Invariant: No order was created in the database
            var orderCount = await db.Orders.CountAsync();
            Assert.Equal(0, orderCount);
        }

        [Fact]
        public async Task Test05_SubmitOrder_BelowMerchantMinimumOrder_IsRejectedForAppAndDirectApi()
        {
            var db = CreateInMemoryOrdersContext();
            var catDb = CreateInMemoryCatalogContext();

            var highMinMerchant = new Modules.Catalog.Entities.Merchant
            {
                Id = 20,
                Title = "Gourmet House",
                Active = true,
                MinOrderAmount = 50000m, // 50,000 SYP minimum
                ShippingCoverageInMeters = 20000,
                Lat = 33.5138m,
                Lng = 36.2765m,
                DeliveryFee = 4000m
            };
            catDb.Merchants.Add(highMinMerchant);
            catDb.SaveChanges();

            var (controller, _, _, testUser) = CreateTestController(
                db,
                catDb,
                configureMerchant: merchantMock =>
                {
                    merchantMock.Setup(m => m.FindAsync(20)).ReturnsAsync(highMinMerchant);
                    merchantMock.Setup(m => m.GetMerchantProductPrice(20, 201)).ReturnsAsync(new MerchantProductDto
                    {
                        MerchantId = 20,
                        MerchantPrice = 15000m, // 15,000 < 50,000
                        ProfitOutOfMerchantPricePercent = 10m
                    });
                },
                configureProduct: productMock =>
                {
                    productMock.Setup(p => p.GetProduct(201)).ReturnsAsync(new ProductLiteDto
                    {
                        Id = 201,
                        Title = "Artisan Cake",
                        Unit = "Piece"
                    });
                });

            var subMinSubmit = new CartSubmit
            {
                IdempotencyKey = "key_min_order_fail",
                Phonenumber = testUser.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Mazzeh",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 201, MerchantId = 20, Quantity = 1 } // Total 15,000 < 50,000
                }
            };

            var response = await controller.SubmitOrder(subMinSubmit);

            var badRequest = Assert.IsType<BadRequestObjectResult>(response.Result);
            var err = Assert.IsType<ApiErr>(badRequest.Value);
            Assert.Contains("أقل من الحد الأدنى للطلب", err.Errors.First());

            var orderCount = await db.Orders.CountAsync();
            Assert.Equal(0, orderCount);
        }

        [Fact]
        public async Task Test06_SubmitOrder_BatchStockExhaustion_RollsBackTransactionAndReleasesReservations()
        {
            var db = CreateInMemoryOrdersContext();
            bool releaseCalled = false;

            var (controller, _, _, testUser) = CreateTestController(
                db,
                configureBatch: batchMock =>
                {
                    batchMock.Setup(b => b.ReserveStockFEFOAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()))
                        .ThrowsAsync(new InvalidOperationException("الكمية المطلوبة من المنتج غير متوفرة حالياً في المخزون."));

                    batchMock.Setup(b => b.ReleaseReservationAsync(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<string>(), It.IsAny<int?>()))
                        .Callback<int, int?, string, int?>((orderId, detailId, reason, merchantId) => { releaseCalled = true; })
                        .Returns(Task.CompletedTask);
                });

            var submitRequest = new CartSubmit
            {
                IdempotencyKey = "key_batch_exhaust_01",
                Phonenumber = testUser.PhoneNumber,
                Lat = 34.7333m,
                Lng = 36.7167m,
                Address = "Malki",
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                CartItems = new[]
                {
                    new CartItem { ProductId = 101, MerchantId = 10, Quantity = 5 }
                }
            };

            var response = await controller.SubmitOrder(submitRequest);

            var badRequest = Assert.IsType<BadRequestObjectResult>(response.Result);
            var err = Assert.IsType<ApiErr>(badRequest.Value);
            Assert.Contains("غير متوفرة حالياً في المخزون", err.Errors.First());

            // Release of reservations must be called to compensate
            Assert.True(releaseCalled);

            // No active successful order persisted
            var activeOrders = await db.Orders.CountAsync(o => o.OrderStatus == OrderStatus.Success);
            Assert.Equal(0, activeOrders);
        }

        [Fact]
        public void Test07_IsOperatingDeliveryHours_AlignsWithConfiguredOperatingWindow()
        {
            // 11:00 UTC = 14:00 (2:00 PM) Damascus time (+3:00) -> Open (within 09:00 - 23:00)
            var daytimeUtc = new DateTime(2026, 9, 22, 11, 0, 0, DateTimeKind.Utc);
            Assert.True(OrderDto.IsOperatingDeliveryHours(daytimeUtc));

            // 01:00 UTC = 04:00 (4:00 AM) Damascus time (+3:00) -> Closed
            var nightUtc = new DateTime(2026, 9, 22, 1, 0, 0, DateTimeKind.Utc);
            Assert.False(OrderDto.IsOperatingDeliveryHours(nightUtc));

            // 05:00 UTC = 08:00 (8:00 AM) Damascus time (+3:00) -> Closed (opens at 09:00 AM)
            var earlyMorningUtc = new DateTime(2026, 9, 22, 5, 0, 0, DateTimeKind.Utc);
            Assert.False(OrderDto.IsOperatingDeliveryHours(earlyMorningUtc));

            // 19:00 UTC = 22:00 (10:00 PM) Damascus time (+3:00) -> Open
            var eveningUtc = new DateTime(2026, 9, 22, 19, 0, 0, DateTimeKind.Utc);
            Assert.True(OrderDto.IsOperatingDeliveryHours(eveningUtc));
        }

        [Fact]
        public void IsOperatingDeliveryHours_RespectsMerchantTwentyFourHourSchedule()
        {
            var earlyMorningUtc = new DateTime(2026, 9, 22, 1, 0, 0, DateTimeKind.Utc);

            Assert.True(OrderDto.IsOperatingDeliveryHours(earlyMorningUtc, "24 ساعة"));
            Assert.True(OrderDto.IsOperatingDeliveryHours(earlyMorningUtc, " 24 ساعة "));
            Assert.False(OrderDto.IsOperatingDeliveryHours(earlyMorningUtc, "حتى 3 ص"));
        }

        [Fact]
        public void IsOperatingDeliveryHours_UsesConfiguredClosingTime()
        {
            var afterMidnightUtc = new DateTime(2026, 9, 22, 0, 30, 0, DateTimeKind.Utc); // 03:30 Damascus
            var beforeClosingUtc = new DateTime(2026, 9, 21, 23, 30, 0, DateTimeKind.Utc); // 02:30 Damascus

            Assert.False(OrderDto.IsOperatingDeliveryHours(afterMidnightUtc, "حتى 3 ص"));
            Assert.True(OrderDto.IsOperatingDeliveryHours(beforeClosingUtc, "حتى 3 ص"));
        }
    }
}
