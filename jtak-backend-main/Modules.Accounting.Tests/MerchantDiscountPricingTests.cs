using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Moq;
using System.Text.Json;
using Xunit;

namespace Modules.Accounting.Tests;

public class MerchantDiscountPricingTests
{
    [Theory]
    [InlineData(550, 10, 10, 550, 605, 550)]
    [InlineData(550, 10, 50, 550, 605, 550)]
    [InlineData(550, 10, 5, 550, 605, 578)]
    [InlineData(550, 10, 9, 550, 605, 556)]
    [InlineData(500, 0, 10, 500, 500, 500)]
    [InlineData(550.49, 10, 0, 550, 606, 606)]
    [InlineData(550.5, 10, 0, 551, 606, 606)]
    [InlineData(550.49, 10, 5, 550, 606, 578)]
    public void QuoteDiscountUsesSupplierBaseAndNeverUndercutsSupplier(decimal exactBase,
        decimal markup, decimal percent, decimal vendor, decimal before, decimal after)
    {
        var quote = MerchantProductPricing.Calculate(exactBase, markup, percent);
        Assert.Equal(vendor, quote.MerchantPrice);
        Assert.Equal(before, quote.Price);
        Assert.Equal(after, quote.FinalPrice);
        Assert.Equal(before - after, quote.Discount);
    }

    [Fact]
    public void LegacyUsdDiscountRecoversOriginalBaseWithoutChangingStoredRow()
    {
        var row = new MerchantProduct { MerchantPrice = 495m, PriceUsd = 4.5m,
            OriginalPrice = 5m, Discount = 60m, ProfitOutOfMerchantPricePercent = 10m };
        var dto = MerchantProductDto.FromStored(row, 110m);
        Assert.Equal(550m, dto.MerchantPrice);
        Assert.Equal(605m, dto.Price);
        Assert.Equal(550m, dto.FinalPrice);
        Assert.Equal(10m, dto.DiscountPercent);
        Assert.Equal(4.5m, row.PriceUsd);
        Assert.Null(row.DiscountPercent);
        dto.NormalizePricing(110m);
        Assert.Equal(550m, dto.FinalPrice);
    }

    [Fact]
    public void LegacyCompareAtPromotionWithoutMarkupRetainsItsSellingPrice()
    {
        var dto = MerchantProductDto.FromStored(new MerchantProduct {
            MerchantPrice = 495m, PriceUsd = 4.5m, OriginalPrice = 5m, Discount = 55m
        }, 110m);
        Assert.Equal(495m, dto.FinalPrice);
        Assert.Equal(550m, dto.Price);
        Assert.Null(dto.DiscountPercent);
    }

    [Fact]
    public async Task PersistedDiscountAgreesAcrossCatalogReadsReassignmentAndRateChanges()
    {
        using var db = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        db.Merchants.Add(new Merchant { Id = 27, Title = "Restaurant", Active = true,
            MerchantKind = MerchantKind.Restaurant, ProfitOutOfMerchantPricePercent = 10m });
        db.Products.Add(new Product { Id = 5707, Title = "Burger", Active = true });
        await db.SaveChangesAsync();
        var rate = 110m;
        var settings = new Mock<IGenericSettingService>();
        settings.Setup(x => x.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key, null))
            .ReturnsAsync(() => new UsdExchangeRateSetting { Rate = rate });
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var service = new MerchantService(new TrackableRepository<Merchant, CatalogDbContext>(db),
            new TrackableRepository<MerchantProduct, CatalogDbContext>(db),
            new CatalogUnitOfWork(db), settings.Object, cache);
        var assigned = new MerchantProductAssignDto { ProductId = 5707,
            MerchantPrice = 550m, PriceUsd = 5m, OriginalPrice = 5m,
            DiscountPercent = 10m, Discount = 55m };
        await service.AssignMerchantProducts(new[] { 27 }, new[] { assigned });
        db.ChangeTracker.Clear();
        var row = await db.MerchantProducts.SingleAsync();
        Assert.Equal(550m, row.MerchantPrice);
        Assert.Equal(5m, row.PriceUsd);
        Assert.Equal(10m, row.DiscountPercent);
        await AssertAllReads(service, 550m, 605m, 550m);

        // Saving the catalog again must not apply the discount a second time.
        await service.AssignMerchantProducts(new[] { 27 }, new[] { assigned });
        await AssertAllReads(service, 550m, 605m, 550m);
        rate = 220m;
        await service.RepriceUsdDenominatedProducts(rate);
        await AssertAllReads(service, 1100m, 1210m, 1100m);
        await service.SetMerchantPercent(27, 20m);
        await AssertAllReads(service, 1100m, 1320m, 1210m);
        assigned.MerchantPrice = 1100m; assigned.DiscountPercent = 0m; assigned.Discount = 0m;
        assigned.OriginalPrice = null;
        await service.AssignMerchantProducts(new[] { 27 }, new[] { assigned });
        await AssertAllReads(service, 1100m, 1320m, 1320m);
    }

    private static async Task AssertAllReads(MerchantService service, decimal vendor, decimal before, decimal after)
    {
        var reads = new[] { await service.GetMerchantProductPrice(27, 5707),
            (await service.GetActiveMerchantPrices(27))[5707],
            (await service.GetAllMerchantPrices(27))[5707],
            (await service.GetProductPrices(5707))[27] };
        foreach (var dto in reads)
        {
            Assert.Equal(vendor, dto.MerchantPrice);
            Assert.Equal(before, dto.Price);
            Assert.Equal(after, dto.FinalPrice);
            Assert.Equal(before - after, dto.Discount);
            using var json = JsonDocument.Parse(JsonSerializer.Serialize(dto));
            Assert.Equal(after, json.RootElement.GetProperty("FinalPrice").GetDecimal());
            Assert.Equal(before, json.RootElement.GetProperty("Price").GetDecimal());
        }
    }
}
