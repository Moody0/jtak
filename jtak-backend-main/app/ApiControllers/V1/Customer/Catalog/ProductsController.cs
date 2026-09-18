using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Linq;
using System.Threading.Tasks;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Services;
using Modules.Orders.Entities;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using MerchantDto = Modules.Catalog.Entities.MerchantDto;
using System;
using System.Collections.Generic;
using System.Text.Json;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ApiVersion("1")]
    public class ProductsController : SolApiController
    {
        private readonly IMerchantService _merchantService;
        private readonly IProductService _service;
        private readonly UserManager<AppUser> _userManager;
        private readonly ICatalogUnitOfWork _unitOfWork;
        private readonly IOrderDetailService _orderDetailsService;
        private readonly IGenericSettingService _genericSetting;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public ProductsController(
            IProductService service,
            IMerchantService merchantService,
            UserManager<AppUser> userManager,
            ICatalogUnitOfWork unitOfWork,
            IMapper mapper,
            ILogger<ProductsController> logger,
            IGenericSettingService genericSetting = null,
            IOrderDetailService orderDetailsService = null)
        {
            _service = service;
            _merchantService = merchantService;
            _userManager = userManager;
            _unitOfWork = unitOfWork;
            _mapper = mapper;
            _logger = logger;
            _genericSetting = genericSetting;
            _orderDetailsService = orderDetailsService;
        }

        /// <summary>
        /// Returns active merchants for one explicitly assigned merchant type.
        /// </summary>
        [HttpGet]
        [Route("MerchantsByKind/{merchantKind}")]
        public async Task<ActionResult<MerchantDto[]>> MerchantsByKind(MerchantKind merchantKind)
        {
            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind == merchantKind)
                .OrderBy(x => x.Title)
                .Select(x => new MerchantDto
                {
                    Id = x.Id,
                    Title = x.Title,
                    ShortDescription = x.ShortDescription,
                    Description = x.Description,
                    Phone1 = x.Phone1,
                    Phone2 = x.Phone2,
                    ShippingCoverageInMeters = x.ShippingCoverageInMeters,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    Photo = x.Photo
                })
                .ToArrayAsync();

            return merchants;
        }

        /// <summary>
        /// Returns active merchants for customer app, optionally filtered by kind.
        /// </summary>
        [HttpGet]
        [Route("Merchants")]
        public async Task<ActionResult<MerchantDto[]>> GetMerchants([FromQuery] MerchantKind? kind = null)
        {
            var q = _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active);

            if (kind.HasValue)
            {
                q = q.Where(x => x.MerchantKind == kind.Value);
            }

            var merchants = await q
                .OrderBy(x => x.Title)
                .Select(x => new MerchantDto
                {
                    Id = x.Id,
                    Title = x.Title,
                    ShortDescription = x.ShortDescription,
                    Description = x.Description,
                    Phone1 = x.Phone1,
                    Phone2 = x.Phone2,
                    ShippingCoverageInMeters = x.ShippingCoverageInMeters,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    Photo = x.Photo
                })
                .ToArrayAsync();

            return merchants;
        }

        /// <summary>
        /// Returns single active merchant details for customer app by ID.
        /// </summary>
        [HttpGet]
        [Route("Merchants/{id}")]
        [Route("Merchant/{id}")]
        public async Task<ActionResult<MerchantDto>> GetMerchant(int id)
        {
            var merchant = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.Id == id && x.DeletionDate == null && x.Active)
                .Select(x => new MerchantDto
                {
                    Id = x.Id,
                    Title = x.Title,
                    ShortDescription = x.ShortDescription,
                    Description = x.Description,
                    Phone1 = x.Phone1,
                    Phone2 = x.Phone2,
                    ShippingCoverageInMeters = x.ShippingCoverageInMeters,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    Photo = x.Photo
                })
                .FirstOrDefaultAsync();

            if (merchant == null)
            {
                return NotFound();
            }

            return merchant;
        }

        /// <summary>
        /// Merchants that actually stock something in this category, including
        /// its subcategories. The apps previously inferred this by comparing a
        /// category's name against merchant names and cuisines, so a category
        /// nobody happened to be named after fell through to listing every
        /// merchant there is.
        /// </summary>
        [HttpGet]
        [Route("MerchantsByCategory/{categoryId}")]
        public async Task<ActionResult<MerchantDto[]>> MerchantsByCategory(int categoryId,
                                                                           [FromQuery] decimal? lat = null,
                                                                           [FromQuery] decimal? lng = null)
        {
            var offers = _service.Queryable().AsNoTracking()
                                 .Where(x => x.DeletionDate == null && x.Active &&
                                             x.ProductCategory.Active &&
                                             (x.ProductCategoryId == categoryId ||
                                              x.ProductCategory.ParentId == categoryId))
                                 .SelectMany(x => x.MerchantProducts)
                                 .Where(m => m.MerchantPrice > 0);

            // Honour delivery coverage when the caller knows where it is, using
            // the same rule search uses so the two can never disagree.
            if (lat.HasValue && lng.HasValue)
            {
                var reachable = await _merchantService.GetSearchableMerchants(lat.Value, lng.Value);
                if (reachable != null && reachable.Length > 0)
                    offers = offers.Where(m => reachable.Contains(m.MerchantId));
            }

            var merchantIds = await offers.Select(m => m.MerchantId).Distinct().ToArrayAsync();
            if (!merchantIds.Any())
                return Array.Empty<MerchantDto>();

            return await _merchantService.Queryable().AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active && merchantIds.Contains(x.Id))
                .OrderBy(x => x.Title)
                .Select(x => new MerchantDto
                {
                    Id = x.Id,
                    Title = x.Title,
                    ShortDescription = x.ShortDescription,
                    Description = x.Description,
                    Phone1 = x.Phone1,
                    Phone2 = x.Phone2,
                    ShippingCoverageInMeters = x.ShippingCoverageInMeters,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    Photo = x.Photo
                })
                .ToArrayAsync();
        }

        /// <summary>
        /// Customer-facing endpoint: Get active products for a specific merchant
        /// </summary>
        [HttpGet]
        [Route("Merchants/{mid}/Products")]
        public async Task<ActionResult<MerchantProductDto[]>> GetMerchantProducts(int mid)
        {
            var products = await _service.Queryable()
                                   .Include(x => x.MerchantProducts)
                                   .Include(x => x.ProductCategory)
                                   .ThenInclude(x => x.Parent)
                                   .Where(x => x.DeletionDate == null && x.Active && (x.ProductCategory == null || x.ProductCategory.Active))
                                   .OrderBy(x => x.ProductCategory.Order)
                                   .Select(x => new MerchantProductDto
                                   {
                                       ProductId = x.Id,
                                       Product = x.Title,
                                       ProductBarcode = x.Barcode,
                                       ProductBrand = x.Brand,
                                       ProductCat1 = x.ProductCategory != null ? x.ProductCategory.Title : "Uncategorized",
                                       ProductCat2 = x.ProductCategory != null && x.ProductCategory.Parent != null ? x.ProductCategory.Parent.Title : "",
                                       ProductPhotos = x.Photos,
                                       ProductDescription = x.Description,
                                       ProductUnit = x.Unit,
                                       ProductCategoryId = x.ProductCategoryId,
                                       ProductActive = x.Active,
                                       ProductIsFeatured = x.IsFeatured,
                                       CategoryParentId = x.ProductCategory != null ? x.ProductCategory.ParentId : null,
                                       CategoryActive = x.ProductCategory != null && x.ProductCategory.Active,
                                       CategoryIcon = x.ProductCategory != null ? x.ProductCategory.Icon : null
                                   })
                                   .ToArrayAsync();

            var mps = await _merchantService.GetActiveMerchantPrices(mid);

            var result = new System.Collections.Generic.List<MerchantProductDto>();
            foreach (var product in products)
            {
                if (mps.ContainsKey(product.ProductId))
                {
                    var mp = mps[product.ProductId];
                    product.ProfitOutOfMerchantPricePercent = mp.ProfitOutOfMerchantPricePercent;
                    product.MerchantPrice = mp.MerchantPrice;
                    product.AdditionalProfitPercent = mp.AdditionalProfitPercent;
                    product.Discount = mp.Discount;
                    product.MerchantId = mid;
                    result.Add(product);
                }
            }
            return result.ToArray();
        }

        /// <summary>
        /// Get product details by ID for customer app
        /// </summary>
        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<ProductDto>> Get(int id, [FromQuery] int? merchantId = null)
        {
            var item = await _service.Queryable()
                                     .Include(x => x.ProductCategory)
                                     .Include(x => x.Tags)
                                     .ThenInclude(x => x.Tag)
                                     .Include(x => x.MerchantProducts)
                                     .FirstOrDefaultAsync(x => x.Id == id && x.DeletionDate == null && x.Active);

            if (item == null)
                return NotFound();

            var model = _mapper.Map<ProductDto>(item);
            if (item.Tags != null)
            {
                model.Tags = item.Tags.Where(t => t.Tag != null).Select(x => _mapper.Map<TagDto>(x.Tag)).ToArray();
            }
            model.ProductCategory = item.ProductCategory?.Title;

            if (merchantId.HasValue && merchantId.Value > 0)
            {
                var mp = await _merchantService.GetBestProductPrice(id, new[] { merchantId.Value });
                if (mp != null && mp.FinalPrice > 0)
                {
                    model.Price = mp.Price;
                    model.FinalPrice = mp.FinalPrice;
                    model.MerchantId = mp.MerchantId;
                    model.PriceUsd = mp.PriceUsd;
                    model.OriginalPrice = mp.OriginalPrice;
                    model.Discount = mp.Discount;
                }
            }
            else
            {
                var mp = await _merchantService.GetBestProductPrice(id, null);
                if (mp != null && mp.FinalPrice > 0)
                {
                    model.Price = mp.Price;
                    model.FinalPrice = mp.FinalPrice;
                    model.MerchantId = mp.MerchantId;
                    model.PriceUsd = mp.PriceUsd;
                    model.OriginalPrice = mp.OriginalPrice;
                    model.Discount = mp.Discount;
                }
            }

            if (model.FinalPrice <= 0)
            {
                var fallbackMp = item.MerchantProducts?.FirstOrDefault(m => m.MerchantPrice > 0);
                if (fallbackMp != null)
                {
                    model.Price = fallbackMp.MerchantPrice;
                    model.FinalPrice = fallbackMp.MerchantPrice;
                    model.MerchantId = fallbackMp.MerchantId;
                    model.PriceUsd = fallbackMp.PriceUsd;
                    model.OriginalPrice = fallbackMp.OriginalPrice;
                    model.Discount = fallbackMp.Discount;
                    if (fallbackMp.PriceUsd.HasValue && fallbackMp.PriceUsd.Value > 0)
                    {
                        var usdRate = await _merchantService.GetUsdRate();
                        if (usdRate > 0)
                        {
                            model.Price = Math.Round(fallbackMp.PriceUsd.Value * usdRate, 0, MidpointRounding.AwayFromZero);
                            model.FinalPrice = model.Price;
                        }
                    }
                }
            }

            return model;
        }

        /// <summary>
        /// Search all Products
        /// </summary>
        /// <remarks>
        /// OrderBy values:
        /// <list type="bullet">
        /// <item>
        /// <term><c>PriceAsc</c></term>
        /// <description>0</description>
        /// </item>
        /// <item>
        /// <term><c>PriceDesc</c></term>
        /// <description>1</description>
        /// </item>
        /// <item>
        /// <term><c>ReviewAsc</c></term>
        /// <description>2</description>
        /// </item>
        /// <item>
        /// <term><c>ReviewDesc</c></term>
        /// <description>3</description>
        /// </item>
        /// </list>
        /// </remarks>
        /// <returns></returns>
        [HttpPost]
        [Route("Search")]
        public async Task<ActionResult<ProductLiteDto[]>> Search(ProductSearchVm vm)
        {
            vm.q = vm.q?.Trim().ToLower();
            var doSearch = !string.IsNullOrEmpty(vm.q);

            var q = _service.Queryable()
                            .Include(x => x.MerchantProducts)
                            .Include(x => x.ProductCategory)
                            .Where(x => !vm.ProductCategoryId.HasValue ||
                                x.ProductCategoryId == vm.ProductCategoryId ||
                                x.ProductCategory.ParentId == vm.ProductCategoryId)
                            .Where(x => !doSearch || x.Title.ToLower().Contains(vm.q))
                            .Where(x => x.DeletionDate == null && (x.ProductCategory == null || x.ProductCategory.Active) && x.Active);

            int[] mids = null;
            // Restaurants are limited to their delivery coverage, markets are not.
            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetSearchableMerchants(vm.Lat.Value, vm.Lng.Value);
                // An unpriced row means the merchant does not actually stock the
                // product. Excluding those here keeps this filter in step with
                // the priced-only check applied to the results below, so a page
                // of results cannot silently come back part empty.
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) && (m.MerchantPrice > 0 || (m.PriceUsd.HasValue && m.PriceUsd.Value > 0))));
            }
            else
            {
                _logger.LogError("قم بتحديد مكانك أولا!");
                _logger.LogError(JsonSerializer.Serialize(vm));
                return BadRequest("قم بتحديد مكانك أولا!");
            }

            // Fetch next page for products
            var productsPage = await q.OrderBy(x => x.ProductCategory.Order)
                                      .Skip(vm.Page * vm.Take)
                                      .Take(vm.Take)
                                      .Select(x => new ProductLiteDto
                                      {
                                          Id = x.Id,
                                          Title = x.Title,
                                          Description = x.Description,
                                          CategoryId = x.ProductCategory.Id,
                                          Photos = x.Photos,
                                          Unit = x.Unit
                                      })
                                      .ToArrayAsync();

            // Load merchant prices from cache
            foreach (var product in productsPage)
            {
                var mp = await _merchantService.GetBestProductPrice(product.Id, mids);
                if (mp != null)
                {
                    product.MerchantId = mp.MerchantId;
                    product.Price = mp.Price;
                    product.FinalPrice = mp.FinalPrice;
                    product.PriceUsd = mp.PriceUsd;
                    product.OriginalPrice = mp.OriginalPrice;
                    product.Discount = mp.Discount;
                }
            }

            //q = vm.OrderBy switch
            //{
            //    OrderBy.PriceAsc => q.OrderBy(x => x.Price),
            //    OrderBy.PriceDesc => q.OrderByDescending(x => x.Price),
            //    OrderBy.ReviewAsc => q.OrderBy(x => x.Rate),
            //    OrderBy.ReviewDesc => q.OrderByDescending(x => x.Rate),
            //    _ => q
            //};

            return productsPage.Where(x => x.MerchantId != 0 && x.FinalPrice != 0).ToArray();
        }

        /// <summary>
        /// Search all Products
        /// </summary>
        /// <remarks>
        /// OrderBy values:
        /// <list type="bullet">
        /// <item>
        /// <term><c>PriceAsc</c></term>
        /// <description>0</description>
        /// </item>
        /// <item>
        /// <term><c>PriceDesc</c></term>
        /// <description>1</description>
        /// </item>
        /// <item>
        /// <term><c>ReviewAsc</c></term>
        /// <description>2</description>
        /// </item>
        /// <item>
        /// <term><c>ReviewDesc</c></term>
        /// <description>3</description>
        /// </item>
        /// </list>
        /// </remarks>
        /// <returns></returns>
        [HttpPost]
        [Route("SearchGrouped")]
        public async Task<ActionResult<ProductCategoryLiteDto[]>> SearchGrouped(ProductSearchVm vm)
        {
            vm.q = vm.q?.Trim().ToLower();
            var doSearch = !string.IsNullOrEmpty(vm.q);

            var q = _service.Queryable()
                            .Include(x => x.MerchantProducts)
                            .Include(x => x.ProductCategory)
                            .Where(x => !vm.ProductCategoryId.HasValue || x.ProductCategory.ParentId == vm.ProductCategoryId)
                            .Where(x => !doSearch || x.Title.ToLower().Contains(vm.q))
                            .Where(x => x.DeletionDate == null && x.ProductCategory.Active && x.Active);

            int[] mids = null;
            // Restaurants are limited to their delivery coverage, markets are not.
            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetSearchableMerchants(vm.Lat.Value, vm.Lng.Value);
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) && m.MerchantPrice > 0));
            }
            else
            {
                _logger.LogError("قم بتحديد مكانك أولا!");
                _logger.LogError(JsonSerializer.Serialize(vm));
                return BadRequest("قم بتحديد مكانك أولا!");
            }

            // Fetch next page for products
            var products = await q.OrderBy(x => x.ProductCategory.Order)
                                      .Select(x => new ProductLiteDto
                                      {
                                          Id = x.Id,
                                          Title = x.Title,
                                          Description = x.Description,
                                          CategoryId = x.ProductCategory.Id,
                                          Category = x.ProductCategory.Title,
                                          Photos = x.Photos,
                                          Unit = x.Unit
                                      })
                                      .ToArrayAsync();

            // Load merchant prices from cache
            foreach (var product in products)
            {
                var mp = await _merchantService.GetBestProductPrice(product.Id, mids);
                //var mps = await _merchantService.GetProductPrices(product.Id);
                //var mp = mps.Values.OrderBy(x => x.MerchantPrice).FirstOrDefault(x => x.MerchantPrice > 0 && mids.Contains(x.MerchantId));
                if (mp != null)
                {
                    product.MerchantId = mp.MerchantId;
                    product.Price = mp.Price;
                    product.FinalPrice = mp.FinalPrice;
                    product.PriceUsd = mp.PriceUsd;
                    product.OriginalPrice = mp.OriginalPrice;
                    product.Discount = mp.Discount;
                }
            }

            //q = vm.OrderBy switch
            //{
            //    OrderBy.PriceAsc => q.OrderBy(x => x.Price),
            //    OrderBy.PriceDesc => q.OrderByDescending(x => x.Price),
            //    OrderBy.ReviewAsc => q.OrderBy(x => x.Rate),
            //    OrderBy.ReviewDesc => q.OrderByDescending(x => x.Rate),
            //    _ => q
            //};

            return products.Where(x => x.MerchantId != 0 && x.FinalPrice != 0)
                           .GroupBy(x => x.Category)
                           .Select(x => new ProductCategoryLiteDto
                           {
                               Category = x.Key,
                               Products = x.ToArray()
                           })
                           .ToArray();
            //return products.Where(x => x.MerchantId != 0 && x.FinalPrice != 0).ToArray();
        }

        /// <summary>
        /// Customer-facing: Returns most popular / ordered products for Home page
        /// Fully controlled by Admin through Dashboard (Manual, Hybrid, or Auto mode)
        /// </summary>
        [HttpGet]
        [Route("Popular")]
        public async Task<ActionResult<PopularProductDto[]>> GetPopular([FromQuery] int take = 15)
        {
            if (take <= 0 || take > 50) take = 15;

            PopularSectionConfig popularConfig = null;
            if (_genericSetting != null)
            {
                try
                {
                    popularConfig = await _genericSetting.GetValue<PopularSectionConfig>("PopularProductsConfig", null);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to read PopularProductsConfig in GetPopular");
                }
            }

            if (popularConfig != null && !popularConfig.Enabled)
            {
                return Array.Empty<PopularProductDto>();
            }

            string mode = popularConfig?.Mode ?? "Hybrid";
            var activeConfigItems = popularConfig?.Items?
                .Where(x => x.Active && x.ProductId > 0)
                .OrderBy(x => x.Order)
                .ToList() ?? new List<PopularProductItemConfig>();

            // Strictly filter merchants to restaurants only
            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active && x.MerchantKind == MerchantKind.Restaurant)
                .ToDictionaryAsync(x => x.Id, x => x);

            var restaurantMerchantIds = merchants.Keys.ToList();

            var productsQuery = _service.Queryable()
                .AsNoTracking()
                .Include(x => x.MerchantProducts)
                .Include(x => x.ProductCategory)
                .Where(x => x.DeletionDate == null && x.Active && (x.ProductCategory == null || x.ProductCategory.Active))
                .Where(x => x.MerchantProducts.Any(m => restaurantMerchantIds.Contains(m.MerchantId)));

            var candidateProducts = new System.Collections.Generic.List<Product>();

            // 1. Manual Mode: Strictly return admin curated items in exact admin order
            if (mode.Equals("Manual", StringComparison.OrdinalIgnoreCase))
            {
                var adminIds = activeConfigItems.Select(x => x.ProductId).Distinct().ToList();
                if (adminIds.Any())
                {
                    var prods = await productsQuery
                        .Where(x => adminIds.Contains(x.Id))
                        .ToListAsync();

                    // Restore administrator's exact custom sequence
                    candidateProducts = adminIds
                        .Select(id => prods.FirstOrDefault(p => p.Id == id))
                        .Where(p => p != null)
                        .Take(take)
                        .ToList();
                }
            }
            // 2. Hybrid Mode (Default): Admin curated items first, followed by trending/sales
            else if (mode.Equals("Hybrid", StringComparison.OrdinalIgnoreCase))
            {
                var adminIds = activeConfigItems.Select(x => x.ProductId).Distinct().ToList();
                if (adminIds.Any())
                {
                    var adminProds = await productsQuery
                        .Where(x => adminIds.Contains(x.Id))
                        .ToListAsync();

                    candidateProducts = adminIds
                        .Select(id => adminProds.FirstOrDefault(p => p.Id == id))
                        .Where(p => p != null)
                        .ToList();
                }

                // If fewer than `take` items, supplement with top ordered / featured meals
                if (candidateProducts.Count < take)
                {
                    var existingIds = candidateProducts.Select(x => x.Id).ToList();

                    var topOrderedStats = new System.Collections.Generic.List<(int ProductId, int Count)>();
                    if (_orderDetailsService != null)
                    {
                        try
                        {
                            var stats = await _orderDetailsService.Queryable()
                                .AsNoTracking()
                                .Where(x => x.ProductId > 0 && !existingIds.Contains(x.ProductId) &&
                                            (x.OrderDetailStatus == OrderDetailStatus.Delivered ||
                                             x.OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                                             x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted))
                                .GroupBy(x => x.ProductId)
                                .Select(g => new { ProductId = g.Key, Count = g.Sum(x => x.Quantity) })
                                .OrderByDescending(x => x.Count)
                                .Take(take * 2)
                                .ToListAsync();

                            topOrderedStats = stats.Select(s => (s.ProductId, s.Count)).ToList();
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Failed to query orderDetailsService in Hybrid GetPopular");
                        }
                    }

                    var topProductIds = topOrderedStats.Select(x => x.ProductId).ToList();
                    if (topProductIds.Any())
                    {
                        var topProds = await productsQuery
                            .Where(x => topProductIds.Contains(x.Id))
                            .ToListAsync();

                        candidateProducts.AddRange(topProds);
                    }

                    if (candidateProducts.Count < take)
                    {
                        var currentIds = candidateProducts.Select(x => x.Id).ToList();
                        var supplementProducts = await productsQuery
                            .Where(x => !currentIds.Contains(x.Id))
                            .OrderByDescending(x => x.IsFeatured)
                            .ThenBy(x => x.ProductCategory.Order)
                            .Take(take - candidateProducts.Count)
                            .ToListAsync();
                        candidateProducts.AddRange(supplementProducts);
                    }
                }
            }
            // 3. Auto Mode: Purely based on real sales statistics
            else
            {
                var topOrderedStats = new System.Collections.Generic.List<(int ProductId, int Count)>();
                if (_orderDetailsService != null)
                {
                    try
                    {
                        var stats = await _orderDetailsService.Queryable()
                            .AsNoTracking()
                            .Where(x => x.ProductId > 0 &&
                                        (x.OrderDetailStatus == OrderDetailStatus.Delivered ||
                                         x.OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                                         x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted))
                            .GroupBy(x => x.ProductId)
                            .Select(g => new { ProductId = g.Key, Count = g.Sum(x => x.Quantity) })
                            .OrderByDescending(x => x.Count)
                            .Take(take * 2)
                            .ToListAsync();

                        topOrderedStats = stats.Select(s => (s.ProductId, s.Count)).ToList();
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to query orderDetailsService in Auto GetPopular");
                    }
                }

                var topProductIds = topOrderedStats.Select(x => x.ProductId).ToList();
                if (topProductIds.Any())
                {
                    candidateProducts = await productsQuery
                        .Where(x => topProductIds.Contains(x.Id))
                        .ToListAsync();
                }

                if (candidateProducts.Count < take)
                {
                    var existingIds = candidateProducts.Select(x => x.Id).ToList();
                    var supplementProducts = await productsQuery
                        .Where(x => !existingIds.Contains(x.Id))
                        .OrderByDescending(x => x.IsFeatured)
                        .ThenBy(x => x.ProductCategory.Order)
                        .Take(take - candidateProducts.Count)
                        .ToListAsync();
                    candidateProducts.AddRange(supplementProducts);
                }
            }

            var result = new System.Collections.Generic.List<PopularProductDto>();
            foreach (var p in candidateProducts)
            {
                var mp = await _merchantService.GetBestProductPrice(p.Id, null);
                var mid = mp?.MerchantId ?? p.MerchantProducts?.FirstOrDefault()?.MerchantId ?? 0;
                if (mid <= 0 || !merchants.ContainsKey(mid))
                {
                    var validMp = p.MerchantProducts?.FirstOrDefault(m => merchants.ContainsKey(m.MerchantId));
                    if (validMp != null) mid = validMp.MerchantId;
                }

                if (!merchants.TryGetValue(mid, out var merchant)) continue;
                decimal finalPrice = mp?.FinalPrice ?? 0m;
                decimal price = mp?.Price ?? finalPrice;

                if (finalPrice <= 0)
                {
                    var fallbackPrice = p.MerchantProducts?.FirstOrDefault(m => m.MerchantId == mid);
                    if (fallbackPrice != null && fallbackPrice.MerchantPrice > 0)
                    {
                        if (fallbackPrice.PriceUsd.HasValue && fallbackPrice.PriceUsd.Value > 0)
                        {
                            var usdRate = await _merchantService.GetUsdRate();
                            if (usdRate > 0)
                            {
                                price = Math.Round(fallbackPrice.PriceUsd.Value * usdRate, 0, MidpointRounding.AwayFromZero);
                                finalPrice = price;
                            }
                            else
                            {
                                price = fallbackPrice.MerchantPrice;
                                finalPrice = fallbackPrice.MerchantPrice;
                            }
                        }
                        else
                        {
                            price = fallbackPrice.MerchantPrice;
                            finalPrice = fallbackPrice.MerchantPrice;
                        }
                    }
                }

                if (finalPrice <= 0) continue;

                var customItem = activeConfigItems.FirstOrDefault(x => x.ProductId == p.Id);
                var itemTitle = (!string.IsNullOrWhiteSpace(customItem?.CustomTitle)) ? customItem.CustomTitle : p.Title;

                string eta = "15-25 دقيقة";
                if (!string.IsNullOrEmpty(merchant?.ShortDescription) && merchant.ShortDescription.Contains("•"))
                {
                    var parts = merchant.ShortDescription.Split('•');
                    if (parts.Length > 1) eta = parts[1].Trim();
                }

                result.Add(new PopularProductDto
                {
                    Id = p.Id,
                    Title = itemTitle,
                    Description = p.Description,
                    Price = price,
                    FinalPrice = finalPrice,
                    Photos = p.Photos,
                    Unit = p.Unit,
                    CategoryId = p.ProductCategoryId ?? 0,
                    Category = p.ProductCategory?.Title ?? "",
                    MerchantId = mid,
                    MerchantTitle = merchant?.Title ?? "متجر جيتك",
                    MerchantLogo = merchant?.Photo ?? "",
                    MerchantKind = (int)(merchant?.MerchantKind ?? MerchantKind.Restaurant),
                    Eta = eta,
                    Distance = "1.8 كم",
                    OrdersCount = 1
                });

                if (result.Count >= take) break;
            }

            return result.ToArray();
        }
    }
}
