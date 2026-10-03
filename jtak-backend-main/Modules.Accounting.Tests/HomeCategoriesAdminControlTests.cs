using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
using App.Shared.Entities.Enums;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Moq;
using URF.Core.Abstractions.Trackable;

namespace Modules.Accounting.Tests;

public class HomeCategoriesAdminControlTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task SavedEmptyLayoutDoesNotReseedTiles(bool initialized)
    {
        var config = new HomeCategoriesConfig { ErrandRequestsTileInitialized = initialized };
        var settings = new Mock<IGenericSettingService>(MockBehavior.Strict);
        settings.Setup(x => x.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey, null))
            .ReturnsAsync(config);
        var categories = new Mock<IProductCategoryService>(MockBehavior.Strict);
        var service = CreateService(settings, categories);

        Assert.Same(config, await service.GetConfig());
        Assert.Empty(await service.GetTiles(activeOnly: true));
        Assert.Empty(await service.GetTiles(activeOnly: false));
        categories.VerifyNoOtherCalls();
        settings.Verify(x => x.SetValue(It.IsAny<string>(), It.IsAny<HomeCategoriesConfig>(), null), Times.Never);
    }

    [Fact]
    public async Task SavingKeepsMerchantTypesCustomNamesImagesAndVisibility()
    {
        var config = new HomeCategoriesConfig
        {
            Enabled = false,
            MaxItems = 0,
            Tiles = new List<HomeCategoryTile>
            {
                new() { Title = "المتاجر المتنوعة", ImageUrl = "other.webp", Order = 20,
                    Active = false, LinkType = HomeCategoryLinkType.MerchantKind, MerchantKind = MerchantKind.Store },
                new() { Title = "الصحة", ImageUrl = "health.webp", Order = 10,
                    Active = true, LinkType = HomeCategoryLinkType.MerchantKind, MerchantKind = MerchantKind.Pharmacy }
            }
        };
        var settings = new Mock<IGenericSettingService>();
        settings.Setup(x => x.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey, null)).ReturnsAsync(config);
        var service = CreateService(settings, new Mock<IProductCategoryService>());

        await service.SaveConfig(config);
        var saved = await service.GetConfig();
        Assert.False(saved.Enabled);
        Assert.Equal(0, saved.MaxItems);
        Assert.Collection(saved.Tiles,
            tile => { Assert.Equal("الصحة", tile.Title); Assert.Equal("health.webp", tile.ImageUrl);
                Assert.Equal(MerchantKind.Pharmacy, tile.MerchantKind); Assert.True(tile.Active); Assert.Equal(0, tile.Order); },
            tile => { Assert.Equal("المتاجر المتنوعة", tile.Title); Assert.Equal("other.webp", tile.ImageUrl);
                Assert.Equal(MerchantKind.Store, tile.MerchantKind); Assert.False(tile.Active); Assert.Equal(1, tile.Order); });
        settings.Verify(x => x.SetValue(HomeCategoriesConfig.SettingKey, config, null), Times.Once);
    }

    private static HomeCategoriesService CreateService(Mock<IGenericSettingService> settings,
        Mock<IProductCategoryService> categories) => new(categories.Object,
            Mock.Of<IProductService>(), Mock.Of<IMerchantService>(),
            Mock.Of<ITrackableRepository<MerchantProduct, CatalogDbContext>>(), settings.Object);
}
