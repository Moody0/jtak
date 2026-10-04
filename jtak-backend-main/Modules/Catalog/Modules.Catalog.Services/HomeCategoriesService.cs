using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using Solf.Base;
using URF.Core.Abstractions.Trackable;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Catalog.Services
{
    public interface IHomeCategoriesService
    {
        Task<HomeCategoriesConfig> GetConfig();
        Task SaveConfig(HomeCategoriesConfig config);
        Task<HomeCategoryTileDto[]> GetTiles(bool activeOnly);
    }

    /// <summary>
    /// Owns the Home "shop by category" grid. Every tile carries an explicit
    /// destination chosen by the administrator, which is what lets the apps
    /// route without pattern matching on category titles.
    /// </summary>
    public class HomeCategoriesService : IHomeCategoriesService
    {
        private readonly IProductCategoryService _categoryService;
        private readonly IProductService _productService;
        private readonly IMerchantService _merchantService;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepository;
        private readonly IGenericSettingService _genericSetting;

        public HomeCategoriesService(IProductCategoryService categoryService,
                                     IProductService productService,
                                     IMerchantService merchantService,
                                     ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepository,
                                     IGenericSettingService genericSetting)
        {
            _categoryService = categoryService;
            _productService = productService;
            _merchantService = merchantService;
            _merchantProductRepository = merchantProductRepository;
            _genericSetting = genericSetting;
        }

        public async Task<HomeCategoriesConfig> GetConfig()
        {
            var config = await _genericSetting.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey);
            var needsInitialization = config == null;
            if (config == null)
            {
                config = new HomeCategoriesConfig
                {
                    Tiles = await BuildDefaultTiles()
                };
            }
            config.Tiles ??= new List<HomeCategoryTile>();

            // Seed only a new configuration. Saved empty/disabled layouts must
            // stay exactly as the administrator configured them.
            if (needsInitialization)
            {
                if (!config.Tiles.Any(x => x.LinkType == HomeCategoryLinkType.ErrandRequests))
                {
                    foreach (var tile in config.Tiles)
                        tile.Order++;

                    config.Tiles.Add(new HomeCategoryTile
                    {
                        Id = "errand-requests",
                        Title = "طلبات",
                        TitleEn = "Requests",
                        Order = 0,
                        Active = true,
                        LinkType = HomeCategoryLinkType.ErrandRequests
                    });
                }

                config.ErrandRequestsTileInitialized = true;
                await SaveConfig(config);
            }

            return config;
        }

        public async Task SaveConfig(HomeCategoriesConfig config)
        {
            config ??= new HomeCategoriesConfig();
            config.Tiles ??= new List<HomeCategoryTile>();
            config.ErrandRequestsTileInitialized = true;

            // Give every tile a stable id and a gap-free order so the apps and
            // the dashboard always agree on the sequence.
            var order = 0;
            foreach (var tile in config.Tiles.OrderBy(x => x.Order).ToArray())
            {
                if (string.IsNullOrWhiteSpace(tile.Id))
                    tile.Id = Guid.NewGuid().ToString("N");
                tile.Order = order++;
            }
            config.Tiles = config.Tiles.OrderBy(x => x.Order).ToList();

            await _genericSetting.SetValue(HomeCategoriesConfig.SettingKey, config);
        }

        /// <summary>
        /// The arrangement used before anyone has configured one: every active
        /// root category, in catalog order, each opening its own category.
        /// </summary>
        private async Task<List<HomeCategoryTile>> BuildDefaultTiles()
        {
            var roots = await _categoryService.Queryable().AsNoTracking()
                                              .Where(x => x.DeletionDate == null && x.Active && x.ParentId == null)
                                              .OrderBy(x => x.Order)
                                              .ThenBy(x => x.Id)
                                              .Select(x => new { x.Id, x.Title, x.Icon })
                                              .ToArrayAsync();

            return roots.Select((x, index) => new HomeCategoryTile
            {
                Id = $"category-{x.Id}",
                Title = x.Title,
                ImageUrl = x.Icon,
                Order = index,
                Active = true,
                LinkType = HomeCategoryLinkType.ProductCategory,
                ProductCategoryId = x.Id
            }).ToList();
        }

        /// <summary>
        /// Resolves the configured tiles against the live catalog. A tile whose
        /// target has been deleted or deactivated is reported as broken rather
        /// than dropped silently, so the dashboard can show why it is missing
        /// from the app.
        /// </summary>
        public async Task<HomeCategoryTileDto[]> GetTiles(bool activeOnly)
        {
            var config = await GetConfig();
            var configured = config.Tiles ?? new List<HomeCategoryTile>();

            var tiles = configured
                .Where(x => !activeOnly || x.Active)
                .OrderBy(x => x.Order)
                .ToArray();

            if (!tiles.Any())
                return Array.Empty<HomeCategoryTileDto>();

            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            var categories = await _categoryService.Queryable().AsNoTracking()
                                                   .Where(x => visibleCategoryIds.Contains(x.Id))
                                                   .Select(x => new { x.Id, x.Title, x.Icon, x.ParentId })
                                                   .ToDictionaryAsync(x => x.Id);

            var merchants = await _merchantService.Queryable().AsNoTracking()
                                                  .Where(x => x.DeletionDate == null && x.Active)
                                                  .Select(x => new { x.Id, x.Title, x.Photo, x.MerchantKind })
                                                  .ToDictionaryAsync(x => x.Id);

            // Query the join entity directly. The previous Product.SelectMany
            // shape produced CROSS APPLY SQL on the production provider and
            // caused /Customer/Home to return HTTP 500, which also prevented
            // the app from receiving its banners.
            var availableOffers = await _merchantProductRepository.Queryable().AsNoTracking()
                .Where(mp => mp.Product.DeletionDate == null &&
                             mp.Product.Active &&
                             mp.Product.ProductCategoryId.HasValue &&
                             visibleCategoryIds.Contains(mp.Product.ProductCategoryId.Value) &&
                             // MerchantPrice is the persisted customer-facing
                             // price and exists on older production schemas as
                             // well. Do not make the home-categories endpoint
                             // fail merely because the optional PriceUsd
                             // migration has not been applied yet.
                             mp.MerchantPrice > 0 &&
                             mp.Merchant.DeletionDate == null &&
                             mp.Merchant.Active)
                .Select(mp => new
                {
                    ProductId = mp.ProductId,
                    CategoryId = mp.Product.ProductCategoryId.Value,
                    mp.MerchantId
                })
                .ToArrayAsync();

            var categoryParents = categories.ToDictionary(x => x.Key, x => x.Value.ParentId);

            var resolved = new List<HomeCategoryTileDto>();
            foreach (var tile in tiles)
            {
                var dto = new HomeCategoryTileDto
                {
                    Id = tile.Id,
                    Title = tile.Title,
                    TitleEn = tile.TitleEn,
                    ImageUrl = tile.ImageUrl,
                    Order = tile.Order,
                    LinkType = tile.LinkType,
                    ProductCategoryId = tile.ProductCategoryId,
                    SecondaryProductCategoryId = tile.SecondaryProductCategoryId,
                    MerchantKind = tile.MerchantKind,
                    RestaurantCategoryId = tile.RestaurantCategoryId,
                    MerchantId = tile.MerchantId,
                    SearchTerm = tile.SearchTerm
                };

                switch (tile.LinkType)
                {
                    case HomeCategoryLinkType.ProductCategory:
                        if (tile.ProductCategoryId.HasValue &&
                            categories.TryGetValue(tile.ProductCategoryId.Value, out var category))
                        {
                            dto.TargetLabel = category.Title;
                            dto.TargetCategoryTitle = category.Title;

                            var categoryIds = GetCategoryTreeIds(
                                tile.ProductCategoryId.Value,
                                categoryParents);

                            if (tile.SecondaryProductCategoryId.HasValue &&
                                categories.TryGetValue(tile.SecondaryProductCategoryId.Value, out var secCategory))
                            {
                                dto.SecondaryTargetCategoryTitle = secCategory.Title;
                                dto.TargetLabel = $"{category.Title} + {secCategory.Title}";
                                categoryIds.UnionWith(GetCategoryTreeIds(
                                    tile.SecondaryProductCategoryId.Value,
                                    categoryParents));
                            }

                            if (string.IsNullOrWhiteSpace(dto.Title))
                                dto.Title = category.Title;
                            if (string.IsNullOrWhiteSpace(dto.ImageUrl))
                                dto.ImageUrl = category.Icon;

                            var matchingOffers = availableOffers
                                .Where(x => categoryIds.Contains(x.CategoryId))
                                .ToArray();
                            dto.AvailableProductCount = matchingOffers
                                .Select(x => x.ProductId)
                                .Distinct()
                                .Count();
                            dto.AvailableMerchantCount = matchingOffers
                                .Select(x => x.MerchantId)
                                .Distinct()
                                .Count();
                            dto.HasAvailableContent = dto.AvailableProductCount > 0 &&
                                                      dto.AvailableMerchantCount > 0;
                            if (!dto.HasAvailableContent)
                                dto.AvailabilityMessage = "لا توجد منتجات مسعّرة لدى متجر نشط في هذا القسم حالياً";
                        }
                        else
                        {
                            dto.TargetExists = false;
                            dto.HasAvailableContent = false;
                        }
                        break;

                    case HomeCategoryLinkType.Merchant:
                        if (tile.MerchantId.HasValue &&
                            merchants.TryGetValue(tile.MerchantId.Value, out var merchant))
                        {
                            dto.MerchantKind = merchant.MerchantKind;
                            dto.TargetLabel = merchant.Title;
                            if (string.IsNullOrWhiteSpace(dto.Title))
                                dto.Title = merchant.Title;
                            if (string.IsNullOrWhiteSpace(dto.ImageUrl))
                                dto.ImageUrl = merchant.Photo;
                            dto.AvailableMerchantCount = 1;
                            dto.AvailableProductCount = availableOffers
                                .Where(x => x.MerchantId == tile.MerchantId.Value)
                                .Select(x => x.ProductId)
                                .Distinct()
                                .Count();
                            dto.HasAvailableContent = true;
                        }
                        else
                        {
                            dto.TargetExists = false;
                            dto.HasAvailableContent = false;
                        }
                        break;

                    case HomeCategoryLinkType.MerchantKind:
                        if (tile.MerchantKind.HasValue)
                        {
                            dto.TargetLabel = tile.MerchantKind.Value.ToString();
                            dto.AvailableMerchantCount = merchants.Values
                                .Count(x => x.MerchantKind == tile.MerchantKind.Value);
                            dto.HasAvailableContent = dto.AvailableMerchantCount > 0;
                            if (!dto.HasAvailableContent)
                                dto.AvailabilityMessage = "لا يوجد متجر نشط من هذا النوع حالياً";
                        }
                        else
                        {
                            dto.TargetExists = false;
                            dto.HasAvailableContent = false;
                        }
                        break;

                    case HomeCategoryLinkType.Search:
                        if (!string.IsNullOrWhiteSpace(tile.SearchTerm))
                        {
                            dto.TargetLabel = tile.SearchTerm;
                            dto.HasAvailableContent = merchants.Count > 0;
                            dto.AvailableMerchantCount = merchants.Count;
                            if (!dto.HasAvailableContent)
                                dto.AvailabilityMessage = "لا توجد متاجر نشطة للبحث حالياً";
                        }
                        else
                        {
                            dto.TargetExists = false;
                            dto.HasAvailableContent = false;
                        }
                        break;

                    case HomeCategoryLinkType.ErrandRequests:
                        dto.TargetLabel = "طلبات";
                        dto.HasAvailableContent = true;
                        break;

                    case HomeCategoryLinkType.MerchantCategory:
                        if (tile.MerchantId.HasValue &&
                            tile.ProductCategoryId.HasValue &&
                            merchants.TryGetValue(tile.MerchantId.Value, out var mCategoryMerchant) &&
                            categories.TryGetValue(tile.ProductCategoryId.Value, out var mCategoryCategory))
                        {
                            dto.MerchantKind = mCategoryMerchant.MerchantKind;
                            dto.TargetLabel = $"{mCategoryMerchant.Title} - {mCategoryCategory.Title}";
                            dto.TargetCategoryTitle = mCategoryCategory.Title;
                            if (string.IsNullOrWhiteSpace(dto.Title))
                                dto.Title = mCategoryCategory.Title;
                            if (string.IsNullOrWhiteSpace(dto.ImageUrl))
                                dto.ImageUrl = !string.IsNullOrWhiteSpace(mCategoryCategory.Icon)
                                    ? mCategoryCategory.Icon
                                    : mCategoryMerchant.Photo;

                            var catIds = GetCategoryTreeIds(tile.ProductCategoryId.Value, categoryParents);
                            var matchOffers = availableOffers
                                .Where(x => x.MerchantId == tile.MerchantId.Value && catIds.Contains(x.CategoryId))
                                .ToArray();

                            dto.AvailableMerchantCount = 1;
                            dto.AvailableProductCount = matchOffers.Select(x => x.ProductId).Distinct().Count();
                            dto.HasAvailableContent = dto.AvailableProductCount > 0;
                            if (!dto.HasAvailableContent)
                                dto.AvailabilityMessage = $"لا توجد منتجات مسعّرة لهذا القسم لدى متجر \"{mCategoryMerchant.Title}\" حالياً";
                        }
                        else
                        {
                            dto.TargetExists = false;
                            dto.HasAvailableContent = false;
                        }
                        break;

                    default:
                        dto.TargetExists = false;
                        dto.HasAvailableContent = false;
                        break;
                }

                // A tile with no usable title would render as a blank square.
                if (string.IsNullOrWhiteSpace(dto.Title))
                {
                    dto.TargetExists = false;
                    dto.HasAvailableContent = false;
                }

                if (!dto.TargetExists && string.IsNullOrWhiteSpace(dto.AvailabilityMessage))
                    dto.AvailabilityMessage = "الوجهة المحفوظة لم تعد موجودة أو مفعّلة";

                resolved.Add(dto);
            }

            return resolved.ToArray();
        }

        private static HashSet<int> GetCategoryTreeIds(
            int rootId,
            IReadOnlyDictionary<int, int?> parentByCategoryId)
        {
            var result = new HashSet<int> { rootId };
            var added = true;
            while (added)
            {
                added = false;
                foreach (var category in parentByCategoryId)
                {
                    if (category.Value.HasValue &&
                        result.Contains(category.Value.Value) &&
                        result.Add(category.Key))
                    {
                        added = true;
                    }
                }
            }

            return result;
        }
    }
}
