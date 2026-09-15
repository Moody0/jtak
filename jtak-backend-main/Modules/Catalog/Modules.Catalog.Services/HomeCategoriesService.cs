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
        private readonly IMerchantService _merchantService;
        private readonly IGenericSettingService _genericSetting;

        public HomeCategoriesService(IProductCategoryService categoryService,
                                     IMerchantService merchantService,
                                     IGenericSettingService genericSetting)
        {
            _categoryService = categoryService;
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
                                                   .Select(x => new { x.Id, x.Title, x.Icon })
                                                   .ToDictionaryAsync(x => x.Id);

            var merchants = await _merchantService.Queryable().AsNoTracking()
                                                  .Where(x => x.DeletionDate == null && x.Active)
                                                  .Select(x => new { x.Id, x.Title, x.Photo })
                                                  .ToDictionaryAsync(x => x.Id);

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
                        }
                        else dto.TargetExists = false;
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
                        }
                        else dto.TargetExists = false;
                        break;

                    case HomeCategoryLinkType.MerchantKind:
                        if (tile.MerchantKind.HasValue)
                            dto.TargetLabel = tile.MerchantKind.Value.ToString();
                        else dto.TargetExists = false;
                        break;

                    case HomeCategoryLinkType.Search:
                        if (!string.IsNullOrWhiteSpace(tile.SearchTerm))
                            dto.TargetLabel = tile.SearchTerm;
                        else dto.TargetExists = false;
                        break;

                    default:
                        dto.TargetExists = false;
                        break;
                }

                // A tile with no usable title would render as a blank square.
                if (string.IsNullOrWhiteSpace(dto.Title))
                    dto.TargetExists = false;

                resolved.Add(dto);
            }

            return resolved.ToArray();
        }
    }
}
