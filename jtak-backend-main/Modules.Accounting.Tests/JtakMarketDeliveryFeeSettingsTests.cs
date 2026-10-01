using App.ApiControllers.V1.Admin;
using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Merchant = Modules.Catalog.Entities.Merchant;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class JtakMarketDeliveryFeeSettingsTests
{
    [Fact]
    public async Task AdminCourierPolicyDefaultsToMonthlyAndPersistsOnlyItsOwnSetting()
    {
        var settings = new Mock<IGenericSettingService>();
        var controller = new SettingsController(null, null, new Mock<IMerchantService>().Object, settings.Object,
            null, null, NullLogger<SettingsController>.Instance);
        var initial = Assert.IsType<OkObjectResult>(await controller.GetJtakMarketCourierPay());
        Assert.Equal(CaptainCompensationType.SalariedEmployee, Assert.IsType<JtakMarketCourierPaySetting>(initial.Value).Mode);
        var model = new JtakMarketCourierPaySetting {Mode = CaptainCompensationType.FixedPerOrder, Rate = 75};
        Assert.IsType<OkObjectResult>(await controller.SetJtakMarketCourierPay(model));
        settings.Verify(x => x.SetValue(JtakMarketCourierPaySetting.Key, model, null), Times.Once);
        Assert.IsType<BadRequestObjectResult>(await controller.SetJtakMarketCourierPay(
            new() {Mode = CaptainCompensationType.PerKilometer, Rate = 45}));
    }
    [Theory]
    [InlineData(0)]
    [InlineData(125.5)]
    public async Task SavePersistsCanonicalMarketFeeOnlyWithoutRequiringAPhysicalLocation(decimal amount)
    {
        using var db = CreateDb();
        var market = new Merchant { Id = 31, Title = "JTAK Market", Active = true, MerchantKind = MerchantKind.Grocery,
            Lat = 0, Lng = 0, DeliveryFee = 100m };
        var restaurant = new Merchant { Id = 32, Title = "Cafe", Active = true, DeliveryFee = 700m };
        db.Merchants.AddRange(market, restaurant); await db.SaveChangesAsync();
        var merchantService = new Mock<IMerchantService>();
        merchantService.Setup(x => x.GetJtakMarketMerchantId()).ReturnsAsync(31);
        merchantService.Setup(x => x.FindAsync(31)).ReturnsAsync(market);
        var controller = Controller(merchantService.Object, new CatalogUnitOfWork(db));
        Assert.IsType<OkObjectResult>(await controller.SetJtakMarketDeliveryFee(new() {Amount = amount}));
        db.ChangeTracker.Clear();
        Assert.Equal(amount, (await db.Merchants.FindAsync(31))!.DeliveryFee);
        Assert.Equal(700m, (await db.Merchants.FindAsync(32))!.DeliveryFee);
        Assert.Equal(0m, (await db.Merchants.FindAsync(31))!.Lat);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(-1)]
    [InlineData(0.123)]
    [InlineData(100000001)]
    public async Task InvalidFeesNeverWriteToTheCatalogue(double? value)
    {
        var uow = new Mock<ICatalogUnitOfWork>();
        var merchants = new Mock<IMerchantService>();
        var controller = Controller(merchants.Object, uow.Object);
        Assert.IsType<BadRequestObjectResult>(await controller.SetJtakMarketDeliveryFee(
            new() {Amount = value.HasValue ? (decimal)value.Value : null}));
        merchants.Verify(x => x.GetJtakMarketMerchantId(), Times.Never);
        uow.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task AmbiguousMarketFailsWithoutSavingOrInventingADefault()
    {
        var uow = new Mock<ICatalogUnitOfWork>();
        var merchants = new Mock<IMerchantService>();
        var controller = Controller(merchants.Object, uow.Object);
        Assert.IsType<BadRequestObjectResult>(await controller.GetJtakMarketDeliveryFee());
        Assert.IsType<BadRequestObjectResult>(await controller.SetJtakMarketDeliveryFee(new() {Amount = 100m}));
        uow.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    private static CatalogDbContext CreateDb() => new(new DbContextOptionsBuilder<CatalogDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
    private static SettingsController Controller(IMerchantService merchants, ICatalogUnitOfWork uow) =>
        new(null, null, merchants, null, null, null, NullLogger<SettingsController>.Instance, catalogUnitOfWork: uow);
}
