using App.ApiModels;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin.Catalog
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class RestaurantCategoriesController : SolApiController
    {
        public const string SettingKey = "RestaurantCategoriesConfig";
        public const string CacheKey = "RestaurantCategoriesCache";
        public const string CustomerCacheKey = "RestaurantCategoriesCustomerCache";

        private readonly IGenericSettingService _genericSetting;
        private readonly IMerchantService _merchantService;
        private readonly IProductCategoryService _categoryService;
        private readonly IMemoryCache _cache;
        private readonly ILogger<RestaurantCategoriesController> _logger;

        public RestaurantCategoriesController(
            IGenericSettingService genericSetting,
            IMerchantService merchantService,
            IProductCategoryService categoryService,
            IMemoryCache cache,
            ILogger<RestaurantCategoriesController> logger)
        {
            _genericSetting = genericSetting;
            _merchantService = merchantService;
            _categoryService = categoryService;
            _cache = cache;
            _logger = logger;
        }

        /// <summary>
        /// Admin: Get full Restaurant Categories section configuration and items
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<AdminRestaurantCategoriesResponse>> GetConfig()
        {
            var config = await GetOrInitConfigAsync();
            var items = config.Items ?? new List<RestaurantCategoryItem>();

            // Every category that has at least one merchant behind it, so the
            // administrator picks from real options and can see at a glance
            // which entries would be hidden from customers.
            var categories = await _categoryService.Queryable().AsNoTracking()
                                                   .Where(x => x.DeletionDate == null && x.Active)
                                                   .OrderBy(x => x.Title)
                                                   .Select(x => new RestaurantCategoryTargetDto
                                                   {
                                                       Id = x.Id,
                                                       Title = x.Title,
                                                       ParentTitle = x.Parent.Title
                                                   })
                                                   .ToArrayAsync();

            var allCounts = await _merchantService.GetMerchantCountsByCategory(
                categories.Select(x => x.Id).ToArray());

            foreach (var category in categories)
            {
                category.MerchantCount = allCounts.TryGetValue(category.Id, out var n) ? n : 0;
            }

            foreach (var item in items)
            {
                item.MerchantCount = item.ProductCategoryId.HasValue &&
                                     allCounts.TryGetValue(item.ProductCategoryId.Value, out var count)
                    ? count
                    : 0;
            }

            return new AdminRestaurantCategoriesResponse
            {
                SectionTitle = config.SectionTitle ?? "كل المطاعم",
                SectionTitleEn = config.SectionTitleEn ?? "All Restaurants",
                HomeSectionTitle = config.HomeSectionTitle ?? "أصناف متنوعة",
                HomeSectionTitleEn = config.HomeSectionTitleEn ?? "Browse by kind",
                Enabled = config.Enabled,
                ShowOnHome = config.ShowOnHome,
                AvailableCategories = categories.OrderByDescending(x => x.MerchantCount)
                                                .ThenBy(x => x.Title)
                                                .ToList(),
                TotalCount = items.Count,
                ActiveCount = items.Count(x => x.Active),
                Items = items
            };
        }

        /// <summary>
        /// Admin: Save full configuration, section title, enabled status, and reordered items
        /// </summary>
        [HttpPut]
        public async Task<ActionResult<bool>> SaveConfig([FromBody] RestaurantCategoriesSectionConfig config)
        {
            if (config == null) return BadRequest("Config cannot be null");

            config = NormalizeConfig(config);

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);
            _cache.Remove(CustomerCacheKey);

            _logger.LogInformation("Updated RestaurantCategoriesConfig successfully with {0} items", config.Items.Count);
            return true;
        }

        /// <summary>
        /// Admin: Add a new category to the section
        /// </summary>
        [HttpPost]
        [Route("AddItem")]
        public async Task<ActionResult<RestaurantCategoryItem>> AddItem([FromBody] RestaurantCategoryItem item)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.Title))
                return BadRequest("Category title is required");

            var config = await GetOrInitConfigAsync();

            int nextId = config.Items.Any() ? config.Items.Max(x => x.Id) + 1 : 1;
            item.Id = nextId;
            item.Title = item.Title.Trim();
            item.TitleEn = item.TitleEn?.Trim() ?? string.Empty;
            item.FilterTag = string.IsNullOrWhiteSpace(item.FilterTag) ? item.Title : item.FilterTag.Trim();
            item.Image = item.Image?.Trim() ?? string.Empty;
            item.Order = item.Order > 0 ? item.Order : (config.Items.Count + 1);

            config.Items.Add(item);
            config = NormalizeConfig(config);

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);
            _cache.Remove(CustomerCacheKey);

            var added = config.Items.FirstOrDefault(x => x.Id == nextId) ?? item;
            return Ok(added);
        }

        /// <summary>
        /// Admin: Update an existing category
        /// </summary>
        [HttpPut]
        [Route("UpdateItem")]
        public async Task<ActionResult<bool>> UpdateItem([FromBody] RestaurantCategoryItem item)
        {
            if (item == null || item.Id <= 0)
                return BadRequest("Valid category ID is required");

            var config = await GetOrInitConfigAsync();
            var existing = config.Items.FirstOrDefault(x => x.Id == item.Id);
            if (existing == null)
                return NotFound("Category not found");

            if (!string.IsNullOrWhiteSpace(item.Title))
                existing.Title = item.Title.Trim();
            if (item.TitleEn != null)
                existing.TitleEn = item.TitleEn.Trim();
            if (item.Image != null)
                existing.Image = item.Image.Trim();
            if (item.FilterTag != null)
                existing.FilterTag = string.IsNullOrWhiteSpace(item.FilterTag) ? existing.Title : item.FilterTag.Trim();
            if (item.Order > 0)
                existing.Order = item.Order;
            existing.Active = item.Active;

            config = NormalizeConfig(config);
            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);
            _cache.Remove(CustomerCacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Remove a category from the section
        /// </summary>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> RemoveItem(int id)
        {
            var config = await GetOrInitConfigAsync();
            var removed = config.Items.RemoveAll(x => x.Id == id);
            if (removed > 0)
            {
                config = NormalizeConfig(config);
                await _genericSetting.SetValue(SettingKey, config, null);
                _cache.Remove(CacheKey);
                _cache.Remove(CustomerCacheKey);
            }
            return true;
        }

        /// <summary>
        /// Admin: Quick toggle category active status
        /// </summary>
        [HttpPost]
        [Route("Toggle/{id}")]
        public async Task<ActionResult<bool>> Toggle(int id, [FromQuery] bool? active = null)
        {
            var config = await GetOrInitConfigAsync();
            var existing = config.Items.FirstOrDefault(x => x.Id == id);
            if (existing == null)
                return NotFound("Category not found");

            existing.Active = active ?? !existing.Active;

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);
            _cache.Remove(CustomerCacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Reorder categories by IDs sequence
        /// </summary>
        [HttpPost]
        [Route("Reorder")]
        public async Task<ActionResult<bool>> Reorder([FromBody] int[] categoryIds)
        {
            if (categoryIds == null || !categoryIds.Any())
                return BadRequest("Category IDs required");

            var config = await GetOrInitConfigAsync();
            var newItems = new List<RestaurantCategoryItem>();

            int order = 1;
            foreach (var id in categoryIds)
            {
                var existing = config.Items.FirstOrDefault(x => x.Id == id);
                if (existing != null && !newItems.Any(x => x.Id == id))
                {
                    existing.Order = order++;
                    newItems.Add(existing);
                }
            }

            foreach (var item in config.Items)
            {
                if (!newItems.Any(x => x.Id == item.Id))
                {
                    item.Order = order++;
                    newItems.Add(item);
                }
            }

            config.Items = newItems;
            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);
            _cache.Remove(CustomerCacheKey);

            return true;
        }

        private async Task<RestaurantCategoriesSectionConfig> GetOrInitConfigAsync()
        {
            var config = await _genericSetting.GetValue<RestaurantCategoriesSectionConfig>(SettingKey, null);
            if (config == null)
            {
                config = new RestaurantCategoriesSectionConfig
                {
                    SectionTitle = "كل المطاعم",
                    SectionTitleEn = "All Restaurants",
                    Enabled = true,
                    Items = new List<RestaurantCategoryItem>
                    {
                        new RestaurantCategoryItem
                        {
                            Id = 1,
                            Title = "شاورما",
                            TitleEn = "Shawarma",
                            Image = "assets/images/products/Arabic Chicken Shawarma Platter.webp",
                            Order = 1,
                            Active = true,
                            FilterTag = "شاورما"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 2,
                            Title = "مشاوي",
                            TitleEn = "Grills",
                            Image = "assets/images/categories/meat_poultry.png",
                            Order = 2,
                            Active = true,
                            FilterTag = "مشاوي"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 3,
                            Title = "فطور شعبي",
                            TitleEn = "Traditional Breakfast",
                            Image = "assets/images/categories/dish_syrian.png",
                            Order = 3,
                            Active = true,
                            FilterTag = "فطور"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 4,
                            Title = "حلويات",
                            TitleEn = "Sweets & Desserts",
                            Image = "assets/images/products/Classic Roll.webp",
                            Order = 4,
                            Active = true,
                            FilterTag = "حلويات"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 5,
                            Title = "البرجر",
                            TitleEn = "Burgers",
                            Image = "assets/images/products/Double Angus Smash Burger.webp",
                            Order = 5,
                            Active = true,
                            FilterTag = "برجر"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 6,
                            Title = "مشروبات",
                            TitleEn = "Drinks & Coffee",
                            Image = "assets/images/products/Iced Spanish Latte.webp",
                            Order = 6,
                            Active = true,
                            FilterTag = "مشروبات"
                        },
                        new RestaurantCategoryItem
                        {
                            Id = 7,
                            Title = "مخبوزات",
                            TitleEn = "Bakery",
                            Image = "assets/images/products/Minibon 9-Pack Box.webp",
                            Order = 7,
                            Active = true,
                            FilterTag = "مخبوزات"
                        }
                    }
                };

                try
                {
                    await _genericSetting.SetValue(SettingKey, config, null);
                    _cache.Remove(CacheKey);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to persist initial restaurant categories config");
                }
            }

            return NormalizeConfig(config);
        }

        private RestaurantCategoriesSectionConfig NormalizeConfig(RestaurantCategoriesSectionConfig config)
        {
            config ??= new RestaurantCategoriesSectionConfig();
            config.SectionTitle = string.IsNullOrWhiteSpace(config.SectionTitle) ? "كل المطاعم" : config.SectionTitle.Trim();
            config.SectionTitleEn = string.IsNullOrWhiteSpace(config.SectionTitleEn) ? "All Restaurants" : config.SectionTitleEn.Trim();
            config.HomeSectionTitle = string.IsNullOrWhiteSpace(config.HomeSectionTitle) ? "أصناف متنوعة" : config.HomeSectionTitle.Trim();
            config.HomeSectionTitleEn = string.IsNullOrWhiteSpace(config.HomeSectionTitleEn) ? "Browse by kind" : config.HomeSectionTitleEn.Trim();
            config.Items ??= new List<RestaurantCategoryItem>();

            config.Items = config.Items
                .Where(x => x != null && !string.IsNullOrWhiteSpace(x.Title))
                .OrderBy(x => x.Order <= 0 ? int.MaxValue : x.Order)
                .ThenBy(x => x.Id)
                .ToList();

            for (int i = 0; i < config.Items.Count; i++)
            {
                config.Items[i].Order = i + 1;
                config.Items[i].Title = config.Items[i].Title.Trim();
                if (string.IsNullOrWhiteSpace(config.Items[i].FilterTag))
                {
                    config.Items[i].FilterTag = config.Items[i].Title;
                }
            }

            return config;
        }
    }
}
