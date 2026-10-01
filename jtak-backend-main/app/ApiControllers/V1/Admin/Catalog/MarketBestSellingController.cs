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
    public class MarketBestSellingController : SolApiController
    {
        private const string SettingKey = "MarketBestSellingConfig";
        private const string CacheKey = "MarketBestSellingCache";

        private readonly IProductService _productService;
        private readonly IMerchantService _merchantService;
        private readonly IProductCategoryService _categoryService;
        private readonly IGenericSettingService _genericSetting;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IOrderDetailService _orderDetailsService;
        private readonly IMemoryCache _cache;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public MarketBestSellingController(
            IProductService productService,
            IMerchantService merchantService,
            IProductCategoryService categoryService,
            IGenericSettingService genericSetting,
            ICatalogUnitOfWork uow,
            IMemoryCache cache,
            IMapper mapper,
            ILogger<MarketBestSellingController> logger,
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
        /// Admin: Get full Market Best Selling Section configuration with enriched item details
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<AdminMarketBestSellingSectionResponse>> GetConfig()
        {
            var config = await GetOrInitConfigAsync();
            var response = new AdminMarketBestSellingSectionResponse
            {
                Mode = config.Mode ?? "Hybrid",
                SectionTitle = config.SectionTitle ?? "الأكثر مبيعًا",
                SectionTitleEn = config.SectionTitleEn ?? "Best Selling",
                MaxItems = config.MaxItems > 0 ? config.MaxItems : 10,
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
                .Where(x => x.DeletionDate == null && x.MerchantKind != MerchantKind.Restaurant)
                .ToDictionaryAsync(x => x.Id, x => x);

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
                    _logger.LogWarning(ex, "Failed to query orderDetailsService stats in MarketBestSellingController");
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
                    _logger.LogWarning(ex, "Failed to resolve best price for market product {ProductId}", product.Id);
                }

                var fallbackMp = product.MerchantProducts?
                        .Where(x => merchants.ContainsKey(x.MerchantId) && x.MerchantPrice > 0)
                        .OrderBy(x => x.MerchantPrice)
                        .FirstOrDefault();
                if (mp != null && !merchants.ContainsKey(mp.MerchantId)) mp = null;
                var mid = mp?.MerchantId ?? fallbackMp?.MerchantId ?? 0;
                merchants.TryGetValue(mid, out var merchant);

                var fallbackQuote = fallbackMp == null ? null : new MerchantProductDto
                {
                    MerchantPrice = fallbackMp.MerchantPrice,
                    ProfitOutOfMerchantPricePercent = fallbackMp.ProfitOutOfMerchantPricePercent,
                    Discount = fallbackMp.Discount
                };
                decimal finalPrice = mp?.FinalPrice ?? fallbackQuote?.FinalPrice ?? 0m;
                decimal price = mp?.Price ?? fallbackQuote?.Price ?? 0m;
                if (finalPrice <= 0 && fallbackMp != null && fallbackMp.MerchantPrice > 0)
                {
                    price = fallbackQuote?.Price ?? 0m;
                    finalPrice = fallbackQuote?.FinalPrice ?? 0m;
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
                    MerchantTitle = merchant?.Title ?? "سوبر ماركت جيتك",
                    MerchantLogo = merchant?.Photo ?? "",
                    Order = itemCfg.Order,
                    Active = itemCfg.Active,
                    ProductActive = product.Active,
                    CustomBadge = itemCfg.CustomBadge ?? "الأكثر مبيعًا",
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
        public async Task<ActionResult<bool>> SaveConfig([FromBody] MarketBestSellingSectionConfig config)
        {
            if (config == null) return BadRequest("Config cannot be null");

            config = await NormalizeConfigAsync(config);

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            _logger.LogInformation("Updated MarketBestSellingConfig successfully with {0} items", config.Items.Count);
            return true;
        }

        /// <summary>
        /// Admin: Add a product to the Market Best Selling list
        /// </summary>
        [HttpPost]
        [Route("AddItem")]
        public async Task<ActionResult<bool>> AddItem([FromBody] MarketBestSellingItemConfig item)
        {
            if (item == null || item.ProductId <= 0) return BadRequest("Invalid product");

            var product = await _productService.Queryable()
                .AsNoTracking()
                .Include(x => x.MerchantProducts)
                .FirstOrDefaultAsync(x => x.Id == item.ProductId && x.DeletionDate == null && x.Active);
            if (product == null) return NotFound("Product not found");
            var activeMarketMerchantIds = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind != MerchantKind.Restaurant)
                .Select(x => x.Id)
                .ToListAsync();
            if (product.MerchantProducts?.Any(x => x.MerchantPrice > 0 && activeMarketMerchantIds.Contains(x.MerchantId)) != true)
            {
                return BadRequest("Product is not available from an active market");
            }

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
                config.Items.Insert(newOrder - 1, new MarketBestSellingItemConfig
                {
                    ProductId = item.ProductId,
                    Order = newOrder,
                    Active = true,
                    CustomBadge = item.CustomBadge ?? "الأكثر مبيعًا",
                    CustomTitle = item.CustomTitle
                });
            }

            for (int i = 0; i < config.Items.Count; i++)
            {
                config.Items[i].Order = i + 1;
            }

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Remove a product from the Market Best Selling list
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
                    _logger.LogWarning(ex, "Failed to persist market best selling config on removal");
                }
            }

            return true;
        }

        /// <summary>
        /// Admin: Quick 1-click toggle active
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
                    .Include(x => x.MerchantProducts)
                    .FirstOrDefaultAsync(x => x.Id == productId && x.DeletionDate == null && x.Active);
                if (product == null) return NotFound("Product not found");

                var activeMarketMerchantIds = await _merchantService.Queryable()
                    .AsNoTracking()
                    .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind != MerchantKind.Restaurant)
                    .Select(x => x.Id)
                    .ToListAsync();
                if (product.MerchantProducts?.Any(x => x.MerchantPrice > 0 && activeMarketMerchantIds.Contains(x.MerchantId)) != true)
                {
                    return BadRequest("Product is not available from an active market");
                }

                config.Items.Add(new MarketBestSellingItemConfig
                {
                    ProductId = productId,
                    Order = config.Items.Count + 1,
                    Active = active ?? true,
                    CustomBadge = "الأكثر مبيعًا"
                });
            }

            await _genericSetting.SetValue(SettingKey, config, null);
            _cache.Remove(CacheKey);

            return true;
        }

        /// <summary>
        /// Admin: Reorder market best selling products
        /// </summary>
        [HttpPost]
        [Route("Reorder")]
        public async Task<ActionResult<bool>> Reorder([FromBody] int[] productIds)
        {
            if (productIds == null || !productIds.Any()) return BadRequest("Product IDs required");

            var config = await GetOrInitConfigAsync();
            var newItems = new List<MarketBestSellingItemConfig>();

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
        /// Admin: Search products to add to Market Best Selling
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
            var existingIds = new HashSet<int>(config.Items.Select(x => x.ProductId));

            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active &&
                            x.MerchantKind != MerchantKind.Restaurant &&
                            (merchantId == null || x.Id == merchantId))
                .ToDictionaryAsync(x => x.Id, x => x);
            var activeMerchantIds = merchants.Keys.ToList();

            var query = _productService.Queryable()
                .AsNoTracking()
                .Include(x => x.ProductCategory)
                .Include(x => x.MerchantProducts)
                .Where(x => x.DeletionDate == null && x.Active &&
                            x.MerchantProducts.Any(m => activeMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

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

            var prods = await query
                .OrderByDescending(x => x.Id)
                .Take(take)
                .ToListAsync();

            var result = prods.Select(p =>
            {
                var mp = p.MerchantProducts?
                    .Where(m => merchants.ContainsKey(m.MerchantId))
                    .OrderBy(m => m.MerchantPrice)
                    .FirstOrDefault();

                var mid = mp?.MerchantId ?? 0;
                merchants.TryGetValue(mid, out var m);

                return new SearchProductCandidateDto
                {
                    Id = p.Id,
                    Title = p.Title,
                    Unit = p.Unit,
                    Photos = p.Photos,
                    Price = mp?.MerchantPrice ?? 0m,
                    CategoryId = p.ProductCategoryId ?? 0,
                    CategoryTitle = p.ProductCategory?.Title ?? "",
                    MerchantId = mid,
                    MerchantTitle = m?.Title ?? "",
                    Active = p.Active,
                    IsAlreadyInPopular = existingIds.Contains(p.Id)
                };
            }).ToArray();

            return result;
        }

        private async Task<MarketBestSellingSectionConfig> GetOrInitConfigAsync()
        {
            if (_genericSetting == null)
            {
                return new MarketBestSellingSectionConfig();
            }

            MarketBestSellingSectionConfig config = null;
            try
            {
                config = await _genericSetting.GetValue<MarketBestSellingSectionConfig>(SettingKey, null);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to read MarketBestSellingConfig from generic settings");
            }

            if (config != null)
            {
                return config;
            }

            // Seed initial config
            config = new MarketBestSellingSectionConfig
            {
                Enabled = true,
                SectionTitle = "الأكثر مبيعًا",
                SectionTitleEn = "Best Selling",
                Mode = "Hybrid",
                MaxItems = 10,
                Items = new List<MarketBestSellingItemConfig>()
            };

            try
            {
                // Start the shelf with active products offered by a market
                // merchant, never restaurant menu items.
                var activeMarketMerchantIds = await _merchantService.Queryable()
                    .AsNoTracking()
                    .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind != MerchantKind.Restaurant)
                    .Select(x => x.Id)
                    .ToListAsync();
                var candidateQuery = _productService.Queryable()
                    .AsNoTracking()
                    .Include(x => x.MerchantProducts)
                    .Where(x => x.DeletionDate == null && x.Active &&
                                x.MerchantProducts.Any(m => activeMarketMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

                var seedProducts = await candidateQuery
                    .OrderByDescending(x => x.IsFeatured)
                    .ThenByDescending(x => x.Id)
                    .Take(6)
                    .ToListAsync();
                int order = 1;
                foreach (var sp in seedProducts)
                {
                    config.Items.Add(new MarketBestSellingItemConfig
                    {
                        ProductId = sp.Id,
                        Order = order++,
                        Active = true,
                        CustomBadge = "الأكثر مبيعًا"
                    });
                }

                await _genericSetting.SetValue(SettingKey, config, null);
                _cache.Remove(CacheKey);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to seed default MarketBestSellingConfig");
            }

            return config;
        }

        private async Task<MarketBestSellingSectionConfig> NormalizeConfigAsync(MarketBestSellingSectionConfig config)
        {
            if (config == null) config = new MarketBestSellingSectionConfig();
            if (string.IsNullOrWhiteSpace(config.SectionTitle)) config.SectionTitle = "الأكثر مبيعًا";
            if (string.IsNullOrWhiteSpace(config.SectionTitleEn)) config.SectionTitleEn = "Best Selling";
            config.MaxItems = Math.Clamp(config.MaxItems <= 0 ? 10 : config.MaxItems, 1, 50);
            config.Mode = config.Mode == "Manual" || config.Mode == "Auto" ? config.Mode : "Hybrid";

            var items = config.Items ?? new List<MarketBestSellingItemConfig>();

            // Deduplicate items
            var distinctItems = new List<MarketBestSellingItemConfig>();
            var seenIds = new HashSet<int>();
            foreach (var item in items)
            {
                if (item.ProductId > 0 && !seenIds.Contains(item.ProductId))
                {
                    seenIds.Add(item.ProductId);
                    distinctItems.Add(item);
                }
            }

            // Validate products exist
            var productIds = distinctItems.Select(x => x.ProductId).ToList();
            if (productIds.Any())
            {
                var activeMarketMerchantIds = await _merchantService.Queryable()
                    .AsNoTracking()
                    .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind != MerchantKind.Restaurant)
                    .Select(x => x.Id)
                    .ToListAsync();
                var validIds = await _productService.Queryable()
                    .AsNoTracking()
                    .Where(x => productIds.Contains(x.Id) && x.DeletionDate == null &&
                                x.MerchantProducts.Any(m => activeMarketMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0))
                    .Select(x => x.Id)
                    .ToListAsync();

                var validSet = new HashSet<int>(validIds);
                distinctItems = distinctItems.Where(x => validSet.Contains(x.ProductId)).ToList();
            }

            // Normalize order
            for (int i = 0; i < distinctItems.Count; i++)
            {
                distinctItems[i].Order = i + 1;
                if (string.IsNullOrWhiteSpace(distinctItems[i].CustomBadge))
                {
                    distinctItems[i].CustomBadge = "الأكثر مبيعًا";
                }
            }

            config.Items = distinctItems;
            return config;
        }
    }
}
