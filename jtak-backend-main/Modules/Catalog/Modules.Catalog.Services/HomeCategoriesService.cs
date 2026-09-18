using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
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
        private readonly IGenericSettingService _genericSetting;

        public HomeCategoriesService(IProductCategoryService categoryService,
                                     IProductService productService,
                                     IMerchantService merchantService,
                                     IGenericSettingService genericSetting)
        {
            _categoryService = categoryService;
            _productService = productService;
            _merchantService = merchantService;
            _genericSetting = genericSetting;
        }

        public async Task<HomeCategoriesConfig> GetConfig() =>
            await _genericSetting.GetValue<HomeCategoriesConfig>(HomeCategoriesConfig.SettingKey)
                ?? new HomeCategoriesConfig();

        public async Task SaveConfig(HomeCategoriesConfig config)
        {
            config ??= new HomeCategoriesConfig();
            config.Tiles ??= new List<HomeCategoryTile>();

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

            // Until an administrator curates the grid, fall back to the active
            // root categories. That keeps Home populated on a fresh install and
            // gives the dashboard a real starting arrangement to edit, instead
            // of an empty screen the admin has to build from nothing.
            if (!configured.Any())
                configured = await BuildDefaultTiles();

            var tiles = configured
                .Where(x => !activeOnly || x.Active)
                .OrderBy(x => x.Order)
                .ToArray();

            if (!tiles.Any())
                return Array.Empty<HomeCategoryTileDto>();

            var categories = await _categoryService.Queryable().AsNoTracking()
                                                   .Where(x => x.DeletionDate == null && x.Active)
                                                   .Select(x => new { x.Id, x.Title, x.Icon, x.ParentId })
                                                   .ToDictionaryAsync(x => x.Id);

            var merchants = await _merchantService.Queryable().AsNoTracking()
                                                  .Where(x => x.DeletionDate == null && x.Active)
                                                  .Select(x => new { x.Id, x.Title, x.Photo, x.MerchantKind })
                                                  .ToDictionaryAsync(x => x.Id);

            var availableOffers = await _productService.Queryable().AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active &&
                            x.ProductCategoryId.HasValue &&
                            x.ProductCategory.Active)
                .SelectMany(x => x.MerchantProducts
                    .Where(mp => (mp.MerchantPrice > 0 ||
                                  (mp.PriceUsd.HasValue && mp.PriceUsd.Value > 0)) &&
                                 mp.Merchant.DeletionDate == null &&
                                 mp.Merchant.Active)
                    .Select(mp => new
                    {
                        ProductId = x.Id,
                        CategoryId = x.ProductCategoryId.Value,
                        mp.MerchantId
                    }))
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
                    MerchantKind = tile.MerchantKind,
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
                            if (string.IsNullOrWhiteSpace(dto.Title))
                                dto.Title = category.Title;
                            if (string.IsNullOrWhiteSpace(dto.ImageUrl))
                                dto.ImageUrl = category.Icon;

                            var categoryIds = GetCategoryTreeIds(
                                tile.ProductCategoryId.Value,
                                categoryParents);
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
                            var merchantIds = merchants.Values
                                .Where(x => x.MerchantKind == tile.MerchantKind.Value)
                                .Select(x => x.Id)
                                .ToHashSet();
                            dto.AvailableMerchantCount = merchantIds.Count;
                            dto.AvailableProductCount = availableOffers
                                .Where(x => merchantIds.Contains(x.MerchantId))
                                .Select(x => x.ProductId)
                                .Distinct()
                                .Count();
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
