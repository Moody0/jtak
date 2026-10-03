using System.Security.Claims;
using App.ApiControllers.V1.Admin;
using App.ApiModels;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using App.Catalog.Data;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using Modules.Shipping.Entities;
using Modules.Accounting.Data;
using Modules.Accounting.Services;
using Moq;
using Solf.Models;
using Xunit;

namespace Modules.Accounting.Tests;

public class AdminOrdersSectionAuditTests
{
    private sealed class Fixture : IDisposable
    {
        public readonly OrdersDbContext Db = new(new DbContextOptionsBuilder<OrdersDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        public readonly CatalogDbContext Catalog = new(new DbContextOptionsBuilder<CatalogDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        public readonly Mock<IDeliveryService> Delivery = new();
        public readonly Mock<INotificationService> Notifications = new();
        public readonly AppDbContext App = new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        public readonly AccountingDbContext Accounting = new(new DbContextOptionsBuilder<AccountingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        public readonly OrdersController Controller;
        public Fixture() {
            var uow = new OrdersUnitOfWork(Db);
            var service = new OrderService(uow, Mock.Of<IMapper>(), null,
                new TrackableRepository<Order, OrdersDbContext>(Db),
                new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(Db),
                new TrackableRepository<OrderDetail, OrdersDbContext>(Db));
            var merchants = new Mock<IMerchantService>(); merchants.Setup(x => x.Queryable()).Returns(Catalog.Merchants);
            merchants.Setup(x => x.GetMerchantStops(It.IsAny<int[]>())).ReturnsAsync(Array.Empty<(decimal Lat, decimal Lng, int MerchantId)>());
            Delivery.Setup(x => x.GetOnlineDeliveryIds()).ReturnsAsync(Array.Empty<Guid>());
            Delivery.Setup(x => x.GetDeliveryStatus(It.IsAny<Guid>())).ReturnsAsync(new DeliveryStatus { IsOnline = true });
            var users = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(), null, null, null, null, null, null, null, null);
            users.Setup(x => x.Users).Returns(App.Users);
            users.Setup(x => x.IsInRoleAsync(It.IsAny<AppUser>(), It.IsAny<string>())).ReturnsAsync(true);
            Controller = new OrdersController(Notifications.Object, users.Object, merchants.Object, Delivery.Object,
                service, null, uow, new AccountingUnitOfWork(Accounting), null, null, Mock.Of<ILedgerService>(), null, NullLogger<OrdersController>.Instance, Mock.Of<IMapper>());
            Controller.ControllerContext = new() { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()) }, "test")) } };
        }
        public async Task<Order> Seed(OrderDetailStatus status, Guid? driver = null, string name = null) {
            var order = new Order { OrderStatus = OrderStatus.Success, UserId = Guid.NewGuid(), DeliveryId = driver, DeliveryUser = name,
                PurchaseDate = DateTime.UtcNow, OrderDetails = new List<OrderDetail> { new() { MerchantId = 10, ProductId = 1, Quantity = 1,
                    SinglePrice = 100, SingleFinalPrice = 100, OrderDetailStatus = status } } };
            Db.Orders.Add(order); await Db.SaveChangesAsync(); return order;
        }
        public void Dispose() { Db.Dispose(); Catalog.Dispose(); App.Dispose(); Accounting.Dispose(); }
    }

    [Theory]
    [InlineData(null)] [InlineData("???")]
    public async Task AssignmentCountsUseIdEvenIfDriverNameIsMissing(string driverName) {
        using var f = new Fixture(); await f.Seed(OrderDetailStatus.MerchantAccepted, Guid.NewGuid(), driverName);
        await f.Seed(OrderDetailStatus.MerchantAccepted, Guid.Empty);
        Assert.Equal(1, (await f.Controller.Summary()).Value.WithoutDriver);
        var page = (await f.Controller.DataTable(new MetronicTable { PageNumber = 1, PageSize = 10 }, "UNASSIGNED")).Value;
        Assert.Equal(1, page.TotalRecords); Assert.Equal(Guid.Empty, Assert.Single(page.Items).DeliveryId);
    }
    [Fact]
    public async Task PaginationDoesNotRepeatTheFirstPage() {
        using var f = new Fixture(); for (var i = 0; i < 3; i++) await f.Seed(OrderDetailStatus.Pending);
        var first = (await f.Controller.DataTable(new MetronicTable { PageNumber = 1, PageSize = 1, SortField = "id", SortOrder = "asc" })).Value;
        var second = (await f.Controller.DataTable(new MetronicTable { PageNumber = 2, PageSize = 1, SortField = "id", SortOrder = "asc" })).Value;
        Assert.NotEqual(Assert.Single(first.Items).Id, Assert.Single(second.Items).Id);
    }
    [Fact]
    public async Task AdminAcceptanceStartsDriverMatchingOnceAndPreservesTheDeadlineOnReplay() {
        using var f = new Fixture(); var order = await f.Seed(OrderDetailStatus.Pending);
        Assert.True((await f.Controller.Accept(order.Id)).Value);
        Assert.Equal(OrderDetailStatus.MerchantAccepted, order.OrderDetails.Single().OrderDetailStatus);
        Assert.NotNull(order.CourierMatchingStartedAtUtc); Assert.Null(order.CourierMatchingCompletedAtUtc);
        Assert.Equal(TimeSpan.FromMinutes(10), order.CourierMatchingDeadlineAtUtc - order.CourierMatchingStartedAtUtc);
        var started = order.CourierMatchingStartedAtUtc;
        Assert.True((await f.Controller.Accept(order.Id)).Value);
        Assert.Equal(started, order.CourierMatchingStartedAtUtc); Assert.Equal(1, order.CourierMatchingRound);
    }
    [Fact]
    public async Task PreparingUsesTheAcceptanceAndMatchingFlow() {
        using var f = new Fixture(); var order = await f.Seed(OrderDetailStatus.Pending);
        Assert.True((await f.Controller.Preparing(order.Id)).Value); Assert.NotNull(order.CourierMatchingDeadlineAtUtc);
    }
    [Fact]
    public async Task ActiveOrdersMustBeCanceledBeforeArchiveAndCompletedHistoryCanBeRestored() {
        using var f = new Fixture(); var active = await f.Seed(OrderDetailStatus.Pending);
        Assert.IsType<BadRequestObjectResult>((await f.Controller.Archive(active.Id, new ArchiveOrderRequest { Reason = "test" })).Result);
        Assert.Null(active.DeletionDate);
        var done = await f.Seed(OrderDetailStatus.Delivered);
        Assert.True((await f.Controller.Archive(done.Id, new ArchiveOrderRequest { Reason = "test" })).Value);
        Assert.NotNull(done.DeletionDate);
        Assert.True((await f.Controller.Restore(done.Id)).Value); Assert.Null(done.DeletionDate);
    }
    [Theory]
    [InlineData(OrderDetailStatus.ShippingStarted)] [InlineData(OrderDetailStatus.Delivered)]
    public async Task UnassignmentCannotEraseCashOrResponsibilityAfterPickup(OrderDetailStatus status) {
        using var f = new Fixture(); var id = Guid.NewGuid(); var order = await f.Seed(status, id, "driver");
        order.CaptainEarning = 40;
        Assert.IsType<BadRequestObjectResult>((await f.Controller.UnassignDelivery(order.Id)).Result);
        Assert.Equal(id, order.DeliveryId); Assert.Equal(40, order.CaptainEarning);
        f.Delivery.Verify(x => x.RemoveOrder(It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<int?>()), Times.Never);
    }
    [Fact]
    public async Task UnassignmentBeforePickupReopensMatchingWithANewRound() {
        using var f = new Fixture(); var order = await f.Seed(OrderDetailStatus.MerchantAccepted, Guid.NewGuid(), "driver");
        order.CourierMatchingCompletedAtUtc = DateTime.UtcNow; order.CourierMatchingRound = 1;
        Assert.True((await f.Controller.UnassignDelivery(order.Id)).Value);
        Assert.Null(order.DeliveryId); Assert.Null(order.CourierMatchingCompletedAtUtc);
        Assert.Equal(2, order.CourierMatchingRound); Assert.True(order.CourierMatchingDeadlineAtUtc > DateTime.UtcNow);
    }
    [Fact]
    public async Task ManualAssignmentMarksDriverAcceptedWhileMerchantIsPreparing() {
        using var f = new Fixture(); var driver = new AppUser { Id = Guid.NewGuid(), FullName = "Driver", IsActive = true };
        f.App.Users.Add(driver); await f.App.SaveChangesAsync(); var order = await f.Seed(OrderDetailStatus.MerchantAccepted);
        Assert.True((await f.Controller.SetDelivery(order.Id, driver.Id)).Value);
        Assert.Equal(driver.Id, order.DeliveryId); Assert.NotNull(order.CourierMatchingCompletedAtUtc);
    }
    [Fact]
    public async Task FailedReassignmentPreservesThePreviousDriverRouteAndLocation() {
        using var f = new Fixture(); var driver = new AppUser { Id = Guid.NewGuid(), FullName = "New", IsActive = true };
        f.App.Users.Add(driver); await f.App.SaveChangesAsync(); var oldDriver = Guid.NewGuid();
        var order = await f.Seed(OrderDetailStatus.MerchantAccepted, oldDriver, "Old");
        order.DeliveryLat = 34.7m; order.DeliveryLng = 36.7m; order.CourierMatchingCompletedAtUtc = DateTime.UtcNow;
        f.Delivery.Setup(x => x.AddOrder(driver.Id, order.Id, It.IsAny<ShippingOrderDto[]>(), It.IsAny<ShippingOrderDto>())).ThrowsAsync(new Exception("route failed"));
        var result = Assert.IsType<ObjectResult>((await f.Controller.SetDelivery(order.Id, driver.Id)).Result);
        Assert.Equal(503, result.StatusCode); Assert.Equal(oldDriver, order.DeliveryId); Assert.Equal(34.7m, order.DeliveryLat);
        Assert.NotNull(order.CourierMatchingCompletedAtUtc);
        f.Delivery.Verify(x => x.RemoveOrder(oldDriver, order.Id, It.IsAny<int?>()), Times.Never);
    }
    [Fact]
    public async Task UnassignmentNotificationFailureDoesNotReportACommittedActionAsFailed() {
        using var f = new Fixture(); var order = await f.Seed(OrderDetailStatus.MerchantAccepted, Guid.NewGuid());
        f.Delivery.Setup(x => x.GetOnlineDeliveryIds()).ThrowsAsync(new Exception("push offline"));
        Assert.True((await f.Controller.UnassignDelivery(order.Id)).Value); Assert.Null(order.DeliveryId);
    }
    [Fact]
    public async Task SupportReadUpdatesTheBadgeAndRejectsInvalidStatuses() {
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        var support = new Mock<ISupportMessageService>(); support.Setup(x => x.Queryable()).Returns(db.SupportMessages);
        var controller = new SupportMessagesController(support.Object, new AppUnitOfWork(db), NullLogger<SupportMessagesController>.Instance, Mock.Of<IMapper>());
        var ticket = new SupportMessage { Title = "Help", Status = SupportMessageStatus.New }; db.SupportMessages.Add(ticket); await db.SaveChangesAsync();
        Assert.Equal(SupportMessageStatus.Read, (await controller.Get(ticket.Id)).Value.Status);
        Assert.IsType<BadRequestObjectResult>((await controller.UpdateStatus(ticket.Id, new UpdateSupportMessageStatusDto { Status = (SupportMessageStatus)999 })).Result);
    }
}
