using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Data.MultiContext;
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
using Solf.Base;
using URF.Core.Abstractions.Trackable;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ApiVersion("1")]
    public class ProductsController : SolApiController
    {
        private readonly IMerchantService _merchantService;
        private readonly IProductService _service;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepository;
        private readonly IProductCategoryService _categoryService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ICatalogUnitOfWork _unitOfWork;
        private readonly IOrderDetailService _orderDetailsService;
        private readonly IGenericSettingService _genericSetting;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public ProductsController(
            IProductService service,
            ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepository,
            IProductCategoryService categoryService,
            IMerchantService merchantService,
            UserManager<AppUser> userManager,
            ICatalogUnitOfWork unitOfWork,
            IMapper mapper,
            ILogger<ProductsController> logger,
            IGenericSettingService genericSetting = null,
            IOrderDetailService orderDetailsService = null)
        {
            _service = service;
            _merchantProductRepository = merchantProductRepository;
            _categoryService = categoryService;
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
            var virtualMarketId = await _merchantService.GetJtakMarketMerchantId();
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
                    Lat = x.Id == virtualMarketId ? 0m : x.Lat,
                    Lng = x.Id == virtualMarketId ? 0m : x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    IsJtakMarket = x.Id == virtualMarketId,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    LogoBackgroundColor = x.LogoBackgroundColor,
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
            var virtualMarketId = await _merchantService.GetJtakMarketMerchantId();
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
                    Lat = x.Id == virtualMarketId ? 0m : x.Lat,
                    Lng = x.Id == virtualMarketId ? 0m : x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    IsJtakMarket = x.Id == virtualMarketId,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    LogoBackgroundColor = x.LogoBackgroundColor,
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
            var virtualMarketId = await _merchantService.GetJtakMarketMerchantId();
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
                    Lat = x.Id == virtualMarketId ? 0m : x.Lat,
                    Lng = x.Id == virtualMarketId ? 0m : x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    IsJtakMarket = x.Id == virtualMarketId,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    LogoBackgroundColor = x.LogoBackgroundColor,
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
            var virtualMarketId = await _merchantService.GetJtakMarketMerchantId();
            var categoryIds = await GetActiveCategoryTreeIds(categoryId);
            if (!categoryIds.Any())
                return Array.Empty<MerchantDto>();

            // Start at the join entity to avoid a provider-dependent APPLY query.
            var offers = _merchantProductRepository.Queryable().AsNoTracking()
                .Where(m => m.Product.DeletionDate == null &&
                            m.Product.Active &&
                            m.Product.ProductCategory.Active &&
                            m.Product.ProductCategoryId.HasValue &&
                            categoryIds.Contains(m.Product.ProductCategoryId.Value) &&
                            m.MerchantPrice > 0 &&
                            m.Merchant.DeletionDate == null &&
                            m.Merchant.Active);

            // Keep category listings aligned with the active merchants in search.
            // Checkout validates the delivery pin against the city service area.
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
                    Lat = x.Id == virtualMarketId ? 0m : x.Lat,
                    Lng = x.Id == virtualMarketId ? 0m : x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    IsJtakMarket = x.Id == virtualMarketId,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    LogoBackgroundColor = x.LogoBackgroundColor,
                    Photo = x.Photo
                })
                .ToArrayAsync();
        }

        /// <summary>Active merchants with at least one real, priced product offer.</summary>
        [HttpGet]
        [Route("MerchantsWithOffers")]
        public async Task<ActionResult<MerchantDto[]>> MerchantsWithOffers([FromQuery] decimal? lat = null,
                                                                           [FromQuery] decimal? lng = null)
        {
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            var virtualMarketId = await _merchantService.GetJtakMarketMerchantId();
            var offers = _merchantProductRepository.Queryable().AsNoTracking()
                .Where(x => x.Discount > 0m && x.MerchantPrice > 0m &&
                            x.Product.Active && x.Product.DeletionDate == null &&
                            x.Product.ProductCategoryId.HasValue && visibleCategoryIds.Contains(x.Product.ProductCategoryId.Value) &&
                            x.Merchant.Active && x.Merchant.DeletionDate == null);

            if (lat.HasValue && lng.HasValue)
            {
                var reachable = await _merchantService.GetSearchableMerchants(lat.Value, lng.Value);
                if (reachable == null || reachable.Length == 0)
                    return Array.Empty<MerchantDto>();
                offers = offers.Where(x => reachable.Contains(x.MerchantId));
            }

            var merchantIds = await offers.Select(x => x.MerchantId).Distinct().ToArrayAsync();

            return await _merchantService.Queryable().AsNoTracking()
                .Where(x => x.Active && x.DeletionDate == null && merchantIds.Contains(x.Id))
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
                    Lat = x.Id == virtualMarketId ? 0m : x.Lat,
                    Lng = x.Id == virtualMarketId ? 0m : x.Lng,
                    Active = x.Active,
                    MerchantKind = x.MerchantKind,
                    DeliveryTime = x.DeliveryTime,
                    DeliveryFee = x.DeliveryFee,
                    IsJtakMarket = x.Id == virtualMarketId,
                    MinOrderAmount = x.MinOrderAmount,
                    WorkingHours = x.WorkingHours,
                    Address = x.Address,
                    LogoBackgroundColor = x.LogoBackgroundColor,
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
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            var products = await _service.Queryable()
                                   .Include(x => x.MerchantProducts)
                                   .Include(x => x.ProductCategory)
                                   .ThenInclude(x => x.Parent)
                                   .Where(x => x.DeletionDate == null && x.Active && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)))
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
                    product.Discount = mp.Discount;
                    product.DiscountPercent = mp.DiscountPercent;
                    product.UsdExchangeRate = mp.UsdExchangeRate;
                    product.PriceUsd = mp.PriceUsd;
                    product.OriginalPrice = mp.OriginalPrice;
                    product.MaxOrderQuantity = mp.MaxOrderQuantity;
                    product.MerchantKind = mp.MerchantKind;
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

            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            if (item.ProductCategoryId.HasValue && !visibleCategoryIds.Contains(item.ProductCategoryId.Value)) return NotFound();
            var mp = await _merchantService.GetBestProductPrice(id,
                merchantId.HasValue && merchantId.Value > 0 ? new[] { merchantId.Value } : null);
            if (mp == null || mp.FinalPrice <= 0) return NotFound();
            model.Price = mp.Price;
            model.FinalPrice = mp.FinalPrice;
            model.MerchantId = mp.MerchantId;
            model.MerchantKind = mp.MerchantKind;
            model.PriceUsd = mp.PriceUsd;
            model.OriginalPrice = mp.OriginalPrice;
            model.Discount = mp.Discount;
            model.MaxOrderQuantity = mp.MaxOrderQuantity;

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
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            vm.q = vm.q?.Trim().ToLower();
            var doSearch = !string.IsNullOrEmpty(vm.q);

            var q = _service.Queryable()
                            .Include(x => x.MerchantProducts)
                            .Include(x => x.ProductCategory)
                            .Where(x => !vm.ProductCategoryId.HasValue ||
                                x.ProductCategoryId == vm.ProductCategoryId ||
                                x.ProductCategory.ParentId == vm.ProductCategoryId)
                            .Where(x => !doSearch ||
                                x.Title.ToLower().Contains(vm.q) ||
                                (x.Description != null && x.Description.ToLower().Contains(vm.q)) ||
                                (x.Brand != null && x.Brand.ToLower().Contains(vm.q)) ||
                                (x.ProductCategory != null &&
                                    (x.ProductCategory.Title.ToLower().Contains(vm.q) ||
                                     (x.ProductCategory.Parent != null &&
                                      x.ProductCategory.Parent.Title.ToLower().Contains(vm.q)))))
                            .Where(x => x.DeletionDate == null && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)) && x.Active);

            if (vm.OnlyOffers)
            {
                q = q.Where(x => x.ProductCategory != null &&
                                 x.MerchantProducts.Any(m => m.Discount > 0m && m.MerchantPrice > 0m &&
                                                             m.Merchant.Active && m.Merchant.DeletionDate == null));
            }

            int[] mids = null;
            // Restaurants are limited to their delivery coverage, markets are not.
            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetSearchableMerchants(vm.Lat.Value, vm.Lng.Value);
                if (vm.OnlyOffers && (mids == null || mids.Length == 0))
                    return Array.Empty<ProductLiteDto>();
                // An unpriced row means the merchant does not actually stock the
                // product. Excluding those here keeps this filter in step with
                // the priced-only check applied to the results below, so a page
                // of results cannot silently come back part empty.
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) && (m.MerchantPrice > 0 || (m.PriceUsd.HasValue && m.PriceUsd.Value > 0))));
                if (vm.OnlyOffers)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) &&
                                     m.Discount > 0m && m.MerchantPrice > 0m &&
                                     m.Merchant.Active && m.Merchant.DeletionDate == null));
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
                                          Category = x.ProductCategory.Title,
                                          Photos = x.Photos,
                                          Unit = x.Unit
                                      })
                                      .ToArrayAsync();

            // Load merchant prices from cache
            foreach (var product in productsPage)
            {
                var mp = vm.OnlyOffers
                    ? (await _merchantService.GetProductPrices(product.Id)).Values
                        .Where(x => x.Discount > 0m && x.FinalPrice > 0m &&
                                    (mids == null || mids.Contains(x.MerchantId)))
                        .OrderBy(x => x.FinalPrice)
                        .FirstOrDefault()
                    : await _merchantService.GetBestProductPrice(product.Id, mids);
                if (mp != null)
                {
                    product.MerchantId = mp.MerchantId;
                    product.MerchantKind = mp.MerchantKind;
                    product.Price = mp.Price;
                    product.FinalPrice = mp.FinalPrice;
                    product.PriceUsd = mp.PriceUsd;
                    product.OriginalPrice = mp.OriginalPrice;
                    product.Discount = mp.Discount;
                    product.MaxOrderQuantity = mp.MaxOrderQuantity;
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
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            vm.q = vm.q?.Trim().ToLower();
            var doSearch = !string.IsNullOrEmpty(vm.q);
            var categoryIds = vm.ProductCategoryId.HasValue
                ? await GetActiveCategoryTreeIds(vm.ProductCategoryId.Value)
                : Array.Empty<int>();

            var q = _service.Queryable()
                            .Include(x => x.MerchantProducts)
                            .Include(x => x.ProductCategory)
                            .Where(x => !vm.ProductCategoryId.HasValue ||
                                (x.ProductCategoryId.HasValue &&
                                 categoryIds.Contains(x.ProductCategoryId.Value)))
                            .Where(x => !doSearch ||
                                x.Title.ToLower().Contains(vm.q) ||
                                (x.Description != null && x.Description.ToLower().Contains(vm.q)) ||
                                (x.Brand != null && x.Brand.ToLower().Contains(vm.q)) ||
                                (x.ProductCategory != null &&
                                    (x.ProductCategory.Title.ToLower().Contains(vm.q) ||
                                     (x.ProductCategory.Parent != null &&
                                      x.ProductCategory.Parent.Title.ToLower().Contains(vm.q)))))
                            .Where(x => x.DeletionDate == null && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)) && x.Active);

            if (vm.OnlyOffers)
            {
                q = q.Where(x => x.ProductCategory != null &&
                                 x.MerchantProducts.Any(m => m.Discount > 0m && m.MerchantPrice > 0m &&
                                                             m.Merchant.Active && m.Merchant.DeletionDate == null));
            }

            int[] mids = null;
            // Restaurants are limited to their delivery coverage, markets are not.
            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetSearchableMerchants(vm.Lat.Value, vm.Lng.Value);
                if (vm.OnlyOffers && (mids == null || mids.Length == 0))
                    return Array.Empty<ProductCategoryLiteDto>();
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) && m.MerchantPrice > 0));
                if (vm.OnlyOffers)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId) &&
                                     m.Discount > 0m && m.MerchantPrice > 0m &&
                                     m.Merchant.Active && m.Merchant.DeletionDate == null));
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
                var mp = vm.OnlyOffers
                    ? (await _merchantService.GetProductPrices(product.Id)).Values
                        .Where(x => x.Discount > 0m && x.FinalPrice > 0m &&
                                    (mids == null || mids.Contains(x.MerchantId)))
                        .OrderBy(x => x.FinalPrice)
                        .FirstOrDefault()
                    : await _merchantService.GetBestProductPrice(product.Id, mids);
                //var mps = await _merchantService.GetProductPrices(product.Id);
                //var mp = mps.Values.OrderBy(x => x.MerchantPrice).FirstOrDefault(x => x.MerchantPrice > 0 && mids.Contains(x.MerchantId));
                if (mp != null)
                {
                    product.MerchantId = mp.MerchantId;
                    product.MerchantKind = mp.MerchantKind;
                    product.Price = mp.Price;
                    product.FinalPrice = mp.FinalPrice;
                    product.PriceUsd = mp.PriceUsd;
                    product.OriginalPrice = mp.OriginalPrice;
                    product.Discount = mp.Discount;
                    product.MaxOrderQuantity = mp.MaxOrderQuantity;
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

        private async Task<int[]> GetActiveCategoryTreeIds(int rootId)
        {
            var visibleIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            var categories = await _categoryService.Queryable().AsNoTracking()
                .Where(x => visibleIds.Contains(x.Id)).Select(x => new { x.Id, x.ParentId }).ToArrayAsync();

            if (!categories.Any(x => x.Id == rootId))
                return Array.Empty<int>();

            var ids = new HashSet<int> { rootId };
            var added = true;
            while (added)
            {
                added = false;
                foreach (var category in categories)
                {
                    if (category.ParentId.HasValue &&
                        ids.Contains(category.ParentId.Value) &&
                        ids.Add(category.Id))
                    {
                        added = true;
                    }
                }
            }

            return ids.ToArray();
        }

        /// <summary>
        /// Customer-facing: Returns most popular / ordered products for Home page
        /// Fully controlled by Admin through Dashboard (Manual, Hybrid, or Auto mode)
        /// </summary>
        [HttpGet]
        [Route("Popular")]
        public async Task<ActionResult<PopularProductDto[]>> GetPopular([FromQuery] int take = 15)
        {
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            if (take <= 0 || take > 100) take = 15;

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
            take = Math.Min(take, Math.Clamp(popularConfig?.MaxItems > 0 ? popularConfig.MaxItems : 15, 1, 100));

            string mode = popularConfig?.Mode ?? "Hybrid";
            var excludedProductIds = popularConfig?.Items?.Where(x => x != null && !x.Active && x.ProductId > 0).Select(x => x.ProductId).ToList() ?? new List<int>();
            var activeConfigItems = popularConfig?.Items?
                .Where(x => x != null && x.Active && x.ProductId > 0)
                .OrderBy(x => x.Order)
                .ToList() ?? new List<PopularProductItemConfig>();

            // Popular products can come from any active merchant type.
            // The admin dashboard supports restaurants, groceries, pharmacies,
            // and other stores, so restricting this section to restaurants
            // silently removes valid products from the customer app.
            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active)
                .ToDictionaryAsync(x => x.Id, x => x);

            var activeMerchantIds = merchants.Keys.ToList();

            var baseProductsQuery = _service.Queryable()
                .AsNoTracking()
                .Include(x => x.MerchantProducts)
                .Include(x => x.ProductCategory)
                .Where(x => x.DeletionDate == null && x.Active && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)) &&
                            !excludedProductIds.Contains(x.Id) &&
                            x.MerchantProducts.Any(m => activeMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

            var productsQuery = baseProductsQuery
                .Where(x => x.MerchantProducts.Any(m => activeMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

            var candidateProducts = new System.Collections.Generic.List<Product>();

            // 1. Manual Mode: Strictly return admin curated items in exact admin order
            if (mode.Equals("Manual", StringComparison.OrdinalIgnoreCase))
            {
                var adminIds = activeConfigItems.Select(x => x.ProductId).Distinct().ToList();
                if (adminIds.Any())
                {
                    var prods = await baseProductsQuery
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
                    var adminProds = await baseProductsQuery
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

                        var topProductsById = topProds.ToDictionary(x => x.Id);
                        candidateProducts.AddRange(
                            topProductIds
                                .Where(id => topProductsById.ContainsKey(id))
                                .Select(id => topProductsById[id]));
                    }

                    if (candidateProducts.Count < take)
                    {
                        var currentIds = candidateProducts.Select(x => x.Id).ToList();
                        var supplementProducts = await productsQuery
                            .Where(x => !currentIds.Contains(x.Id))
                            .OrderByDescending(x => x.IsFeatured)
                            .ThenBy(x => x.Title)
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
                    var topProds = await productsQuery
                        .Where(x => topProductIds.Contains(x.Id))
                        .ToListAsync();
                    var topProductsById = topProds.ToDictionary(x => x.Id);
                    candidateProducts = topProductIds
                        .Where(id => topProductsById.ContainsKey(id))
                        .Select(id => topProductsById[id])
                        .ToList();
                }

                if (candidateProducts.Count < take)
                {
                    var existingIds = candidateProducts.Select(x => x.Id).ToList();
                    var supplementProducts = await productsQuery
                        .Where(x => !existingIds.Contains(x.Id))
                        .OrderByDescending(x => x.IsFeatured)
                        .ThenBy(x => x.Title)
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
                int? maxOrderQuantity = mp?.MaxOrderQuantity;

                if (finalPrice <= 0)
                {
                    var fallbackPrice = p.MerchantProducts?.FirstOrDefault(m => m.MerchantId == mid);
                    if (fallbackPrice != null && fallbackPrice.MerchantPrice > 0)
                    {
                        var quote = MerchantProductDto.FromStored(fallbackPrice, await _merchantService.GetUsdRate());
                        finalPrice = quote.FinalPrice;
                        price = quote.Price;
                        maxOrderQuantity = quote.MaxOrderQuantity;
                    }
                }

                if (finalPrice <= 0) continue;

                var customItem = activeConfigItems.FirstOrDefault(x => x.ProductId == p.Id);
                var itemTitle = (!string.IsNullOrWhiteSpace(customItem?.CustomTitle)) ? customItem.CustomTitle : p.Title;

                string eta = merchant?.DeliveryTime ?? "";

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
                    MaxOrderQuantity = maxOrderQuantity,
                    Eta = eta,
                    Distance = "",
                    OrdersCount = 1
                });

                if (result.Count >= take) break;
            }

            return result.ToArray();
        }

        /// <summary>
        /// Customer-facing metadata for the Most Popular home section.
        /// Kept separate from /Popular so existing mobile list consumers remain
        /// backward compatible while still honoring admin visibility and titles.
        /// </summary>
        [HttpGet]
        [Route("PopularConfig")]
        public async Task<ActionResult<object>> GetPopularConfig()
        {
            PopularSectionConfig config = null;
            if (_genericSetting != null)
            {
                try
                {
                    config = await _genericSetting.GetValue<PopularSectionConfig>("PopularProductsConfig", null);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to read PopularProductsConfig metadata");
                }
            }

            return Ok(new
            {
                enabled = config?.Enabled ?? true,
                sectionTitle = config?.SectionTitle ?? "الأكثر طلباً",
                sectionTitleEn = config?.SectionTitleEn ?? "Most Popular",
                maxItems = Math.Clamp(config?.MaxItems > 0 ? config.MaxItems : 15, 1, 100)
            });
        }

        /// <summary>
        /// Customer-facing metadata for Market Best Selling section.
        /// Gives administrator full control over visibility, title, and product curation.
        /// </summary>
        [HttpGet]
        [Route("MarketBestSellingConfig")]
        public async Task<ActionResult<object>> GetMarketBestSellingConfig()
        {
            MarketBestSellingSectionConfig config = null;
            if (_genericSetting != null)
            {
                try
                {
                    config = await _genericSetting.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig", null);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to read MarketBestSellingConfig metadata");
                }
            }

            return Ok(new
            {
                enabled = config?.Enabled ?? true,
                sectionTitle = config?.SectionTitle ?? "الأكثر مبيعًا",
                sectionTitleEn = config?.SectionTitleEn ?? "Best Selling",
                mode = config?.Mode ?? "Hybrid",
                maxItems = config?.MaxItems > 0 ? config.MaxItems : 10,
                curatedProductIds = config?.Items?
                    .Where(x => x.Active && x.ProductId > 0)
                    .OrderBy(x => x.Order)
                    .Select(x => x.ProductId)
                    .ToList() ?? new List<int>()
            });
        }

        /// <summary>
        /// Customer-facing product list for Market Best Selling shelf.
        /// Honors admin configuration (Enabled, Mode, Curated Products, and Ordering).
        /// </summary>
        [HttpGet]
        [Route("MarketBestSelling")]
        public async Task<ActionResult<PopularProductDto[]>> GetMarketBestSelling(
            [FromQuery] int? merchantId = null,
            [FromQuery] int take = 10)
        {
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_categoryService.Queryable());
            if (take <= 0 || take > 50) take = 10;

            MarketBestSellingSectionConfig config = null;
            if (_genericSetting != null)
            {
                try
                {
                    config = await _genericSetting.GetValue<MarketBestSellingSectionConfig>("MarketBestSellingConfig", null);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to read MarketBestSellingConfig in GetMarketBestSelling");
                }
            }

            if (config != null && !config.Enabled)
            {
                return Array.Empty<PopularProductDto>();
            }

            // The administrator owns the shelf size. A client may request
            // fewer items, but cannot override the configured maximum.
            var configuredMaxItems = config?.MaxItems > 0 ? config.MaxItems : 10;
            take = Math.Min(take, Math.Clamp(configuredMaxItems, 1, 50));

            string mode = config?.Mode ?? "Hybrid";
            var excludedProductIds = config?.Items?.Where(x => x != null && !x.Active && x.ProductId > 0).Select(x => x.ProductId).ToList() ?? new List<int>();
            var activeConfigItems = config?.Items?
                .Where(x => x != null && x.Active && x.ProductId > 0)
                .OrderBy(x => x.Order)
                .ToList() ?? new List<MarketBestSellingItemConfig>();

            var merchants = await _merchantService.Queryable()
                .AsNoTracking()
                .Where(x => x.DeletionDate == null && x.Active &&
                            x.MerchantKind != MerchantKind.Restaurant &&
                            (merchantId == null || x.Id == merchantId.Value))
                .ToDictionaryAsync(x => x.Id, x => x);

            var activeMerchantIds = merchants.Keys.ToList();

            var baseProductsQuery = _service.Queryable()
                .AsNoTracking()
                .Include(x => x.MerchantProducts)
                .Include(x => x.ProductCategory)
                .Where(x => x.DeletionDate == null && x.Active && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)) &&
                            !excludedProductIds.Contains(x.Id) && x.MerchantProducts.Any(m => activeMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

            var productsQuery = baseProductsQuery
                .Where(x => x.MerchantProducts.Any(m => activeMerchantIds.Contains(m.MerchantId) && m.MerchantPrice > 0));

            var candidateProducts = new List<Product>();

            var topOrderedStats = new List<(int ProductId, int Count)>();
            if (_orderDetailsService != null && activeMerchantIds.Any())
            {
                try
                {
                    var stats = await _orderDetailsService.Queryable()
                        .AsNoTracking()
                        .Where(x => x.ProductId > 0 && activeMerchantIds.Contains(x.MerchantId) &&
                                    (x.OrderDetailStatus == OrderDetailStatus.Delivered ||
                                     x.OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                                     x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted ||
                                     x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup))
                        .GroupBy(x => x.ProductId)
                        .Select(g => new { ProductId = g.Key, Count = g.Sum(x => x.Quantity) })
                        .OrderByDescending(x => x.Count)
                        .Take(take * 3)
                        .ToListAsync();
                    topOrderedStats = stats.Select(x => (x.ProductId, x.Count)).ToList();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to query sales statistics in GetMarketBestSelling");
                }
            }

            // 1. Manual Mode
            if (mode.Equals("Manual", StringComparison.OrdinalIgnoreCase))
            {
                var adminIds = activeConfigItems.Select(x => x.ProductId).Distinct().ToList();
                if (adminIds.Any())
                {
                    var prods = await productsQuery
                        .Where(x => adminIds.Contains(x.Id))
                        .ToListAsync();

                    candidateProducts = adminIds
                        .Select(id => prods.FirstOrDefault(p => p.Id == id))
                        .Where(p => p != null)
                        .Take(take)
                        .ToList();
                }
            }
            // 2. Hybrid Mode
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

                if (candidateProducts.Count < take)
                {
                    var existingIds = candidateProducts.Select(x => x.Id).ToList();
                    var soldProductIds = topOrderedStats
                        .Where(x => !existingIds.Contains(x.ProductId))
                        .Select(x => x.ProductId)
                        .ToList();
                    if (soldProductIds.Any())
                    {
                        var soldProducts = await productsQuery
                            .Where(x => soldProductIds.Contains(x.Id))
                            .ToListAsync();
                        var soldById = soldProducts.ToDictionary(x => x.Id);
                        candidateProducts.AddRange(soldProductIds
                            .Where(id => soldById.ContainsKey(id))
                            .Select(id => soldById[id])
                            .Take(take - candidateProducts.Count));
                    }

                    if (candidateProducts.Count < take)
                    {
                        var currentIds = candidateProducts.Select(x => x.Id).ToList();
                        var supplementProducts = await productsQuery
                            .Where(x => !currentIds.Contains(x.Id))
                            .OrderByDescending(x => x.IsFeatured)
                            .ThenByDescending(x => x.Id)
                            .Take(take - candidateProducts.Count)
                            .ToListAsync();
                        candidateProducts.AddRange(supplementProducts);
                    }
                }
            }
            // 3. Auto Mode
            else
            {
                var soldProductIds = topOrderedStats.Select(x => x.ProductId).ToList();
                if (soldProductIds.Any())
                {
                    var soldProducts = await productsQuery
                        .Where(x => soldProductIds.Contains(x.Id))
                        .ToListAsync();
                    var soldById = soldProducts.ToDictionary(x => x.Id);
                    candidateProducts = soldProductIds
                        .Where(id => soldById.ContainsKey(id))
                        .Select(id => soldById[id])
                        .Take(take)
                        .ToList();
                }

                if (candidateProducts.Count < take)
                {
                    var existingIds = candidateProducts.Select(x => x.Id).ToList();
                    var supplementProducts = await productsQuery
                        .Where(x => !existingIds.Contains(x.Id))
                        .OrderByDescending(x => x.IsFeatured)
                        .ThenByDescending(x => x.Id)
                        .Take(take - candidateProducts.Count)
                        .ToListAsync();
                    candidateProducts.AddRange(supplementProducts);
                }
            }

            var result = new List<PopularProductDto>();
            foreach (var p in candidateProducts)
            {
                var mp = p.MerchantProducts?
                    .Where(m => merchants.ContainsKey(m.MerchantId) && m.MerchantPrice > 0)
                    .OrderBy(m => m.MerchantPrice)
                    .FirstOrDefault();

                var mid = mp?.MerchantId ?? (merchantId ?? 0);
                merchants.TryGetValue(mid, out var m);
                MerchantProductDto priceQuote = null;
                try
                {
                    priceQuote = mid > 0
                        ? await _merchantService.GetBestProductPrice(p.Id, new[] { mid })
                        : null;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to calculate market best-selling price for product {ProductId}", p.Id);
                }
                var itemConfig = mode.Equals("Auto", StringComparison.OrdinalIgnoreCase)
                    ? null
                    : activeConfigItems.FirstOrDefault(x => x.ProductId == p.Id);

                result.Add(new PopularProductDto
                {
                    Id = p.Id,
                    Title = string.IsNullOrWhiteSpace(itemConfig?.CustomTitle)
                        ? p.Title
                        : itemConfig.CustomTitle,
                    Description = p.Description,
                    CategoryId = p.ProductCategoryId ?? 0,
                    Category = p.ProductCategory?.Title ?? "",
                    Photos = p.Photos,
                    Unit = p.Unit,
                    Price = priceQuote?.Price ?? mp?.MerchantPrice ?? 0m,
                    FinalPrice = priceQuote?.FinalPrice ?? mp?.MerchantPrice ?? 0m,
                    MerchantId = mid,
                    MerchantTitle = m?.Title ?? "المتجر",
                    MerchantLogo = m?.Photo ?? "",
                    MerchantKind = (int)(m?.MerchantKind ?? MerchantKind.Grocery),
                    Eta = m?.DeliveryTime ?? "",
                    Distance = "",
                    OrdersCount = 0,
                    CustomBadge = itemConfig?.CustomBadge
                });
            }

            return Ok(result.ToArray());
        }
    }
}
