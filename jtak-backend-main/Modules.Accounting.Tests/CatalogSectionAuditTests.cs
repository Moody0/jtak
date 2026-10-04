using System.Security.Claims;
using App.ApiControllers.V1.Admin;
using App.ApiControllers.V1.Admin.Catalog;
using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Data.MultiContext;
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
using Xunit;
using WarehouseProducts = App.ApiControllers.V1.Warehouse.ProductsController;
using AdminProducts = App.ApiControllers.V1.Admin.ProductsController;

namespace Modules.Accounting.Tests;

public class CatalogSectionAuditTests : IDisposable
{
    readonly CatalogDbContext db;
    readonly MemoryCache cache = new(new MemoryCacheOptions());
    readonly CatalogUnitOfWork uow;
    readonly ProductService products;
    readonly ProductCategoryService categories;
    readonly MerchantService merchants;
    readonly Mock<IGenericSettingService> settings = new();
    readonly Guid owner = Guid.NewGuid();

    public CatalogSectionAuditTests()
    {
        db = new(new DbContextOptionsBuilder<CatalogDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        uow = new(db);
        settings.Setup(x => x.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key, null))
            .ReturnsAsync(new UsdExchangeRateSetting { Rate = 100m });
        products = new(uow, new TrackableRepository<Tag, CatalogDbContext>(db),
            new TrackableRepository<ProductTag, CatalogDbContext>(db), new TrackableRepository<Product, CatalogDbContext>(db), cache,
            new TrackableRepository<ProductCategory, CatalogDbContext>(db));
        categories = new(new TrackableRepository<ProductCategory, CatalogDbContext>(db), cache);
        merchants = new(new TrackableRepository<Merchant, CatalogDbContext>(db),
            new TrackableRepository<MerchantProduct, CatalogDbContext>(db), uow, settings.Object, cache, categories:
            new TrackableRepository<ProductCategory, CatalogDbContext>(db));
        db.ProductCategories.AddRange(new ProductCategory { Id = 1, Title = "Root", Active = true },
            new ProductCategory { Id = 2, Title = "Child", ParentId = 1, Active = true });
        db.Merchants.AddRange(new Merchant { Id = 12, Title = "JTAK Market", Active = true, OwnerId = owner, MerchantKind = MerchantKind.Grocery },
            new Merchant { Id = 30, Title = "Other grocery", Active = true, OwnerId = Guid.NewGuid(), MerchantKind = MerchantKind.Grocery });
        db.Products.AddRange(new Product { Id = 100, Title = "Mine", Unit = "قطعة", Active = true, ProductCategoryId = 2, Photos = "old.webp" },
            new Product { Id = 200, Title = "Other", Unit = "قطعة", Active = true, ProductCategoryId = 2 });
        db.MerchantProducts.AddRange(new MerchantProduct { MerchantId = 12, ProductId = 100, MerchantPrice = 500, MaxOrderQuantity = 5 },
            new MerchantProduct { MerchantId = 30, ProductId = 200, MerchantPrice = 700 });
        db.SaveChanges();
    }

    WarehouseProducts Warehouse()
    {
        var controller = new WarehouseProducts(products, merchants, categories, null, uow, cache, null,
            NullLogger<WarehouseProducts>.Instance);
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, owner.ToString()) }, "test")) } };
        return controller;
    }
    ProductCategoriesController CategoryAdmin() => new(categories, uow, NullLogger<ProductCategoriesController>.Instance, null, cache);
    AdminProducts ProductAdmin(Microsoft.AspNetCore.Hosting.IWebHostEnvironment env = null) => new(products, categories, merchants, Mock.Of<ITagService>(),
        new TrackableRepository<MerchantProduct, CatalogDbContext>(db), uow, cache, null, env, NullLogger<AdminProducts>.Instance);
    App.ApiControllers.V1.Warehouse.MerchantProductManageDto Dto(string title = "Mine", decimal price = 500) => new() {
        Title = title, Price = price, Unit = "قطعة", Active = true, ProductCategoryId = 2, Photos = "old.webp", MaxOrderQuantity = 5 };

    [Theory]
    [InlineData("edit")][InlineData("availability")][InlineData("delete")][InlineData("detail")]
    public async Task WarehouseCannotMutateOrReadAnotherMerchantsProduct(string action)
    {
        var c = Warehouse();
        IActionResult result = action switch {
            "edit" => (await c.Update(200, Dto("Stolen"))).Result,
            "availability" => (await c.ToggleAvailability(200)).Result,
            "delete" => (await c.Delete(200)).Result,
            _ => (await c.Get(200)).Result
        };
        Assert.IsType<NotFoundResult>(result);
        Assert.Equal("Other", db.Products.Find(200)!.Title);
        Assert.True(db.Products.Find(200)!.Active);
        Assert.Null(db.Products.Find(200)!.DeletionDate);
    }

    [Fact]
    public async Task BatchPricesCannotAssignAnotherCatalogProductToSelf()
    {
        var result = await Warehouse().SetPrices(12, new[] { new MerchantProductPriceDto { ProductId = 200, MerchantPrice = 10 } });
        Assert.IsType<ForbidResult>(result.Result);
        Assert.False(await db.MerchantProducts.AnyAsync(x => x.MerchantId == 12 && x.ProductId == 200));
    }

    [Fact]
    public async Task OwnDetailContainsCanonicalMerchantPriceAndUnavailableProduct()
    {
        db.Products.Find(100)!.Active = false; await db.SaveChangesAsync();
        var detail = (await Warehouse().Get(100)).Value;
        Assert.Equal(500m, detail!.MerchantPrice);
        Assert.False(detail.ProductActive);
        Assert.Equal(100, detail.ProductId);
    }

    [Fact]
    public async Task UpdateClearsPhotoAndInvalidatesCachedOrderAndPriceDetails()
    {
        cache.Set("Product-100", "old"); cache.Set("ProductPrices_100", "old"); cache.Set("MerchantProduct_12_100", "old");
        var dto = Dto(); dto.Photos = "";
        Assert.IsType<OkObjectResult>((await Warehouse().Update(100, dto)).Result);
        Assert.Equal("", db.Products.Find(100)!.Photos);
        Assert.False(cache.TryGetValue("Product-100", out _));
        Assert.False(cache.TryGetValue("ProductPrices_100", out _));
        Assert.False(cache.TryGetValue("MerchantProduct_12_100", out _));
    }

    [Fact]
    public async Task SharedProductDeleteOnlyUnlinksCurrentMerchant()
    {
        db.MerchantProducts.Add(new MerchantProduct { MerchantId = 30, ProductId = 100, MerchantPrice = 900 });
        await db.SaveChangesAsync();
        Assert.IsType<OkObjectResult>((await Warehouse().Delete(100)).Result);
        Assert.Null(db.Products.Find(100)!.DeletionDate);
        Assert.True(await db.MerchantProducts.AnyAsync(x => x.MerchantId == 30 && x.ProductId == 100));
        Assert.False(await db.MerchantProducts.AnyAsync(x => x.MerchantId == 12 && x.ProductId == 100));
    }

    [Fact]
    public async Task SharedMetadataAndAvailabilityCannotChangeAnotherStoreButPriceCan()
    {
        db.MerchantProducts.Add(new MerchantProduct { MerchantId = 30, ProductId = 100, MerchantPrice = 900 }); await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>((await Warehouse().Update(100, Dto("Changed"))).Result);
        Assert.IsType<BadRequestObjectResult>((await Warehouse().ToggleAvailability(100)).Result);
        Assert.IsType<OkObjectResult>((await Warehouse().Update(100, Dto(price: 600))).Result);
        Assert.Equal(900, db.MerchantProducts.Find(30, 100)!.MerchantPrice);
        Assert.Equal(600, db.MerchantProducts.Find(12, 100)!.MerchantPrice);
    }

    [Theory][InlineData(-1)][InlineData(0)]
    public async Task WarehouseRejectsNonPositivePricesBeforeChangingAnything(decimal price)
    {
        Assert.IsType<BadRequestObjectResult>((await Warehouse().Create(Dto(price: price))).Result);
        Assert.IsType<BadRequestObjectResult>((await Warehouse().Update(100, Dto(price: price))).Result);
        Assert.Equal(500, db.MerchantProducts.Find(12, 100)!.MerchantPrice);
    }

    [Theory][InlineData(1)][InlineData(2)]
    public async Task CategoryCannotBePlacedInsideItselfOrItsDescendant(int parent)
    {
        var result = await CategoryAdmin().Edit(1, new ProductCategoryDto { Title = "Root", ParentId = parent, Active = true });
        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Null(db.ProductCategories.Find(1)!.ParentId);
    }

    [Fact]
    public async Task CategoryCannotDeleteParentWithChildren()
    {
        Assert.IsType<BadRequestObjectResult>((await CategoryAdmin().Delete(1)).Result);
        Assert.Null(db.ProductCategories.Find(1)!.DeletionDate);
    }

    [Theory][InlineData("   ", null)][InlineData("Valid", 999)]
    public async Task CategoryRejectsBlankNameOrMissingParent(string title, int? parent)
    {
        Assert.IsType<BadRequestObjectResult>((await CategoryAdmin().Create(new ProductCategoryDto { Title = title, ParentId = parent })).Result);
        Assert.Equal(2, await db.ProductCategories.CountAsync());
    }

    [Fact]
    public async Task EditingOneMerchantOfferPreservesOtherMerchantAssignments()
    {
        db.MerchantProducts.Add(new MerchantProduct { MerchantId = 30, ProductId = 100, MerchantPrice = 900 }); await db.SaveChangesAsync();
        await ProductAdmin().Edit(100, new ProductDto { Title = "Mine", Unit = "قطعة", Active = true, ProductCategoryId = 2,
            MerchantId = 12, Price = 600, DiscountPercent = 0 });
        Assert.Equal(900, db.MerchantProducts.Find(30, 100)!.MerchantPrice);
        Assert.Equal(600, db.MerchantProducts.Find(12, 100)!.MerchantPrice);
    }

    [Fact]
    public async Task AdminCanCreateAProductForAnInactiveIndependentGroceryWithoutMarketAssignment()
    {
        db.Merchants.Find(30)!.Active = false; await db.SaveChangesAsync();
        var result = await ProductAdmin().Create(new ProductDto { Title = "New", ProductCategoryId = 2, MerchantId = 30, Price = 100 });
        Assert.True(result.Value > 0);
        Assert.NotNull(await db.MerchantProducts.FindAsync(30, result.Value));
        Assert.Null(await db.MerchantProducts.FindAsync(12, result.Value));
    }

    [Fact]
    public async Task DuplicateKeepsMerchantAndPriceAndUnitAndPromotion()
    {
        var offer = db.MerchantProducts.Find(30, 200)!; offer.DiscountPercent = 5; offer.MaxOrderQuantity = 3;
        var source = db.Products.Find(200)!; source.IsFeatured = false; source.Description = "Description";
        await db.SaveChangesAsync();
        var result = await ProductAdmin().Duplicate(200);
        var copy = db.Products.Find(result.Value)!;
        Assert.Equal(source.Unit, copy.Unit); Assert.False(copy.IsFeatured);
        var copiedOffer = db.MerchantProducts.Find(30, copy.Id)!;
        Assert.Equal(700, copiedOffer.MerchantPrice); Assert.Equal(5, copiedOffer.DiscountPercent);
        Assert.Equal(3, copiedOffer.MaxOrderQuantity);
        Assert.Null(db.MerchantProducts.Find(12, copy.Id));
    }

    [Fact]
    public async Task RestaurantCategoryEditPersistsAndClearsItsCatalogLink()
    {
        var config = new RestaurantCategoriesSectionConfig { Items = new() { new() { Id = 1, Title = "Meals", ProductCategoryId = 1 } } };
        settings.Setup(x => x.GetValue<RestaurantCategoriesSectionConfig>(RestaurantCategoriesController.SettingKey, null)).ReturnsAsync(config);
        settings.Setup(x => x.SetValue(RestaurantCategoriesController.SettingKey, It.IsAny<RestaurantCategoriesSectionConfig>(), null)).Returns(Task.CompletedTask);
        var c = new RestaurantCategoriesController(settings.Object, merchants, categories, cache, NullLogger<RestaurantCategoriesController>.Instance);
        await c.UpdateItem(new RestaurantCategoryItem { Id = 1, Title = "Meals", Active = true, ProductCategoryId = 2 });
        Assert.Equal(2, config.Items[0].ProductCategoryId);
        await c.UpdateItem(new RestaurantCategoryItem { Id = 1, Title = "Meals", Active = true, ProductCategoryId = null });
        Assert.Null(config.Items[0].ProductCategoryId);
    }

    [Fact]
    public async Task DisablingRootHidesDescendantsAndInvalidatesPreviouslyCachedProductPrices()
    {
        Assert.NotNull(await products.GetProduct(100));
        Assert.NotEmpty(await merchants.GetProductPrices(100));
        Assert.NotNull(await merchants.GetMerchantProductPrice(12, 100));
        var result = await CategoryAdmin().Edit(1, new ProductCategoryDto { Title = "Root", Active = false });
        Assert.Equal(1, result.Value);
        Assert.Null(await products.GetProduct(100));
        Assert.Empty(await merchants.GetProductPrices(100));
        Assert.Null(await merchants.GetMerchantProductPrice(12, 100));
        Assert.Empty(await categories.GetProductCategories());
        Assert.Single(((OkObjectResult)(await Warehouse().Get()).Result!).Value as MerchantProductDto[]);
    }

    [Fact]
    public async Task CategoryVisibilityRequiresEveryAncestorAndExcludesOrphansAndCycles()
    {
        db.ProductCategories.AddRange(new ProductCategory { Id = 3, Title = "Grandchild", ParentId = 2, Active = true },
            new ProductCategory { Id = 4, Title = "Orphan", ParentId = 999, Active = true },
            new ProductCategory { Id = 5, Title = "Cycle", ParentId = 5, Active = true });
        await db.SaveChangesAsync();
        Assert.Equal(new[] { 1, 2, 3 }, (await CatalogCategoryVisibility.GetIdsAsync(categories.Queryable())).OrderBy(x => x));
        db.ProductCategories.Find(2)!.Active = false; await db.SaveChangesAsync();
        Assert.Equal(new[] { 1 }, await CatalogCategoryVisibility.GetIdsAsync(categories.Queryable()));
    }

    [Fact]
    public async Task LegacyOwnerWithTwoStoresReceivesSeparatePricesForEachStore()
    {
        db.Merchants.Find(30)!.OwnerId = owner;
        db.MerchantProducts.Add(new MerchantProduct { MerchantId = 30, ProductId = 100, MerchantPrice = 900 });
        await db.SaveChangesAsync();
        var rows = (MerchantProductDto[])((OkObjectResult)(await Warehouse().Get()).Result!).Value!;
        Assert.Equal(500m, rows.Single(x => x.ProductId == 100 && x.MerchantId == 12).MerchantPrice);
        Assert.Equal(900m, rows.Single(x => x.ProductId == 100 && x.MerchantId == 30).MerchantPrice);
    }

    [Fact]
    public async Task CustomerDetailNeverFallsBackToAnotherStoreOrAnInactiveOffer()
    {
        var mapper = new Mock<AutoMapper.IMapper>();
        mapper.Setup(x => x.Map<ProductDto>(It.IsAny<Product>())).Returns((Product p) => new ProductDto { Id = p.Id, Title = p.Title });
        var customer = new App.ApiControllers.V1.Customer.ProductsController(products,
            new TrackableRepository<MerchantProduct, CatalogDbContext>(db), categories, merchants, null, uow,
            mapper.Object, NullLogger<App.ApiControllers.V1.Customer.ProductsController>.Instance);
        Assert.IsType<NotFoundResult>((await customer.Get(100, 30)).Result);
        db.Merchants.Find(12)!.Active = false; await db.SaveChangesAsync();
        cache.Remove("ProductPrices_100");
        Assert.IsType<NotFoundResult>((await customer.Get(100, 12)).Result);
        Assert.Empty((await customer.GetMerchantProducts(12)).Value!);
    }

    [Fact]
    public async Task ProductListCombinesCategoryStatusAndPaginationAndAcceptsCategorySorting()
    {
        db.Products.Find(200)!.Active = false; await db.SaveChangesAsync();
        var result = (await ProductAdmin().DataTable(new Solf.Models.MetronicTable {
            PageNumber = 1, PageSize = 1, SortField = "productCategory", SortOrder = "asc" }, 1, false)).Value!;
        Assert.Equal(1, result.TotalRecords);
        Assert.Equal(200, Assert.Single(result.Items).Id);
    }

    [Fact]
    public async Task CategoryListFiltersStatusParentAndLevelBeforeCounting()
    {
        db.ProductCategories.Find(2)!.Active = false; await db.SaveChangesAsync();
        var result = (await CategoryAdmin().DataTable(new Solf.Models.MetronicTable {
            PageNumber = 1, PageSize = 10, SortField = "id", SortOrder = "asc" }, "sub", 1, false)).Value!;
        Assert.Equal(1, result.TotalRecords); Assert.Equal(2, Assert.Single(result.Items).Id);
        var empty = (await CategoryAdmin().DataTable(new Solf.Models.MetronicTable { PageNumber = 1, PageSize = 10 }, "sub", 1, true)).Value!;
        Assert.Empty(empty.Items); Assert.Equal(0, empty.TotalRecords);
    }

    [Fact]
    public async Task AdminPublicationBadgeKeepsDraftStoreAssignmentAndHonorsDisabledCategories()
    {
        db.Merchants.Find(12)!.Active = false;
        db.ProductCategories.Find(1)!.Active = false;
        await db.SaveChangesAsync();
        var result = (await ProductAdmin().DataTable(new Solf.Models.MetronicTable { PageNumber = 1, PageSize = 10 })).Value!;
        var own = result.Items.Single(x => x.Id == 100);
        Assert.Equal(12, own.MerchantId); Assert.Equal(500m, own.Price); Assert.False(own.IsPublishedToCustomer);
        Assert.False(result.Items.Single(x => x.Id == 200).IsPublishedToCustomer);
    }

    [Theory]
    [InlineData(false)][InlineData(true)]
    public async Task ExcelImportUsesOneBasedColumnsAndRejectsIncompleteWorkbooks(bool incomplete)
    {
        var env = new Mock<Microsoft.AspNetCore.Hosting.IWebHostEnvironment>();
        var root = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "jtak-catalog-audit", Guid.NewGuid().ToString("N"));
        env.SetupGet(x => x.ContentRootPath).Returns(root);
        var token = $"2026_10_04_{Guid.NewGuid():N}.xlsx";
        var path = root + App.Helpers.FileHelper.GetVirtualPath(token).Replace("/", "\\").Replace("~", "");
        System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        OfficeOpenXml.ExcelPackage.LicenseContext = OfficeOpenXml.LicenseContext.NonCommercial;
        using (var book = new OfficeOpenXml.ExcelPackage()) {
            var p = book.Workbook.Worksheets.Add("Products"); p.Cells[1, 1].Value = "Title"; p.Cells[1, 2].Value = "Category";
            p.Cells[2, 1].Value = "Imported"; p.Cells[2, 2].Value = "Imported child";
            if (!incomplete) {
                var sub = book.Workbook.Worksheets.Add("Subcategories"); sub.Cells[1, 1].Value = "Title"; sub.Cells[1, 2].Value = "Parent";
                sub.Cells[2, 1].Value = "Imported child"; sub.Cells[2, 2].Value = "Imported root";
                var r = book.Workbook.Worksheets.Add("Roots"); r.Cells[1, 1].Value = "Title"; r.Cells[2, 1].Value = "Imported root";
                r.Cells[3, 1].Value = "Imported root";
            }
            book.SaveAs(new System.IO.FileInfo(path));
        }
        var result = await ProductAdmin(env.Object).BulkImport(new App.ApiModels.Admin.ProductsBulkImport { File = token });
        if (incomplete) Assert.IsType<BadRequestObjectResult>(result.Result);
        else {
            Assert.Equal(1, result.Value!.ImportedCat1); Assert.Equal(1, result.Value.ImportedCat2); Assert.Equal(1, result.Value.ImportedProds);
            Assert.False(db.ProductCategories.Any(x => x.Title == "Title"));
            Assert.True(db.Products.Any(x => x.Title == "Imported"));
        }
    }

    public void Dispose() { db.Dispose(); cache.Dispose(); }
}
