using App.ApiControllers.V1.Admin;
using App.Catalog.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Moq;
using Solf.Models;

namespace Modules.Accounting.Tests;

public class CustomerInterfaceBannerAuditTests : IDisposable
{
    readonly AppDbContext db = new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
    readonly MemoryCache cache = new(new MemoryCacheOptions());
    readonly BannerController controller;
    readonly BannerService service;
    public CustomerInterfaceBannerAuditTests()
    {
        service = new(new TrackableRepository<Banner, AppDbContext>(db), null, cache);
        controller = new(new AppUnitOfWork(db), null, null, service, NullLogger<BannerController>.Instance, cache, null);
        controller.ControllerContext = new() { HttpContext = new DefaultHttpContext() };
    }
    BannerDto Valid() => new() { Title = "ماركت ومطاعم", Active = true, FeaturedImage = "banner.webp", Url = "https://example.com/#sale", BannerLocation = BannerLocation.HomePage };
    [Theory]
    [InlineData("title")][InlineData("image")][InlineData("location")][InlineData("order")][InlineData("url")][InlineData("zero")][InlineData("negative")]
    public async Task InvalidBannerCannotBeCreatedOrEdited(string field)
    {
        var dto = Valid();
        switch (field) { case "title": dto.Title = " "; break; case "image": dto.FeaturedImage = " "; break;
          case "location": dto.BannerLocation = (BannerLocation)99; break; case "order": dto.Order = -1; break;
          case "url": dto.Url = "javascript:alert(1)"; break; case "zero": dto.Url = "market:0"; break; case "negative": dto.Url = "restaurant:-1"; break; }
        Assert.IsType<BadRequestObjectResult>((await controller.Create(dto)).Result);
        Assert.IsType<BadRequestObjectResult>((await controller.Edit(1, dto)).Result);
        Assert.Empty(db.Set<Banner>());
    }
    [Theory]
    [InlineData(0)][InlineData(1)][InlineData(2)][InlineData(3)][InlineData(4)]
    public async Task ExplicitPlacementSurvivesMarketingTextAndCacheInvalidation(int location)
    {
        foreach (var l in Enum.GetValues<BannerLocation>()) cache.Set($"BannerCache_{l}", "old");
        cache.Set("BannerCache_AllActive", "old");
        var dto = Valid(); dto.BannerLocation = (BannerLocation)location; dto.Url += "#section:market";
        var result = await controller.Create(dto);
        Assert.True(result.Value > 0); Assert.Equal((BannerLocation)location, db.Set<Banner>().Single().BannerLocation);
        Assert.Equal("https://example.com/#sale", db.Set<Banner>().Single().Url);
        foreach (var l in Enum.GetValues<BannerLocation>()) Assert.False(cache.TryGetValue($"BannerCache_{l}", out _));
        Assert.False(cache.TryGetValue("BannerCache_AllActive", out _));
    }
    [Fact]
    public async Task BulkStatusPreservesDestinationAndRejectsMissingIdsBeforeAnyMutation()
    {
        await controller.Create(Valid()); var banner = db.Set<Banner>().Single();
        Assert.IsType<BadRequestObjectResult>((await controller.BulkStatus(new() { Ids = new[] { banner.Id, 999 }, Active = false })).Result);
        Assert.True(banner.Active);
        Assert.True((await controller.BulkStatus(new() { Ids = new[] { banner.Id }, Active = false })).Value);
        Assert.False(banner.Active); Assert.Equal("https://example.com/#sale", banner.Url); Assert.Equal("ماركت ومطاعم", banner.Title);
        Assert.Empty(await service.GetAllActiveBanners());
    }
    [Fact]
    public async Task BulkDeleteRejectsMissingIdsBeforeDeletingAndDeletesSelectionTogether()
    {
        await controller.Create(Valid()); await controller.Create(Valid()); var ids = db.Set<Banner>().Select(x => x.Id).ToArray();
        Assert.IsType<BadRequestObjectResult>((await controller.BulkDelete(new() { Ids = new[] { ids[0], 999 } })).Result);
        Assert.Equal(2, db.Set<Banner>().Count());
        Assert.True((await controller.BulkDelete(new() { Ids = ids })).Value); Assert.Empty(db.Set<Banner>());
        Assert.IsType<NotFoundObjectResult>((await controller.Delete(ids[0])).Result);
    }
    [Fact]
    public async Task FiltersApplyBeforePaginationAndSummaryIsGlobal()
    {
        for (var i = 0; i < 12; i++) { var b = Valid(); b.Active = i % 2 == 0; b.BannerLocation = i < 6 ? BannerLocation.RestaurantsPage : BannerLocation.DontMiss; await controller.Create(b); }
        var result = await controller.DataTable(new MetronicTable { PageSize = 2, PageNumber = 1 }, "dont_miss", "active");
        Assert.Equal(3, result.Value.TotalRecords); Assert.Equal(2, result.Value.Items.Count());
        Assert.All(result.Value.Items, b => { Assert.True(b.Active); Assert.Equal(BannerLocation.DontMiss, b.BannerLocation); });
        var summary = (await controller.Summary()).Value;
        Assert.Equal(12, summary.GetType().GetProperty("Total")!.GetValue(summary));
        Assert.Equal(6, summary.GetType().GetProperty("DontMiss")!.GetValue(summary));
    }
    public void Dispose() { db.Dispose(); cache.Dispose(); }
}

public class CustomerInterfaceHomeValidationAuditTests
{
    [Theory]
    [InlineData("null")][InlineData("link")][InlineData("kind")][InlineData("zero")][InlineData("negative")][InlineData("max")][InlineData("duplicate")]
    public async Task InvalidHomeConfigIsRejectedWithoutSaving(string scenario)
    {
        var home = new Mock<IHomeCategoriesService>(MockBehavior.Strict);
        var controller = new HomeCategoriesController(home.Object, null, null, null);
        var tile = new HomeCategoryTile { Id = "same", Title = "طلبات", LinkType = HomeCategoryLinkType.ErrandRequests };
        var config = new HomeCategoriesConfig { Tiles = new() { tile } };
        switch (scenario) { case "null": config.Tiles.Add(null!); break; case "link": tile.LinkType = (HomeCategoryLinkType)99; break;
          case "kind": tile.MerchantKind = (MerchantKind)99; break; case "zero": tile.MerchantId = 0; break;
          case "negative": tile.SecondaryProductCategoryId = -1; break; case "max": config.MaxItems = -1; break;
          case "duplicate": config.Tiles.Add(new() { Id = "same", Title = "بحث", LinkType = HomeCategoryLinkType.Search, SearchTerm = "قهوة" }); break; }
        Assert.IsType<BadRequestObjectResult>((await controller.Put(config)).Result);
        home.VerifyNoOtherCalls();
    }
}
