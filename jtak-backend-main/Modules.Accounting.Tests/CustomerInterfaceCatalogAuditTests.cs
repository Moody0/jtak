using App.ApiControllers.V1.Admin;
using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;

using Moq;

namespace Modules.Accounting.Tests;

public class CustomerInterfaceCatalogAuditTests : IDisposable
{
    readonly CatalogDbContext db;
    readonly MemoryCache cache = new(new MemoryCacheOptions());
    readonly CatalogUnitOfWork uow;
    readonly ProductService products;
    readonly ProductCategoryService categories;
    readonly MerchantService merchants;
    readonly Mock<IGenericSettingService> settings = new();
    readonly HomeCategoriesService home;
    public CustomerInterfaceCatalogAuditTests()
    {
        db = new(new DbContextOptionsBuilder<CatalogDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        uow = new(db);
        products = new(uow, new TrackableRepository<Tag, CatalogDbContext>(db), new TrackableRepository<ProductTag, CatalogDbContext>(db),
            new TrackableRepository<Product, CatalogDbContext>(db), cache, new TrackableRepository<ProductCategory, CatalogDbContext>(db));
        categories = new(new TrackableRepository<ProductCategory, CatalogDbContext>(db), cache);
        merchants = new(new TrackableRepository<Merchant, CatalogDbContext>(db), new TrackableRepository<MerchantProduct, CatalogDbContext>(db), uow, settings.Object, cache,
            categories: new TrackableRepository<ProductCategory, CatalogDbContext>(db));
        home = new(categories, products, merchants, new TrackableRepository<MerchantProduct, CatalogDbContext>(db), settings.Object);
        db.ProductCategories.AddRange(new ProductCategory { Id=1, Title="Parent", Active=true },
            new ProductCategory { Id=2, Title="Child", ParentId=1, Active=true }, new ProductCategory { Id=3, Title="Empty", Active=true });
        db.Merchants.Add(new Merchant { Id=30, Title="Grocery", Active=true, OwnerId=Guid.NewGuid(), MerchantKind=App.Shared.Entities.Enums.MerchantKind.Grocery });
        db.Products.Add(new Product { Id=100, Title="Item", Active=true, Unit="قطعة", ProductCategoryId=2 });
        db.MerchantProducts.Add(new MerchantProduct { ProductId=100, MerchantId=30, MerchantPrice=500 }); db.SaveChanges();
    }
    [Fact]
    public async Task HomeCountsAndDestinationHideDescendantsOfDisabledCategory()
    {
        var config=new HomeCategoriesConfig { ErrandRequestsTileInitialized=true, Tiles=new() {new() {Id="child",Title="Child",Active=true,LinkType=HomeCategoryLinkType.ProductCategory,ProductCategoryId=2}} };
        settings.Setup(s=>s.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey,null)).ReturnsAsync(config);
        Assert.Single(await home.GetTiles(true)); db.ProductCategories.Find(1)!.Active=false;await db.SaveChangesAsync();
        var unavailable = Assert.Single(await home.GetTiles(true)); Assert.False(unavailable.TargetExists); Assert.False(unavailable.HasAvailableContent);
        Assert.Empty((await home.GetTiles(true)).Where(tile => tile.TargetExists && tile.HasAvailableContent));
        var admin=new HomeCategoriesController(home,categories,merchants,new TrackableRepository<MerchantProduct,CatalogDbContext>(db));
        var vm=(await admin.Get()).Value!;Assert.DoesNotContain(vm.AvailableCategories,c=>c.Id==2);Assert.Equal(0,vm.AvailableMerchants.Single().ProductCount);
    }
    [Fact]
    public async Task HomeMergedCategoryUsesAvailableSecondaryContent()
    {
        var config=new HomeCategoriesConfig { ErrandRequestsTileInitialized=true, Tiles=new() {new() {Id="merged",Title="Combined",Active=true,LinkType=HomeCategoryLinkType.ProductCategory,ProductCategoryId=3,SecondaryProductCategoryId=2}} };
        settings.Setup(s=>s.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey,null)).ReturnsAsync(config);
        var tile=Assert.Single(await home.GetTiles(true));Assert.Equal(1,tile.AvailableProductCount);Assert.Equal(1,tile.AvailableMerchantCount);
    }
    [Fact]
    public async Task FailedPopularRemovalDoesNotReportSuccessOrMutateCachedSettings()
    {
        var config=new PopularSectionConfig { Items=new() {new() { ProductId=100,Active=true,Order=1 }} };
        settings.Setup(s=>s.GetValue<PopularSectionConfig>("PopularProductsConfig",null)).ReturnsAsync(config);
        settings.Setup(s=>s.SetValue("PopularProductsConfig",It.IsAny<PopularSectionConfig>(),null)).ThrowsAsync(new InvalidOperationException("DB unavailable"));
        var controller=new PopularProductsController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<PopularProductsController>.Instance);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>controller.RemoveItem(100));Assert.Single(config.Items);
    }
    [Fact]
    public async Task FailedBestSellingRemovalDoesNotReportSuccessOrMutateCachedSettings()
    {
        var config=new MarketBestSellingSectionConfig { Items=new() {new() { ProductId=100,Active=true,Order=1 }} };
        settings.Setup(s=>s.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig",null)).ReturnsAsync(config);
        settings.Setup(s=>s.SetValue("MarketBestSellingConfig",It.IsAny<MarketBestSellingSectionConfig>(),null)).ThrowsAsync(new InvalidOperationException("DB unavailable"));
        var controller=new MarketBestSellingController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<MarketBestSellingController>.Instance);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>controller.RemoveItem(100));Assert.Single(config.Items);
    }
    [Fact]
    public async Task BestSellingConfigFiltersNullEntriesAndPreservesRequestedOrder()
    {
        var controller=new MarketBestSellingController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<MarketBestSellingController>.Instance);
        var config=new MarketBestSellingSectionConfig { Items=new() {null!,new() {ProductId=100,Order=7,Active=true}} };
        Assert.True((await controller.SaveConfig(config)).Value);Assert.Single(config.Items);Assert.Equal(1,config.Items[0].Order);
    }
    [Fact]
    public async Task SettingsReadFailureDoesNotSeedOrOverwriteBestSellingConfig()
    {
        settings.Setup(s=>s.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig",null)).ThrowsAsync(new InvalidOperationException("Read failed"));
        var controller=new MarketBestSellingController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<MarketBestSellingController>.Instance);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>controller.GetConfig());
        settings.Verify(s=>s.SetValue(It.IsAny<string>(),It.IsAny<MarketBestSellingSectionConfig>(),null),Times.Never);
    }
    App.ApiControllers.V1.Customer.ProductsController Customer() => new(products, new TrackableRepository<MerchantProduct,CatalogDbContext>(db),categories,merchants,null,uow,null,
        NullLogger<App.ApiControllers.V1.Customer.ProductsController>.Instance,settings.Object);
    [Theory]
    [InlineData("Manual")][InlineData("Hybrid")][InlineData("Auto")]
    public async Task PopularHonorsConfiguredMaximumAndUsesMerchantDeliveryTime(string mode)
    {
        db.Products.Add(new Product {Id=200,Title="Second",Active=true,Unit="قطعة",ProductCategoryId=2});
        db.MerchantProducts.Add(new MerchantProduct {ProductId=200,MerchantId=30,MerchantPrice=500});await db.SaveChangesAsync();
        var config=new PopularSectionConfig {Mode=mode,MaxItems=1,Items=new() {new(){ProductId=100,Order=1,Active=true},new(){ProductId=200,Order=2,Active=true}}};
        settings.Setup(s=>s.GetValue<PopularSectionConfig>("PopularProductsConfig",null)).ReturnsAsync(config);
        var item=Assert.Single((await Customer().GetPopular(100)).Value!);
        Assert.Equal(db.Merchants.Find(30)!.DeliveryTime,item.Eta);Assert.Equal("",item.Distance);
        config.Enabled=false;Assert.Empty((await Customer().GetPopular(100)).Value!);
    }
    [Theory]
    [InlineData("Manual",false)][InlineData("Hybrid",false)][InlineData("Auto",false)]
    [InlineData("Manual",true)][InlineData("Hybrid",true)][InlineData("Auto",true)]
    public async Task ExplicitlyHiddenProductsCannotReturnThroughAutomaticRanking(string mode,bool bestSelling)
    {
        var popular=new PopularSectionConfig {Mode=mode,Items=new(){new(){ProductId=100,Active=false,Order=1}}};
        var best=new MarketBestSellingSectionConfig {Mode=mode,Items=new(){new(){ProductId=100,Active=false,Order=1}}};
        settings.Setup(s=>s.GetValue<PopularSectionConfig>("PopularProductsConfig",null)).ReturnsAsync(popular);
        settings.Setup(s=>s.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig",null)).ReturnsAsync(best);
        if(bestSelling) Assert.Empty(Assert.IsType<PopularProductDto[]>(Assert.IsType<OkObjectResult>((await Customer().GetMarketBestSelling(30,50)).Result).Value));
        else Assert.Empty((await Customer().GetPopular(100)).Value!);
    }
    [Fact]
    public async Task BestSellingDoesNotInventDeliveryTimeOrDistance()
    {
        db.Merchants.Find(30)!.DeliveryTime=null; await db.SaveChangesAsync();
        settings.Setup(s=>s.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig",null)).ReturnsAsync(new MarketBestSellingSectionConfig {Mode="Auto"});
        var items=Assert.IsType<PopularProductDto[]>(Assert.IsType<OkObjectResult>((await Customer().GetMarketBestSelling(30,50)).Result).Value);
        var item=Assert.Single(items); Assert.Equal("",item.Eta); Assert.Equal("",item.Distance); Assert.Equal("Grocery",item.MerchantTitle);
    }
    [Theory]
    [InlineData(false)][InlineData(true)]
    public async Task CandidateSearchFiltersUnavailableProductsBeforeTakingThePage(bool bestSelling)
    {
        var popular=new PopularSectionConfig {Items=new()};var best=new MarketBestSellingSectionConfig {Items=new()};
        settings.Setup(s=>s.GetValue<PopularSectionConfig>("PopularProductsConfig",null)).ReturnsAsync(popular);
        settings.Setup(s=>s.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig",null)).ReturnsAsync(best);
        db.Products.Add(new Product {Id=200,Title="A Unpriced",Active=true,Unit="قطعة",ProductCategoryId=2,IsFeatured=true});
        db.MerchantProducts.Add(new MerchantProduct {ProductId=200,MerchantId=30,MerchantPrice=0});await db.SaveChangesAsync();
        var result=bestSelling
          ? (await new MarketBestSellingController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<MarketBestSellingController>.Instance).SearchProducts(take:1)).Value!
          : (await new PopularProductsController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<PopularProductsController>.Instance).SearchProducts(take:1)).Value!;
        Assert.Equal(100,Assert.Single(result).Id);
        db.ProductCategories.Find(1)!.Active=false;await db.SaveChangesAsync();
        result=bestSelling
          ? (await new MarketBestSellingController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<MarketBestSellingController>.Instance).SearchProducts(take:1)).Value!
          : (await new PopularProductsController(products,merchants,categories,settings.Object,uow,cache,null,NullLogger<PopularProductsController>.Instance).SearchProducts(take:1)).Value!;
        Assert.Empty(result);
    }
    public void Dispose() {db.Dispose();cache.Dispose();}
}
