using App.ApiModels;
using App.Shared.Services;
using Modules.Catalog.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Customer.Catalog
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [Route("api/v{version:apiVersion}/Customer/Catalog/RestaurantCategories")]
    [ApiVersion("1")]
    [AllowAnonymous]
    public class RestaurantCategoriesController : SolApiController
    {
        private const string SettingKey = "RestaurantCategoriesConfig";
        private const string CacheKey = "RestaurantCategoriesCustomerCache";

        private readonly IGenericSettingService _genericSetting;
        private readonly IMerchantService _merchantService;
        private readonly IMemoryCache _cache;
        private readonly ILogger<RestaurantCategoriesController> _logger;

        public RestaurantCategoriesController(
            IGenericSettingService genericSetting,
            IMerchantService merchantService,
            IMemoryCache cache,
            ILogger<RestaurantCategoriesController> logger)
        {
            _genericSetting = genericSetting;
            _merchantService = merchantService;
            _cache = cache;
            _logger = logger;
        }

        /// <summary>
        /// Customer: Get active Restaurant Categories and section title for the Restaurants page
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<CustomerRestaurantCategoriesResponse>> Get()
        {
            if (_cache.TryGetValue(CacheKey, out CustomerRestaurantCategoriesResponse cachedResponse) && cachedResponse != null)
            {
                return cachedResponse;
            }

            RestaurantCategoriesSectionConfig config = null;
            try
            {
                config = await _genericSetting.GetValue<RestaurantCategoriesSectionConfig>(SettingKey, null);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to fetch RestaurantCategoriesConfig for Customer");
            }

            // Fallback default list if no config found yet
            if (config == null)
            {
                config = new RestaurantCategoriesSectionConfig
                {
                    SectionTitle = "كل المطاعم",
                    SectionTitleEn = "All Restaurants",
                    Enabled = true,
                    Items = new List<RestaurantCategoryItem>
                    {
                        new RestaurantCategoryItem { Id = 1, Title = "شاورما", TitleEn = "Shawarma", Image = "assets/images/products/Arabic Chicken Shawarma Platter.webp", Order = 1, Active = true, FilterTag = "شاورما" },
                        new RestaurantCategoryItem { Id = 2, Title = "مشاوي", TitleEn = "Grills", Image = "assets/images/categories/meat_poultry.png", Order = 2, Active = true, FilterTag = "مشاوي" },
                        new RestaurantCategoryItem { Id = 3, Title = "فطور شعبي", TitleEn = "Traditional Breakfast", Image = "assets/images/categories/dish_syrian.png", Order = 3, Active = true, FilterTag = "فطور" },
                        new RestaurantCategoryItem { Id = 4, Title = "حلويات", TitleEn = "Sweets & Desserts", Image = "assets/images/products/Classic Roll.webp", Order = 4, Active = true, FilterTag = "حلويات" },
                        new RestaurantCategoryItem { Id = 5, Title = "البرجر", TitleEn = "Burgers", Image = "assets/images/products/Double Angus Smash Burger.webp", Order = 5, Active = true, FilterTag = "برجر" },
                        new RestaurantCategoryItem { Id = 6, Title = "مشروبات", TitleEn = "Drinks & Coffee", Image = "assets/images/products/Iced Spanish Latte.webp", Order = 6, Active = true, FilterTag = "مشروبات" },
                        new RestaurantCategoryItem { Id = 7, Title = "مخبوزات", TitleEn = "Bakery", Image = "assets/images/products/Minibon 9-Pack Box.webp", Order = 7, Active = true, FilterTag = "مخبوزات" }
                    }
                };
            }

            var response = new CustomerRestaurantCategoriesResponse
            {
                SectionTitle = config.SectionTitle ?? "كل المطاعم",
                SectionTitleEn = config.SectionTitleEn ?? "All Restaurants",
                HomeSectionTitle = config.HomeSectionTitle ?? "أنواع المطاعم",
                HomeSectionTitleEn = config.HomeSectionTitleEn ?? "Restaurant Types",
                Enabled = config.Enabled,
                ShowOnHome = config.ShowOnHome,
                Items = await ResolveItems(config)
            };

            _cache.Set(CacheKey, response, TimeSpan.FromMinutes(10));
            return response;
        }

        /// <summary>
        /// Attaches a live merchant count to every active entry and drops the
        /// ones nobody sells in. A category with no merchants behind it can only
        /// open an empty list, so showing it is a dead end for the customer.
        /// </summary>
        private async Task<List<RestaurantCategoryItem>> ResolveItems(RestaurantCategoriesSectionConfig config)
        {
            var items = config.Items?
                .Where(x => x.Active && !string.IsNullOrWhiteSpace(x.Title))
                .OrderBy(x => x.Order)
                .ToList() ?? new List<RestaurantCategoryItem>();

            if (!items.Any())
                return items;

            var categoryIds = items.Where(x => x.ProductCategoryId.HasValue)
                                   .Select(x => x.ProductCategoryId.Value)
                                   .Distinct()
                                   .ToArray();

            var counts = await _merchantService.GetMerchantCountsByCategory(categoryIds);

            foreach (var item in items)
            {
                item.MerchantCount = item.ProductCategoryId.HasValue &&
                                     counts.TryGetValue(item.ProductCategoryId.Value, out var count)
                    ? count
                    : 0;
            }

            // Entries not yet pointed at a category are kept rather than hidden:
            // their emptiness is unknown, not proven, and hiding them would make
            // the section vanish before anyone has had a chance to link them up.
            return items.Where(x => !x.ProductCategoryId.HasValue || x.MerchantCount > 0).ToList();
        }
    }
}
