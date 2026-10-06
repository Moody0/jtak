using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.ApiControllers.V1.Authorization;
using App.ApiControllers.V1.Warehouse;
using App.Catalog.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Moq;
using Solf.Identity;
using Xunit;

namespace Modules.Accounting.Tests;

public class MerchantAccountBidirectionalSyncTests
{
    [Fact]
    public async Task AdminEditingMerchant_SyncsToOwnerUser_AndInvalidatesCustomerCaches()
    {
        using var catalog = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var identity = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var cache = new MemoryCache(new MemoryCacheOptions());

        var ownerId = Guid.NewGuid();
        var ownerUser = new AppUser
        {
            Id = ownerId,
            FullName = "Old Owner Name",
            FirstName = "Old",
            LastName = "Owner Name",
            PhoneNumber = "+963911111111",
            UserName = "+963911111111",
            IsActive = true
        };
        identity.Users.Add(ownerUser);
        await identity.SaveChangesAsync();

        var usersMock = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(),
            null, null, null, null, null, null, null, null);
        usersMock.Setup(x => x.Users).Returns(identity.Users);
        usersMock.Setup(x => x.FindByIdAsync(ownerId.ToString())).ReturnsAsync(ownerUser);
        usersMock.Setup(x => x.IsInRoleAsync(ownerUser, "Merchant")).ReturnsAsync(true);
        usersMock.Setup(x => x.UpdateAsync(It.IsAny<AppUser>())).ReturnsAsync(IdentityResult.Success);

        var merchant = new Merchant
        {
            Id = 15,
            Title = "Old Store Title",
            OwnerName = "Old Owner Name",
            OwnerId = ownerId,
            Phone1 = "+963911111111",
            Active = true,
            MerchantKind = MerchantKind.Restaurant
        };
        catalog.Merchants.Add(merchant);
        await catalog.SaveChangesAsync();

        cache.Set("RestaurantCategoriesCustomerCache", "cached_categories");
        cache.Set("GetValidMerchants", new[] { 15 });

        var uow = new CatalogUnitOfWork(catalog);
        var settingsMock = new Mock<IGenericSettingService>();
        var merchantRepo = new TrackableRepository<Merchant, CatalogDbContext>(catalog);
        var merchantProductRepo = new TrackableRepository<MerchantProduct, CatalogDbContext>(catalog);
        var merchantService = new MerchantService(merchantRepo, merchantProductRepo, uow, settingsMock.Object, cache);
        var productMock = new Mock<IProductService>();

        var controller = new MerchantsController(
            merchantService,
            productMock.Object,
            uow,
            null,
            null,
            NullLogger<MerchantsController>.Instance,
            cache,
            null,
            usersMock.Object
        );

        var editDto = new MerchantDto
        {
            Id = 15,
            Title = "New Delicious Restaurant",
            OwnerName = "New Owner FullName",
            Phone1 = "+963922222222",
            OwnerId = ownerId,
            Active = false,
            MerchantKind = MerchantKind.Restaurant,
            DeliveryFee = 5000m,
            MinOrderAmount = 15000m,
            ProfitOutOfMerchantPricePercent = 12m
        };

        var result = await controller.Edit(15, editDto);
        Assert.Equal(15, result.Value);

        // Verify AppUser was synchronized
        Assert.Equal("New Owner FullName", ownerUser.FullName);
        Assert.Equal("+963922222222", ownerUser.PhoneNumber);
        Assert.False(ownerUser.IsActive);
        usersMock.Verify(x => x.UpdateAsync(ownerUser), Times.Once);

        // Verify caches were invalidated
        Assert.False(cache.TryGetValue("RestaurantCategoriesCustomerCache", out _));
        Assert.False(cache.TryGetValue("GetValidMerchants", out _));
    }

    [Fact]
    public async Task WarehouseMerchantEditingStoreProfile_SyncsPhoneToOwnerUser_AndInvalidatesCustomerCaches()
    {
        using var catalog = new CatalogDbContext(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var identity = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var cache = new MemoryCache(new MemoryCacheOptions());

        var ownerId = Guid.NewGuid();
        var ownerUser = new AppUser
        {
            Id = ownerId,
            FullName = "Owner Guy",
            PhoneNumber = "+963911111111",
            UserName = "+963911111111",
            IsActive = true
        };
        identity.Users.Add(ownerUser);
        await identity.SaveChangesAsync();

        var usersMock = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(),
            null, null, null, null, null, null, null, null);
        usersMock.Setup(x => x.Users).Returns(identity.Users);
        usersMock.Setup(x => x.FindByIdAsync(ownerId.ToString())).ReturnsAsync(ownerUser);
        usersMock.Setup(x => x.UpdateAsync(It.IsAny<AppUser>())).ReturnsAsync(IdentityResult.Success);

        var merchant = new Merchant
        {
            Id = 22,
            Title = "My Shawarma Shop",
            OwnerId = ownerId,
            Phone1 = "+963911111111",
            Active = true,
            MerchantKind = MerchantKind.Restaurant
        };
        catalog.Merchants.Add(merchant);
        await catalog.SaveChangesAsync();

        cache.Set("RestaurantCategoriesCustomerCache", "cached_categories");
        cache.Set("GetValidMerchants", new[] { 22 });

        var uow = new CatalogUnitOfWork(catalog);
        var settingsMock = new Mock<IGenericSettingService>();
        var merchantRepo = new TrackableRepository<Merchant, CatalogDbContext>(catalog);
        var merchantProductRepo = new TrackableRepository<MerchantProduct, CatalogDbContext>(catalog);
        var merchantService = new MerchantService(merchantRepo, merchantProductRepo, uow, settingsMock.Object, cache);

        var controller = new App.ApiControllers.V1.Warehouse.MerchantController(
            merchantService,
            uow,
            cache,
            NullLogger<App.ApiControllers.V1.Warehouse.MerchantController>.Instance,
            usersMock.Object
        );

        // Set ClaimsPrincipal for logged in user (OpenIddict subject claim)
        var claimsIdentity = new ClaimsIdentity(new[]
        {
            new Claim(OpenIddict.Abstractions.OpenIddictConstants.Claims.Subject, ownerId.ToString())
        }, "TestScheme");
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(claimsIdentity) }
        };

        var updateDto = new MerchantProfileUpdateDto
        {
            Title = "My Shawarma Shop Updated",
            Phone1 = "+963933333333",
            Address = "New Location, Homs"
        };

        var result = await controller.UpdateProfile(updateDto);
        Assert.NotNull(result.Result as OkObjectResult);

        // Verify AppUser Phone was synchronized
        Assert.Equal("+963933333333", ownerUser.PhoneNumber);
        usersMock.Verify(x => x.UpdateAsync(ownerUser), Times.Once);

        // Verify caches were invalidated
        Assert.False(cache.TryGetValue("RestaurantCategoriesCustomerCache", out _));
        Assert.False(cache.TryGetValue("GetValidMerchants", out _));
    }
}
