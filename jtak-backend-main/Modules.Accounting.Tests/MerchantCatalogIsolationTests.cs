using App.ApiControllers.V1.Admin;
using App.Catalog.Data;
using App.Setup;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Moq;
using Solf.Identity;
using Xunit;

namespace Modules.Accounting.Tests;

public class MerchantCatalogIsolationTests
{
    [Theory]
    [InlineData(MerchantKind.Restaurant)]
    [InlineData(MerchantKind.Grocery)]
    [InlineData(MerchantKind.Pharmacy)]
    [InlineData(MerchantKind.Store)]
    [InlineData(MerchantKind.DarkStore)]
    public async Task NewMerchantStaysEmptyAcrossStartupAndOnlyReceivesExplicitAssignments(MerchantKind kind)
    {
        using var catalog = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var identity = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var root = new ProductCategory { Id = 1, Title = "Market categories", Active = true };
        var sub = new ProductCategory { Id = 2, Title = "Groceries", ParentId = 1, Active = true };
        catalog.ProductCategories.AddRange(root, sub);
        catalog.Products.AddRange(
            new Product { Id = 101, Title = "Jtak product", Active = true, ProductCategoryId = 2 },
            new Product { Id = 102, Title = "Other merchant product", Active = true, ProductCategoryId = 2 });
        catalog.Merchants.AddRange(
            new Merchant { Id = 12, Title = "JTAK Market", Active = true, MerchantKind = MerchantKind.Grocery },
            new Merchant { Id = 27, Title = "Restaurant", Active = true, MerchantKind = MerchantKind.Restaurant });
        catalog.MerchantProducts.AddRange(
            new MerchantProduct { MerchantId = 12, ProductId = 101, MerchantPrice = 302m },
            new MerchantProduct { MerchantId = 27, ProductId = 102, MerchantPrice = 500m });
        await catalog.SaveChangesAsync();

        // Use the real startup seed path with existing identity and catalog data.
        foreach (var name in new[] { "Admin", "Merchant", "Delivery", "Customer" })
        {
            var roleId = Guid.NewGuid();
            identity.Roles.Add(new SolRole {
                Id = roleId, Name = name, NormalizedName = name.ToUpperInvariant(),
                RolePermissions = Enum.GetValues<AppPermissionKey>()
                    .Select(key => new RolePermission(roleId, (byte)key)).ToList()
            });
        }
        await identity.SaveChangesAsync();
        var roles = new Mock<RoleManager<SolRole>>(Mock.Of<IRoleStore<SolRole>>(), null, null, null, null);
        roles.Setup(x => x.Roles).Returns(identity.Roles);
        var owner = new AppUser { Id = Guid.NewGuid(), FullName = "New owner", IsActive = true };
        var users = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(),
            null, null, null, null, null, null, null, null);
        users.Setup(x => x.FindByIdAsync(owner.Id.ToString())).ReturnsAsync(owner);
        users.Setup(x => x.IsInRoleAsync(owner, "Merchant")).ReturnsAsync(true);
        users.Setup(x => x.FindByEmailAsync(It.IsAny<string>())).ReturnsAsync(owner);
        var settings = new Mock<IGenericSettingService>();
        settings.Setup(x => x.Queryable()).Returns(new[] { new GenericSetting() }.AsQueryable());
        var products = new Mock<IProductService>();
        products.Setup(x => x.Queryable()).Returns(catalog.Products);
        var categories = new Mock<IProductCategoryService>();
        categories.Setup(x => x.Queryable()).Returns(catalog.ProductCategories);
        var uow = new CatalogUnitOfWork(catalog);
        var merchants = new MerchantService(new TrackableRepository<Merchant, CatalogDbContext>(catalog),
            new TrackableRepository<MerchantProduct, CatalogDbContext>(catalog), uow, settings.Object, cache);
        var controller = new MerchantsController(merchants, products.Object, uow, null, null,
            NullLogger<MerchantsController>.Instance, cache, null, users.Object);
        var result = await controller.Create(new MerchantDto {
            Title = "New merchant", OwnerId = owner.Id, MerchantKind = kind,
            ProfitOutOfMerchantPricePercent = 10m
        });
        var newId = result.Value;
        Assert.True(newId > 0);
        Assert.Empty(await merchants.GetAllMerchantPrices(newId));

        var services = new ServiceCollection();
        services.AddSingleton(new SeedRoles(roles.Object));
        services.AddSingleton(new SeedUsers(users.Object));
        services.AddSingleton(new SeedContent(null, uow, null, null, null,
            categories.Object, products.Object, merchants, settings.Object, users.Object));
        using var provider = services.BuildServiceProvider();
        await provider.EnsureSeedData();
        await provider.EnsureSeedData();
        Assert.Empty(await merchants.GetAllMerchantPrices(newId));
        var picker = (await controller.GetProducts(newId)).Value!;
        Assert.Equal(2, picker.Length);
        Assert.All(picker, item => Assert.Equal(0, item.MerchantId));
        Assert.Empty(picker.Where(item => item.MerchantId == newId).Select(item => item.ProductCategoryId));

        await merchants.AssignMerchantProducts(new[] { newId }, new[] {
            new MerchantProductAssignDto { ProductId = 101, MerchantPrice = 250m }
        });
        await provider.EnsureSeedData();
        var assigned = await merchants.GetAllMerchantPrices(newId);
        Assert.Single(assigned);
        Assert.Equal(250m, assigned[101].MerchantPrice);
        Assert.Equal(302m, (await merchants.GetAllMerchantPrices(12))[101].MerchantPrice);
        Assert.Equal(500m, (await merchants.GetAllMerchantPrices(27))[102].MerchantPrice);
        Assert.Equal(3, await catalog.MerchantProducts.CountAsync());
    }
}
