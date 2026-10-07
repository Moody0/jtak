using App.ApiControllers.V1.Admin;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Services.eCommerce;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Services;
using Modules.Orders.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class DashboardEarnedMoneyTests
{
    [Fact]
    public async Task SummaryIncludesDeliveredInvoiceAmountsAndExcludesProvisionalInvoices()
    {
        using var catalog = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var orders = new OrdersDbContext(new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var accounting = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var app = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        accounting.Bills.AddRange(
            new Bill { MerchantId = 27, OrderId = 1, IsAddedToDues = true,
                TotalAmount = 2420m, MerchantAmount = 2200m, JTakAmount = 220m },
            new Bill { MerchantId = 27, OrderId = 2, IsAddedToDues = false,
                TotalAmount = 605m, MerchantAmount = 550m, JTakAmount = 55m });
        await accounting.SaveChangesAsync();
        var products = new Mock<IProductService>();
        products.Setup(x => x.Queryable()).Returns(catalog.Products);
        var orderService = new Mock<IOrderService>();
        orderService.Setup(x => x.Queryable()).Returns(orders.Orders);
        var detailService = new Mock<IOrderDetailService>();
        detailService.Setup(x => x.Queryable()).Returns(orders.OrderDetails);
        var users = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(),
            null, null, null, null, null, null, null, null);
        users.Setup(x => x.Users).Returns(app.Users);
        var bills = new BillService(new TrackableRepository<Bill, AccountingDbContext>(accounting));
        var controller = new DashboardController(products.Object, orderService.Object,
            detailService.Object, bills, users.Object);

        var result = (await controller.Get()).Value;
        Assert.NotNull(result);
        Assert.Equal(2420L, result.TotalOrdersValue);
        Assert.Equal(2200L, result.MerchantOrdersValue);
        Assert.Equal(220L, result.JTakOrdersValue);
        Assert.Equal(0L, result.JTakAdditionalOrdersValue);
        // The invoice count still includes provisional invoices, as in finance.
        Assert.Equal(2, result.BillsCount);
    }
}
