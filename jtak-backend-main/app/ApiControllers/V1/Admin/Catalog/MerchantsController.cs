using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System.Globalization;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;
using App.Catalog.Data;
using Solf.Models;
using Microsoft.AspNetCore.Hosting;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class MerchantsController : SolApiController
    {
        private readonly IProductService _productService;
        private readonly IMerchantService _service;
        private readonly ICatalogUnitOfWork _uow;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IWebHostEnvironment _env;
        private readonly IMemoryCache _cache;

        public MerchantsController(IMerchantService service,
            IProductService productService, 
            ICatalogUnitOfWork uow, 
            IMapper mapper,
            IWebHostEnvironment env,
            ILogger<MerchantsController> logger,
            IMemoryCache cache)
        {
            _env = env;
            _service = service;
            _productService = productService;
            _uow = uow;
            _logger = logger;
            _mapper = mapper;
            _cache = cache;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Merchants
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<MerchantDto>>> DataTable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new MerchantDto
            {
                Id = x.Id,
                Title = x.Title,
                ShortDescription = x.ShortDescription,
                Description = x.Description,
                IBAN1 = x.IBAN1,
                IBAN1Title = x.IBAN1Title,
                Phone1 = x.Phone1,
                Phone2 = x.Phone2,
                ShippingCoverageInMeters = x.ShippingCoverageInMeters,
                ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent,
                Lat = x.Lat,
                Lng = x.Lng,
                OwnerId = x.OwnerId,
                Active = x.Active,
                MerchantKind = x.MerchantKind,
                DeliveryTime = x.DeliveryTime,
                DeliveryFee = x.DeliveryFee,
                MinOrderAmount = x.MinOrderAmount,
                WorkingHours = x.WorkingHours,
                Address = x.Address,
                Photo = x.Photo
            }, x => x.DeletionDate == null);
            return list;
        }


        /// <summary>
        /// Create a new Merchant
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<int>> Create(MerchantDto item)
        {
            var entity = new Merchant
            {
                Title = item.Title,
                ShortDescription = item.ShortDescription,
                Description = item.Description,
                Photo = item.Photo,
                IBAN1Title = item.IBAN1Title,
                IBAN1 = item.IBAN1,
                Phone1 = item.Phone1,
                Phone2 = item.Phone2,
                Address = item.Address,
                ShippingCoverageInMeters = item.ShippingCoverageInMeters,
                ProfitOutOfMerchantPricePercent = item.ProfitOutOfMerchantPricePercent,
                Lat = item.Lat,
                Lng = item.Lng,
                Active = false,
                MerchantKind = item.MerchantKind,
                DeliveryTime = !string.IsNullOrWhiteSpace(item.DeliveryTime) ? item.DeliveryTime : "20-30 دقيقة",
                DeliveryFee = item.DeliveryFee >= 0 ? item.DeliveryFee : 5000m,
                MinOrderAmount = item.MinOrderAmount >= 0 ? item.MinOrderAmount : 15000m,
                WorkingHours = !string.IsNullOrWhiteSpace(item.WorkingHours) ? item.WorkingHours : "حتى 3 ص",
                OwnerId = item.OwnerId
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();
            _logger.LogInformation("Created New {0}", entity.GetType().Name);

            await _service.SetMerchantPercent(entity.Id, item.ProfitOutOfMerchantPricePercent);

            return entity.Id;
        }

        /// <summary>
        /// Edit a Merchant
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, MerchantDto item)
        {
            var entity = await _service.FindAsync(id);

            var merchantActiveChanged = item.Active != entity.Active;

            entity.Title = item.Title;
            entity.ShortDescription = item.ShortDescription;
            entity.Description = item.Description;
            entity.Photo = item.Photo;
            entity.IBAN1Title = item.IBAN1Title;
            entity.IBAN1 = item.IBAN1;
            entity.Phone1 = item.Phone1;
            entity.Phone2 = item.Phone2;
            entity.Address = item.Address;
            entity.ShippingCoverageInMeters = item.ShippingCoverageInMeters;
            entity.ProfitOutOfMerchantPricePercent = item.ProfitOutOfMerchantPricePercent;
            entity.Lat = item.Lat;
            entity.Lng = item.Lng;
            entity.Active = item.Active;
            entity.MerchantKind = item.MerchantKind;
            entity.DeliveryTime = !string.IsNullOrWhiteSpace(item.DeliveryTime) ? item.DeliveryTime : (entity.DeliveryTime ?? "20-30 دقيقة");
            entity.DeliveryFee = item.DeliveryFee;
            entity.MinOrderAmount = item.MinOrderAmount;
            entity.WorkingHours = !string.IsNullOrWhiteSpace(item.WorkingHours) ? item.WorkingHours : (entity.WorkingHours ?? "حتى 3 ص");
            entity.OwnerId = item.OwnerId;

            await _uow.SaveChangesAsync();

            await _service.SetMerchantPercent(entity.Id, item.ProfitOutOfMerchantPricePercent);

            // If active changed: remove merchant products from cach
            if (merchantActiveChanged)
            {
                _cache.Remove($"ActiveMerchantPrices_{id}");
                _cache.Remove($"AllMerchantPrices_{id}");
                var mpIds = (await _service.GetActiveMerchantPrices(id)).Select(x=>x.Key).ToArray();
                foreach (var mpId in mpIds)
                {
                    _cache.Remove($"ProductPrices_{mpId}");
                    _cache.Remove($"MerchantProduct_{id}_{mpId}");
                }
            }

            return entity.Id;
        }

        /// <summary>
        /// SetProducts of a Merchant (just the ones linked to this merchant)
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Products/{mid}")]
        public async Task<ActionResult<int>> SetProducts(int mid, [FromBody] MerchantProductAssignDto[] products) =>
            await _service.AssignMerchantProducts(new[] { mid }, products);

        /// <summary>
        /// Get all Products, including the ones linked to a Merchant (MerchantId == mid)
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Products/{mid}")]
        public async Task<ActionResult<MerchantProductDto[]>> GetProducts(int mid)
        {
            var products = await _productService.Queryable()
                                   .Include(x => x.MerchantProducts)
                                   .Include(x => x.ProductCategory)
                                   .ThenInclude(x => x.Parent)
                                   .Where(x => x.DeletionDate == null)
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

            // TODO: Get all prices even if the merchant is inactive
            var mps = await _service.GetAllMerchantPrices(mid);

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
                }
            }
            return products;
        }

        /// <summary>
        /// Delete Merchant
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var merchant = await _service.FindAsync(id);
            if (merchant != null)
            {
                merchant.Active = false;
            }
            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            _cache.Remove("GetValidMerchants");
            _cache.Remove($"GetActiveMerchantPrices_{id}");
            _cache.Remove($"GetAllMerchantPrices_{id}");
            return true;
        }

    }
}
