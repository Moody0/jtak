using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class PopularProductsController : SolApiController
    {
        private const string SettingKey = "PopularProductsConfig";
        private const string CacheKey = "PopularProductsCache";

        private readonly IProductService _productService;
        private readonly IMerchantService _merchantService;
        private readonly IProductCategoryService _categoryService;
        private readonly IGenericSettingService _genericSetting;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IOrderDetailService _orderDetailsService;
        private readonly IMemoryCache _cache;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public PopularProductsController(
            IProductService productService,
            IMerchantService merchantService,
            IProductCategoryService categoryService,
            IGenericSettingService genericSetting,
            ICatalogUnitOfWork uow,
            IMemoryCache cache,
            IMapper mapper,
            ILogger<PopularProductsController> logger,
            IOrderDetailService orderDetailsService = null)
        {
            _productService = productService;
            _merchantService = merchantService;
            _categoryService = categoryService;
            _genericSetting = genericSetting;
            _uow = uow;
            _cache = cache;
            _mapper = mapper;
            _logger = logger;
            _orderDetailsService = orderDetailsService;
        }

        /// <summary>
        /// Admin: Get full Popular Products Section configuration with enriched item details
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<AdminPopularSectionResponse>> GetConfig()
        {
            var config = await GetOrInitConfigAsync();
            var response = new AdminPopularSectionResponse
            {
                Mode = config.Mode ?? "Hybrid",
                SectionTitle = config.SectionTitle ?? "الأكثر طلباً",
                SectionTitleEn = config.SectionTitleEn ?? "Most Popular",
                MaxItems = config.MaxItems > 0 ? config.MaxItems : 15,
                Enabled = config.Enabled,
                Items = new List<AdminPopularProductItemDto>()
            };

            var productIds = config.Items?.Select(x => x.ProductId).Distinct().ToList() ?? new List<int>();
            if (!productIds.Any())
            {
                return response;
            }

            var products = await _productService.Queryable()
                .AsNoTracking()
                .Include(x => x.ProductCategory)
                .Include(x => x.MerchantProducts)
                .Where(x => productIds.Contains(x.Id))
                .ToDictionaryAsync(x => x.Id, x => x);

            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null)
                .ToDictionaryAsync(x => x.Id, x => x);

            // Fetch order counts
            var orderCounts = new Dictionary<int, int>();
            if (_orderDetailsService != null)
            {
                try
                {
                    var stats = await _orderDetailsService.Queryable()
                        .AsNoTracking()
                        .Where(x => productIds.Contains(x.ProductId))
                        .GroupBy(x => x.ProductId)
                        .Select(g => new { ProductId = g.Key, Count = g.Sum(x => x.Quantity) })
                        .ToListAsync();

                    foreach (var s in stats)
                    {
                        orderCounts[s.ProductId] = s.Count;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to query orderDetailsService stats");
                }
            }

            var orderedConfigItems = config.Items.OrderBy(x => x.Order).ToList();
            foreach (var itemCfg in orderedConfigItems)
            {
                if (!products.TryGetValue(itemCfg.ProductId, out var product))
                {
                    continue;
                }

                MerchantProductDto mp = null;
                try
                {
                    mp = await _merchantService.GetBestProductPrice(product.Id, null);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to resolve best price for popular product {ProductId}", product.Id);
                }
                var fallbackMp = product.MerchantProducts?
                        .Where(x => merchants.ContainsKey(x.MerchantId) && x.MerchantPrice > 0)
                        .OrderBy(x => x.MerchantPrice)
                        .FirstOrDefault();
                if (mp != null && !merchants.ContainsKey(mp.MerchantId)) mp = null;
                var mid = mp?.MerchantId ?? fallbackMp?.MerchantId ?? 0;
                merchants.TryGetValue(mid, out var merchant);

                decimal fallbackAdditional = fallbackMp == null ? 0m : fallbackMp.MerchantPrice * fallbackMp.AdditionalProfitPercent / 100m;
                decimal finalPrice = mp?.FinalPrice ?? (fallbackMp == null ? 0m : fallbackMp.MerchantPrice + fallbackAdditional);
                decimal price = mp?.Price ?? (fallbackMp == null ? 0m : finalPrice + fallbackMp.Discount);
                if (finalPrice <= 0 && fallbackMp != null)
                {
                    if (fallbackMp.MerchantPrice > 0)
                    {
                        price = fallbackMp.MerchantPrice;
                        finalPrice = fallbackMp.MerchantPrice;
                    }
                }

                orderCounts.TryGetValue(product.Id, out var realCount);

                response.Items.Add(new AdminPopularProductItemDto
                {
                    ProductId = product.Id,
                    Title = string.IsNullOrWhiteSpace(itemCfg.CustomTitle) ? product.Title : itemCfg.CustomTitle,
                    Description = product.Description,
                    Photos = product.Photos,
                    Unit = product.Unit,
                    Price = price,
                    FinalPrice = finalPrice,
                    CategoryId = product.ProductCategoryId ?? 0,
                    CategoryTitle = product.ProductCategory?.Title ?? "",
                    MerchantId = mid,
                    MerchantTitle = merchant?.Title ?? "متجر جيتك",
                    MerchantLogo = merchant?.Photo ?? "",
                    Order = itemCfg.Order,
                    Active = itemCfg.Active,
                    ProductActive = product.Active,
                    CustomBadge = itemCfg.CustomBadge ?? "الأكثر طلباً",
                    CustomTitle = itemCfg.CustomTitle,
                    RealOrdersCount = realCount
                });
            }

            return response;
        }

        /// <summary>
        /// Admin: Save full configuration and reorder items
        /// </summary>
        [HttpPut]
        public async Task<ActionResult<bool>> SaveConfig([FromBody] PopularSectionConfig config)
        {
            if (config == null) return BadRequest("Config cannot be null");

            config = await NormalizeConfigAsync(config);

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            _logger.LogInformation("Updated PopularProductsConfig successfully with {0} items", config.Items.Count);
            return true;
        }

        /// <summary>
        /// Admin: Add a product to the popular items list
        /// </summary>
        [HttpPost]
        [Route("AddItem")]
        public async Task<ActionResult<bool>> AddItem([FromBody] PopularProductItemConfig item)
        {
            if (item == null || item.ProductId <= 0) return BadRequest("Invalid product");

            var product = await _productService.Queryable()
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == item.ProductId && x.DeletionDate == null);
            if (product == null) return NotFound("Product not found");

            var config = await GetOrInitConfigAsync();
            var existing = config.Items.FirstOrDefault(x => x.ProductId == item.ProductId);
            if (existing != null)
            {
                existing.Active = true;
                if (!string.IsNullOrEmpty(item.CustomBadge)) existing.CustomBadge = item.CustomBadge;
                if (!string.IsNullOrEmpty(item.CustomTitle)) existing.CustomTitle = item.CustomTitle;
            }
            else
            {
                var newOrder = Math.Clamp(item.Order > 0 ? item.Order : (config.Items.Count + 1), 1, config.Items.Count + 1);
                config.Items.Insert(newOrder - 1, new PopularProductItemConfig
                {
                    ProductId = item.ProductId,
                    Order = newOrder,
                    Active = true,
                    CustomBadge = item.CustomBadge ?? "الأكثر طلباً",
                    CustomTitle = item.CustomTitle
                });
            }

            // Normalize order
            for (int i = 0; i < config.Items.Count; i++)
            {
                config.Items[i].Order = i + 1;
            }

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Remove a product from the popular list
        /// </summary>
        [HttpDelete]
        [Route("{productId}")]
        public async Task<ActionResult<bool>> RemoveItem(int productId)
        {
            var config = await GetOrInitConfigAsync();
            var count = config.Items.RemoveAll(x => x.ProductId == productId);
            if (count > 0)
            {
                for (int i = 0; i < config.Items.Count; i++)
                {
                    config.Items[i].Order = i + 1;
                }

                try
                {
                    await _genericSetting.SetValue(SettingKey, config, null);
                    _cache.Remove(CacheKey);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to persist initial popular products config");
                }
            }

            return true;
        }

        /// <summary>
        /// Admin: Quick 1-click toggle active / in popular list
        /// </summary>
        [HttpPost]
        [Route("Toggle/{productId}")]
        public async Task<ActionResult<bool>> Toggle(int productId, [FromQuery] bool? active = null)
        {
            var config = await GetOrInitConfigAsync();
            var existing = config.Items.FirstOrDefault(x => x.ProductId == productId);

            if (existing != null)
            {
                existing.Active = active ?? !existing.Active;
            }
            else
            {
                var product = await _productService.Queryable()
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == productId && x.DeletionDate == null);
                if (product == null) return NotFound("Product not found");

                config.Items.Add(new PopularProductItemConfig
                {
                    ProductId = productId,
                    Order = config.Items.Count + 1,
                    Active = active ?? true,
                    CustomBadge = "الأكثر طلباً"
                });
            }

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Reorder popular products
        /// </summary>
        [HttpPost]
        [Route("Reorder")]
        public async Task<ActionResult<bool>> Reorder([FromBody] int[] productIds)
        {
            if (productIds == null || !productIds.Any()) return BadRequest("Product IDs required");

            var config = await GetOrInitConfigAsync();
            var newItems = new List<PopularProductItemConfig>();

            int order = 1;
            foreach (var pid in productIds)
            {
                var existing = config.Items.FirstOrDefault(x => x.ProductId == pid);
                if (existing != null && !newItems.Any(x => x.ProductId == pid))
                {
                    existing.Order = order++;
                    newItems.Add(existing);
                }
            }

            // Include any remaining items that weren't in the productIds array
            foreach (var item in config.Items)
            {
                if (!newItems.Any(x => x.ProductId == item.ProductId))
                {
                    item.Order = order++;
                    newItems.Add(item);
                }
            }

            config.Items = newItems;
            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Search products to add to Popular Dishes
        /// </summary>
        [HttpGet]
        [Route("SearchProducts")]
        public async Task<ActionResult<SearchProductCandidateDto[]>> SearchProducts(
            [FromQuery] string q = null,
            [FromQuery] int? merchantId = null,
            [FromQuery] int take = 30)
        {
            if (take <= 0 || take > 100) take = 30;

            var config = await GetOrInitConfigAsync();
            var existingPopularIds = new HashSet<int>(config.Items.Select(x => x.ProductId));

            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active && (merchantId == null || x.Id == merchantId))
                .ToDictionaryAsync(x => x.Id, x => x);

            var query = _productService.Queryable()
                .AsNoTracking()
                .Include(x => x.ProductCategory)
                .Include(x => x.MerchantProducts)
                .Where(x => x.DeletionDate == null && x.Active);

            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim().ToLower();
                query = query.Where(x => x.Title.ToLower().Contains(term) ||
                                         (x.Description != null && x.Description.ToLower().Contains(term)) ||
                                         (x.ProductCategory != null && x.ProductCategory.Title.ToLower().Contains(term)));
            }

            if (merchantId.HasValue)
            {
                query = query.Where(x => x.MerchantProducts.Any(m => m.MerchantId == merchantId.Value));
            }

            var products = await query
                .OrderByDescending(x => x.IsFeatured)
                .ThenBy(x => x.Title)
                .Take(take)
                .ToListAsync();

            var result = new List<SearchProductCandidateDto>();
            foreach (var p in products)
            {
                var mp = p.MerchantProducts?
                    .Where(x => merchants.ContainsKey(x.MerchantId) && x.MerchantPrice > 0)
                    .OrderBy(x => x.MerchantPrice)
                    .FirstOrDefault();
                if (mp == null)
                {
                    continue;
                }

                var mid = mp.MerchantId;
                merchants.TryGetValue(mid, out var m);

                decimal price = mp.MerchantPrice;

                result.Add(new SearchProductCandidateDto
                {
                    Id = p.Id,
                    Title = p.Title,
                    Unit = p.Unit,
                    Photos = p.Photos,
                    Price = price,
                    CategoryId = p.ProductCategoryId ?? 0,
                    CategoryTitle = p.ProductCategory?.Title ?? "",
                    MerchantId = mid,
                    MerchantTitle = m?.Title ?? (mid > 0 ? $"Store #{mid}" : "غير محدد"),
                    Active = p.Active,
                    IsAlreadyInPopular = existingPopularIds.Contains(p.Id)
                });
            }

            return result.ToArray();
        }

        private async Task<PopularSectionConfig> GetOrInitConfigAsync()
        {
            var config = await _genericSetting.GetValue<PopularSectionConfig>(SettingKey, null);
            if (config == null || config.Items == null)
            {
                config = new PopularSectionConfig
                {
                    Mode = "Hybrid",
                    SectionTitle = "الأكثر طلباً",
                    SectionTitleEn = "Most Popular",
                    MaxItems = 15,
                    Enabled = true,
                    Items = new List<PopularProductItemConfig>()
                };

                // Seed with current featured products so the list starts populated
                try
                {
                    var featuredProds = await _productService.Queryable()
                        .AsNoTracking()
                        .Where(x => x.DeletionDate == null && x.Active && x.IsFeatured)
                        .OrderBy(x => x.Id)
                        .Take(15)
                        .Select(x => x.Id)
                        .ToListAsync();

                    int order = 1;
                    foreach (var pid in featuredProds)
                    {
                        config.Items.Add(new PopularProductItemConfig
                        {
                            ProductId = pid,
                            Order = order++,
                            Active = true,
                            CustomBadge = "الأكثر طلباً"
                        });
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to auto-seed initial popular products config");
                }

                // Persist the initial value so the next request sees the same configuration
                // instead of re-seeding the list on every cache miss.
                await _genericSetting.SetValue(SettingKey, config, null);
                _cache.Remove(CacheKey);
            }

            return await NormalizeConfigAsync(config, persist: false);
        }

        private async Task<PopularSectionConfig> NormalizeConfigAsync(PopularSectionConfig config, bool persist = false)
        {
            config ??= new PopularSectionConfig();
            config.Mode = config.Mode == "Manual" || config.Mode == "Auto" ? config.Mode : "Hybrid";
            config.SectionTitle = string.IsNullOrWhiteSpace(config.SectionTitle) ? "الأكثر طلباً" : config.SectionTitle.Trim();
            config.SectionTitleEn = string.IsNullOrWhiteSpace(config.SectionTitleEn) ? "Most Popular" : config.SectionTitleEn.Trim();
            config.MaxItems = Math.Clamp(config.MaxItems <= 0 ? 15 : config.MaxItems, 1, 100);

            var sourceItems = config.Items ?? new List<PopularProductItemConfig>();
            var candidateIds = sourceItems
                .Where(x => x != null && x.ProductId > 0)
                .Select(x => x.ProductId)
                .Distinct()
                .ToArray();
            var validIds = candidateIds.Length == 0
                ? new HashSet<int>()
                : (await _productService.Queryable()
                    .AsNoTracking()
                    .Where(x => candidateIds.Contains(x.Id) && x.DeletionDate == null)
                    .Select(x => x.Id)
                    .ToListAsync())
                    .ToHashSet();

            config.Items = sourceItems
                .Where(x => x != null && x.ProductId > 0 && validIds.Contains(x.ProductId))
                .OrderBy(x => x.Order <= 0 ? int.MaxValue : x.Order)
                .ThenBy(x => x.ProductId)
                .GroupBy(x => x.ProductId)
                .Select(g => g.First())
                .ToList();

            for (var i = 0; i < config.Items.Count; i++)
            {
                config.Items[i].Order = i + 1;
                config.Items[i].CustomBadge = string.IsNullOrWhiteSpace(config.Items[i].CustomBadge)
                    ? "الأكثر طلباً"
                    : config.Items[i].CustomBadge.Trim();
            }

            if (persist)
            {
                await _genericSetting.SetValue(SettingKey, config, null);
                _cache.Remove(CacheKey);
            }

            return config;
        }
    }
}
