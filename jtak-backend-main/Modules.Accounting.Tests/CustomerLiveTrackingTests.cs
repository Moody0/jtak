using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Moq;
using System.Security.Claims;
using Xunit;
using CustomerOrdersController = App.ApiControllers.V1.Customer.Orders.OrdersController;

namespace Modules.Accounting.Tests;

public class CustomerLiveTrackingTests
{
    [Theory]
    [InlineData(OrderDetailStatus.ShippingStarted, 0, true)]
    [InlineData(OrderDetailStatus.ShippingStarted, 120, false)]
    [InlineData(OrderDetailStatus.Delivered, 0, false)]
    [InlineData(OrderDetailStatus.CustomerCanceled, 0, false)]
    [InlineData(OrderDetailStatus.DeliveryCanceled, 0, false)]
    [InlineData(OrderDetailStatus.MerchantRejected, 0, false)]
    public async Task LiveTrack_UsesFreshHomsGpsOnlyForActiveOrder(OrderDetailStatus status, int age, bool live)
    {
        var dto = await Track(status, age);
        Assert.Equal(live, dto.IsLive);
        Assert.Equal(34.731m, dto.DestinationLat);
        Assert.Equal(36.711m, dto.DestinationLng);
        if (live)
        {
            Assert.Equal(34.7301m, dto.DriverLat);
            Assert.Equal(36.7101m, dto.DriverLng);
            Assert.Equal(DateTimeKind.Utc, dto.LocationUpdatedAt!.Value.Kind);
            Assert.InRange(dto.EtaMinutes, 1, 180);
        }
        else
        {
            Assert.Equal(0, dto.EtaMinutes);
            Assert.Equal(0, dto.RemainingDistanceMeters);
            if (status != OrderDetailStatus.ShippingStarted) Assert.Null(dto.DriverLat);
        }
    }

    [Fact]
    public async Task MissingPickupCoordinates_DoNotInventAShortEta()
    {
        var dto = await Track(OrderDetailStatus.ShippingStarted, 0, invalidStop: true);
        Assert.True(dto.IsLive);
        Assert.Equal(0, dto.EtaMinutes);
        Assert.Equal(0, dto.RemainingDistanceMeters);
    }

    [Fact]
    public async Task OtherCustomer_CannotReadOrderGps()
    {
        Assert.Null(await Track(OrderDetailStatus.ShippingStarted, 0, wrongCustomer: true));
    }

    private static async Task<OrderLiveTrackDto?> Track(OrderDetailStatus status, int age,
        bool invalidStop = false, bool wrongCustomer = false)
    {
        using var orders = new OrdersDbContext(new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var users = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        var customer = Guid.NewGuid();
        var driver = Guid.NewGuid();
        users.Users.Add(new AppUser { Id = driver, FullName = "QA Driver" });
        await users.SaveChangesAsync();
        orders.Orders.Add(new Order { Id = 61, UserId = customer, DeliveryId = driver,
            OrderStatus = OrderStatus.Success, Lat = 34.731m, Lng = 36.711m,
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = status } } });
        await orders.SaveChangesAsync();
        var service = new Mock<IOrderService>();
        service.Setup(s => s.Queryable()).Returns(orders.Orders);
        var delivery = new Mock<IDeliveryService>();
        delivery.Setup(s => s.GetOrderStops(61)).ReturnsAsync(invalidStop
            ? new List<ShippingOrderDto> { new() { Index = 1, Lat = 0, Lng = 0 } }
            : new List<ShippingOrderDto>());
        delivery.Setup(s => s.GetDeliveryStatus(driver)).ReturnsAsync(new DeliveryStatus {
            Loc = (34.7301m, 36.7101m),
            LastLocationUpdatedAt = DateTime.SpecifyKind(DateTime.UtcNow.AddSeconds(-age), DateTimeKind.Unspecified)
        });
        var manager = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(),
            null, null, null, null, null, null, null, null);
        manager.Setup(s => s.Users).Returns(users.Users);
        var controller = new CustomerOrdersController(null, manager.Object, null, null,
            delivery.Object, null, service.Object, null, null);
        var uid = wrongCustomer ? Guid.NewGuid() : customer;
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
                new Claim(ClaimTypes.NameIdentifier, uid.ToString()), new Claim("sub", uid.ToString())
            }, "test"))
        }};
        var response = await controller.GetLiveTrack(61);
        if (wrongCustomer)
        {
            Assert.IsType<NotFoundResult>(response.Result);
            return null;
        }
        return Assert.IsType<OrderLiveTrackDto>(Assert.IsType<OkObjectResult>(response.Result).Value);
    }
}
