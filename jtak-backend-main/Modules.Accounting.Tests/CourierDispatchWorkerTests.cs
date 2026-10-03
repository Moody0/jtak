using App.BackgroundTasks;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Moq;
using System.Security.Claims;
using Xunit;
using Solf.Models;

namespace Modules.Accounting.Tests;

public class CourierDispatchWorkerTests
{
    // A relational database is intentional: the worker uses ExecuteUpdate, which
    // the EF InMemory provider cannot execute.
    private sealed class Fixture : IDisposable
    {
        private readonly SqliteConnection _connection = new("Data Source=:memory:");
        public readonly ServiceProvider Services;
        public readonly Mock<IDeliveryService> Delivery = new();
        public readonly Mock<IMerchantService> Merchant = new();
        public readonly Mock<INotificationService> Notification = new();
        public readonly Mock<IInventoryBatchService> Inventory = new();
        public readonly Guid DriverId = Guid.NewGuid();
        public readonly Guid SecondDriverId = Guid.NewGuid();
        public readonly DeliveryStatus DriverStatus = new()
        {
            IsOnline = true,
            LastLocationUpdatedAt = DateTime.UtcNow,
            Loc = (34.73m, 36.71m),
            PendingOrders = new List<ShippingOrderDto>()
        };

        public Fixture()
        {
            _connection.Open();
            var services = new ServiceCollection();
            services.AddDbContext<OrdersDbContext>(options => options.UseSqlite(_connection));
            services.AddSingleton<IHttpContextAccessor>(new HttpContextAccessor());
            services.AddSingleton(Delivery.Object);
            services.AddSingleton(Merchant.Object);
            services.AddSingleton(Notification.Object);
            services.AddSingleton(Inventory.Object);
            services.AddScoped<IOrderService>(provider =>
            {
                var context = provider.GetRequiredService<OrdersDbContext>();
                return new OrderService(new OrdersUnitOfWork(context), new Mock<IMapper>().Object, null,
                    new TrackableRepository<Order, OrdersDbContext>(context),
                    new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(context),
                    new TrackableRepository<OrderDetail, OrdersDbContext>(context));
            });
            Services = services.BuildServiceProvider();
            using var scope = Services.CreateScope();
            scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Database.EnsureCreated();
            Merchant.Setup(x => x.GetMerchantStops(It.IsAny<int[]>()))
                .ReturnsAsync(new[] { (34.73m, 36.71m, 10) });
            Delivery.Setup(x => x.GetOnlineDeliveryIds()).ReturnsAsync(new[] { DriverId });
            Delivery.Setup(x => x.GetDeliveryStatus(DriverId)).ReturnsAsync(DriverStatus);
            Delivery.Setup(x => x.GetDeliveryStatus(SecondDriverId)).ReturnsAsync(new DeliveryStatus
            {
                IsOnline = true,
                LastLocationUpdatedAt = DateTime.UtcNow,
                Loc = (34.74m, 36.72m),
                PendingOrders = new List<ShippingOrderDto>()
            });
        }

        public async Task<int> SeedOrderAsync(bool accepted = true, Guid? customerId = null, int merchantId = 10)
        {
            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var now = DateTime.UtcNow;
            var order = new Order
            {
                UserId = customerId ?? Guid.NewGuid(),
                OrderStatus = OrderStatus.Success,
                AccountingLastError = "",
                PurchaseDate = now,
                CourierMatchingStartedAtUtc = accepted ? now : null,
                CourierMatchingDeadlineAtUtc = accepted ? now.AddMinutes(CourierMatchingPolicy.TimeoutMinutes) : null,
                CourierMatchingRound = accepted ? 1 : 0,
                OrderDetails = new List<OrderDetail>
                {
                    new()
                    {
                        MerchantId = merchantId, ProductId = 100, Quantity = 1,
                        SinglePrice = 100, SingleFinalPrice = 100,
                        OrderDetailStatus = accepted ? OrderDetailStatus.MerchantAccepted : OrderDetailStatus.Pending
                    }
                }
            };
            db.Orders.Add(order);
            await db.SaveChangesAsync();
            return order.Id;
        }

        public Task DispatchAsync() => new CourierDispatchWorker(Services,
            NullLogger<CourierDispatchWorker>.Instance).ScheduledTask(CancellationToken.None);

        public async Task AssertVisibleToDriverAsync(int orderId, Guid? driverId = null, bool expectLiveOffer = true)
        {
            var visibleDriverId = driverId ?? DriverId;
            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var uow = new OrdersUnitOfWork(db);
            var service = new OrderService(uow, new Mock<IMapper>().Object, null,
                new TrackableRepository<Order, OrdersDbContext>(db),
                new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(db),
                new TrackableRepository<OrderDetail, OrdersDbContext>(db));
            Merchant.Setup(x => x.Queryable()).Returns(new List<Modules.Catalog.Entities.Merchant>().AsQueryable());
            var products = new Mock<IProductService>();
            products.Setup(x => x.Queryable()).Returns(new List<Product>().AsQueryable());
            var controller = new App.ApiControllers.V1.Delivery.OrdersController(
                null, null, uow, Notification.Object, null, Merchant.Object, products.Object,
                Delivery.Object, service, null, null, null, null, null, new Mock<IMapper>().Object);
            controller.ControllerContext = new()
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    { new Claim(ClaimTypes.NameIdentifier, visibleDriverId.ToString()) }, "Test"))
                }
            };
            var result = await controller.PostAvailable(new MetronicTable
            { PageNumber = 0, PageSize = 50, SortField = "id", SortOrder = "desc" });
            var offer = Assert.Single(result.Value.Items);
            Assert.Equal(orderId, offer.Id);
            Assert.Equal(expectLiveOffer, offer.OfferExpiresAtUtc.HasValue);
        }

        public async Task<OrderDispatchOffer[]> OffersAsync()
        {
            using var scope = Services.CreateScope();
            return await scope.ServiceProvider.GetRequiredService<OrdersDbContext>()
                .OrderDispatchOffers.AsNoTracking().ToArrayAsync();
        }

        public void Dispose() { Services.Dispose(); _connection.Dispose(); }
    }

    [Fact]
    public async Task DualCheckout_TimeoutCancelsOnlyItsOwnOrder_WhileSiblingGetsDriverOffer()
    {
        using var fixture = new Fixture();
        var customer = Guid.NewGuid();
        var restaurant = await fixture.SeedOrderAsync(customerId: customer);
        var market = await fixture.SeedOrderAsync(customerId: customer, merchantId: 11);
        using (var scope = fixture.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var order = await db.Orders.SingleAsync(o => o.Id == market);
            order.CourierMatchingStartedAtUtc = DateTime.UtcNow.AddMinutes(-4);
            order.CourierMatchingDeadlineAtUtc = DateTime.UtcNow.AddMinutes(-1);
            await db.SaveChangesAsync();
        }
        await fixture.DispatchAsync();
        var offer = Assert.Single(await fixture.OffersAsync());
        Assert.Equal(restaurant, offer.OrderId);
        using (var scope = fixture.Services.CreateScope())
        {
            var orders = await scope.ServiceProvider.GetRequiredService<OrdersDbContext>()
                .Orders.Include(o => o.OrderDetails).ToArrayAsync();
            Assert.Equal(OrderDetailStatus.MerchantAccepted, orders.Single(o => o.Id == restaurant).OrderDetails.Single().OrderDetailStatus);
            Assert.Equal(OrderDetailStatus.DeliveryCanceled, orders.Single(o => o.Id == market).OrderDetails.Single().OrderDetailStatus);
        }
        fixture.Inventory.Verify(x => x.ReleaseReservationAsync(market, null, It.IsAny<string>(), null), Times.Once);
        fixture.Inventory.Verify(x => x.ReleaseReservationAsync(restaurant, It.IsAny<int?>(), It.IsAny<string>(), It.IsAny<int?>()), Times.Never);
        fixture.Notification.Verify(x => x.SendPushNotification(
            It.Is<Notification>(n => n.EventKey == $"order:{market}:cancelled-no-courier" && n.AudienceApp == "customer" &&
                                    n.TextAr.Contains("3 دقائق")),
            It.Is<Guid[]>(ids => ids.Length == 1 && ids[0] == customer), true, false), Times.Once);
        await fixture.DispatchAsync();
        fixture.Notification.Verify(x => x.SendPushNotification(
            It.Is<Notification>(n => n.EventKey == $"order:{market}:cancelled-no-courier"), It.IsAny<Guid[]>(), true, false), Times.Once);
    }

    [Theory]
    [InlineData(4, false)]
    [InlineData(9, false)]
    [InlineData(11, true)]
    public async Task NoCourier_StaysAvailableUntilTenMinuteDeadline(int elapsedMinutes, bool shouldCancel)
    {
        using var fixture = new Fixture();
        var id = await fixture.SeedOrderAsync();
        fixture.Delivery.Setup(x => x.GetOnlineDeliveryIds()).ReturnsAsync(Array.Empty<Guid>());
        using (var scope = fixture.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var order = await db.Orders.SingleAsync(x => x.Id == id);
            var started = DateTime.UtcNow.AddMinutes(-elapsedMinutes);
            order.CourierMatchingStartedAtUtc = started;
            order.CourierMatchingDeadlineAtUtc = started.AddMinutes(10);
            await db.SaveChangesAsync();
        }

        await fixture.DispatchAsync();
        using (var scope = fixture.Services.CreateScope())
        {
            var order = await scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Orders
                .Include(x => x.OrderDetails).SingleAsync(x => x.Id == id);
            Assert.Equal(shouldCancel, order.CourierMatchingCompletedAtUtc.HasValue);
            Assert.Equal(shouldCancel ? OrderDetailStatus.DeliveryCanceled : OrderDetailStatus.MerchantAccepted,
                order.OrderDetails.Single().OrderDetailStatus);
        }
        fixture.Inventory.Verify(x => x.ReleaseReservationAsync(id, null, It.IsAny<string>(), null),
            shouldCancel ? Times.Once() : Times.Never());
        fixture.Notification.Verify(x => x.SendPushNotification(
            It.Is<Notification>(n => n.TextAr.Contains("10 دقائق")), It.IsAny<Guid[]>(), true, false),
            shouldCancel ? Times.Once() : Times.Never());
    }

    [Fact]
    public async Task DualCheckout_AcceptingOneMerchant_DoesNotStartSiblingMatchingClock()
    {
        using var fixture = new Fixture();
        var customer = Guid.NewGuid();
        var restaurant = await fixture.SeedOrderAsync(customerId: customer);
        var market = await fixture.SeedOrderAsync(accepted: false, customerId: customer, merchantId: 11);
        await fixture.DispatchAsync();
        Assert.Equal(restaurant, Assert.Single(await fixture.OffersAsync()).OrderId);
        using var scope = fixture.Services.CreateScope();
        var pending = await scope.ServiceProvider.GetRequiredService<OrdersDbContext>()
            .Orders.Include(o => o.OrderDetails).SingleAsync(o => o.Id == market);
        Assert.Null(pending.CourierMatchingStartedAtUtc);
        Assert.Null(pending.CourierMatchingDeadlineAtUtc);
        Assert.Equal(OrderDetailStatus.Pending, pending.OrderDetails.Single().OrderDetailStatus);
    }

    [Fact]
    public async Task MerchantAcceptance_PersistsMatchingWindow_ThenCreatesDriverOffer()
    {
        using var fixture = new Fixture();
        var id = await fixture.SeedOrderAsync(accepted: false);
        using (var scope = fixture.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var uow = new OrdersUnitOfWork(db);
            var orders = new TrackableRepository<Order, OrdersDbContext>(db);
            var details = new TrackableRepository<OrderDetail, OrdersDbContext>(db);
            var logs = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(db);
            var manager = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            manager.Setup(x => x.GetUsersInRoleAsync(It.IsAny<string>())).ReturnsAsync(new List<AppUser>());
            var service = new OrderService(uow, new Mock<IMapper>().Object, manager.Object, orders, logs, details);
            var owner = Guid.NewGuid();
            fixture.Merchant.Setup(x => x.GetMerchantIds(owner)).ReturnsAsync(new[] { 10 });
            var controller = new App.ApiControllers.V1.Warehouse.OrdersController(uow, manager.Object,
                fixture.Notification.Object, fixture.Merchant.Object, service, new Mock<IProductService>().Object,
                new Mock<IOrderDetailService>().Object, fixture.Delivery.Object,
                new Mock<IInventoryBatchService>().Object, new Mock<IMapper>().Object,
                new OrderTransitionService(uow, orders, details, logs));
            controller.ControllerContext = new()
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    { new Claim(ClaimTypes.NameIdentifier, owner.ToString()) }, "Test"))
                }
            };
            var result = await controller.MerchantAccept(id);
            Assert.True(result.Value);
        }
        using (var scope = fixture.Services.CreateScope())
        {
            var order = await scope.ServiceProvider.GetRequiredService<OrdersDbContext>().Orders.SingleAsync();
            Assert.NotNull(order.CourierMatchingStartedAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(10), order.CourierMatchingDeadlineAtUtc - order.CourierMatchingStartedAtUtc);
        }
        await fixture.DispatchAsync();
        Assert.Equal(fixture.DriverId, Assert.Single(await fixture.OffersAsync()).DriverId);
        await fixture.AssertVisibleToDriverAsync(id);
    }

    [Fact]
    public async Task PushFailure_DoesNotInvalidateSavedOffer_OrCreateDuplicateOnNextTick()
    {
        using var fixture = new Fixture();
        var id = await fixture.SeedOrderAsync();
        fixture.Notification.Setup(x => x.SendPushNotification(It.IsAny<Notification>(),
            It.IsAny<Guid[]>(), true, false)).ThrowsAsync(new InvalidOperationException("Push unavailable"));
        await fixture.DispatchAsync();
        await fixture.DispatchAsync();
        var offer = Assert.Single(await fixture.OffersAsync());
        Assert.Equal(id, offer.OrderId);
        Assert.Equal(OrderDispatchOfferStatus.Offered, offer.Status);
        Assert.Null(offer.RespondedAtUtc);
        Assert.True(offer.ExpiresAtUtc > DateTime.UtcNow);
        await fixture.AssertVisibleToDriverAsync(id);
    }

    [Fact]
    public async Task TimedOutDriverOffer_RemainsVisibleWhileNextWaveIsDispatched()
    {
        using var fixture = new Fixture();
        var orderId = await fixture.SeedOrderAsync();
        fixture.Delivery.Setup(x => x.GetOnlineDeliveryIds())
            .ReturnsAsync(new[] { fixture.DriverId, fixture.SecondDriverId });

        using (var scope = fixture.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var now = DateTime.UtcNow;
            db.OrderDispatchOffers.Add(new OrderDispatchOffer
            {
                OrderId = orderId,
                DriverId = fixture.DriverId,
                MatchingRound = 1,
                WaveNumber = 1,
                OfferedAtUtc = now.AddSeconds(-26),
                ExpiresAtUtc = now.AddSeconds(-1),
                Status = OrderDispatchOfferStatus.Offered
            });
            await db.SaveChangesAsync();
        }

        await fixture.DispatchAsync();

        var offers = await fixture.OffersAsync();
        Assert.Equal(2, offers.Length);
        Assert.Contains(offers, x => x.DriverId == fixture.DriverId &&
                                     x.Status == OrderDispatchOfferStatus.TimedOut);
        Assert.Contains(offers, x => x.DriverId == fixture.SecondDriverId &&
                                     x.Status == OrderDispatchOfferStatus.Offered &&
                                     x.ExpiresAtUtc > DateTime.UtcNow);
        await fixture.AssertVisibleToDriverAsync(orderId, fixture.DriverId, expectLiveOffer: false);
    }

    [Theory]
    [InlineData(2, true)]
    [InlineData(3, false)]
    public async Task Capacity_CountsDistinctOrders_NotPickupAndDropoffStops(int activeOrders, bool expectedOffer)
    {
        using var fixture = new Fixture();
        await fixture.SeedOrderAsync();
        for (var orderId = 1; orderId <= activeOrders; orderId++)
        {
            fixture.DriverStatus.PendingOrders.Add(new ShippingOrderDto { OrderId = orderId });
            fixture.DriverStatus.PendingOrders.Add(new ShippingOrderDto { OrderId = orderId });
        }
        await fixture.DispatchAsync();
        Assert.Equal(expectedOffer ? 1 : 0, (await fixture.OffersAsync()).Length);
    }

    [Theory]
    [InlineData(false, 0)]
    [InlineData(true, 6)]
    public async Task OfflineOrStaleGps_DoesNotReceiveOffer(bool online, int gpsAgeMinutes)
    {
        using var fixture = new Fixture();
        await fixture.SeedOrderAsync();
        fixture.DriverStatus.IsOnline = online;
        fixture.DriverStatus.LastLocationUpdatedAt = DateTime.UtcNow.AddMinutes(-gpsAgeMinutes);
        await fixture.DispatchAsync();
        Assert.Empty(await fixture.OffersAsync());
    }
}
