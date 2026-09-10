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
using System;
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
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public ProductsController(IProductService service, IMerchantService merchantService, UserManager<AppUser> userManager, ICatalogUnitOfWork unitOfWork, IMapper mapper, ILogger<ProductsController> logger)
        {
            _service = service;
            _merchantService = merchantService;
            _userManager = userManager;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
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
                    Address = x.Address,
                    Photo = x.Photo
                })
                .ToArrayAsync();

            return merchants;
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
                            .Where(x => x.DeletionDate == null && x.ProductCategory.Active && x.Active);

            int[] mids = null;
            // Filter for merchants on my location only
            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetValidMerchants(vm.Lat.Value, vm.Lng.Value);
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId)));
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
            // Filter for merchants on my location only

            if (vm.Lat.HasValue && vm.Lng.HasValue)
            {
                mids = await _merchantService.GetValidMerchants(vm.Lat.Value, vm.Lng.Value);
                if (mids != null && mids.Length > 0)
                    q = q.Where(x => x.MerchantProducts.Any(m => mids.Contains(m.MerchantId)));
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
    }
}
