using App.Catalog.Data;
using App.Shared.Entities;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using App.Shared.Entities.Enums;
using Solf.Models;
using App.Extensions;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class ProductsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IMerchantService _merchantService;
        private readonly IProductCategoryService _categoryService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ICatalogUnitOfWork _unitOfWork;
        private readonly IMemoryCache _cache;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public ProductsController(
            IProductService service,
            IMerchantService merchantService,
            IProductCategoryService categoryService,
            UserManager<AppUser> userManager,
            ICatalogUnitOfWork unitOfWork,
            IMemoryCache cache,
            IMapper mapper,
            ILogger<ProductsController> logger)
        {
            _service = service;
            _merchantService = merchantService;
            _categoryService = categoryService;
            _userManager = userManager;
            _unitOfWork = unitOfWork;
            _cache = cache;
            _logger = logger;
            _mapper = mapper;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Products
        /// </summary>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<ProductDto>>> DataTable([FromBody] MetronicTable request)
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var list = await _service.ListMetronicTableQueryable(request, x => new ProductDto
            {
                Id = x.Id,
                Title = x.Title,
                Description = x.Description,
                ProductCategory = x.ProductCategory.Title,
                Photos = x.Photos,
                ProductCategoryId = x.ProductCategoryId
            }, x => x.DeletionDate == null && x.MerchantProducts.Any(mp => mids.Contains(mp.MerchantId)), x => x.ProductCategoryId);

            return list;
        }

        /// <summary>
        /// SetPrices of a Merchant (Merchant Price)
        /// </summary>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Prices")]
        public async Task<ActionResult<int>> SetPrices(int mid, [FromBody] MerchantProductPriceDto[] products)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids.Length == 0) return Forbid();
            if (products == null || products.Any(x => x == null || x.MerchantPrice < 0 ||
                x.MaxOrderQuantity < 1 || x.MaxOrderQuantity > 999) || products.GroupBy(x => x.ProductId).Any(x => x.Count() > 1))
                return BadRequest("بيانات الأسعار غير صالحة.");
            var ids = products.Select(x => x.ProductId).ToArray();
            var ownedCount = await _service.Queryable().CountAsync(x => ids.Contains(x.Id) && x.DeletionDate == null &&
                x.MerchantProducts.Any(mp => mids.Contains(mp.MerchantId)));
            if (ownedCount != ids.Length) return Forbid();
            var result = await _merchantService.SetMerchantProductPrices(mids, products);
            foreach (var m in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{m}");
                _cache.Remove($"AllMerchantPrices_{m}");
            }
            return result;
        }

        /// <summary>
        /// Get all Products linked to this Merchant (including out-of-stock items)
        /// </summary>
        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<MerchantProductDto[]>> Get()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids == null || mids.Length == 0) return Ok(Array.Empty<MerchantProductDto>());

            var products = await _service.Queryable()
                .Include(x => x.MerchantProducts)
                .Include(x => x.ProductCategory)
                .ThenInclude(x => x.Parent)
                .Where(x => x.DeletionDate == null && x.MerchantProducts.Any(mp => mids.Contains(mp.MerchantId)))
                .OrderBy(x => x.ProductCategory != null ? x.ProductCategory.Order : 999)
                .Select(x => new MerchantProductDto
                {
                    ProductId = x.Id,
                    Product = x.Title,
                    ProductBarcode = x.Barcode,
                    ProductBrand = x.Brand,
                    ProductCat1 = x.ProductCategory != null ? x.ProductCategory.Title : "عام",
                    ProductCat2 = x.ProductCategory != null && x.ProductCategory.Parent != null ? x.ProductCategory.Parent.Title : "",
                    ProductPhotos = x.Photos,
                    ProductDescription = x.Description,
                    ProductUnit = x.Unit,
                    ProductCategoryId = x.ProductCategoryId,
                    ProductActive = x.Active,
                    ProductIsFeatured = x.IsFeatured,
                    CategoryParentId = x.ProductCategory != null ? x.ProductCategory.ParentId : null,
                    CategoryActive = x.ProductCategory == null || x.ProductCategory.Active,
                    CategoryIcon = x.ProductCategory != null ? x.ProductCategory.Icon : null
                })
                .ToArrayAsync();

            var resultList = new System.Collections.Generic.List<MerchantProductDto>();
            foreach (var mid in mids)
            {
                var mps = await _merchantService.GetAllMerchantPrices(mid);
                foreach (var metadata in products)
                {
                    if (mps.ContainsKey(metadata.ProductId))
                    {
                        var product = new MerchantProductDto {
                            ProductId = metadata.ProductId, Product = metadata.Product, ProductBarcode = metadata.ProductBarcode,
                            ProductBrand = metadata.ProductBrand, ProductCat1 = metadata.ProductCat1, ProductCat2 = metadata.ProductCat2,
                            ProductPhotos = metadata.ProductPhotos, ProductDescription = metadata.ProductDescription,
                            ProductUnit = metadata.ProductUnit, ProductCategoryId = metadata.ProductCategoryId,
                            ProductActive = metadata.ProductActive, ProductIsFeatured = metadata.ProductIsFeatured,
                            CategoryParentId = metadata.CategoryParentId, CategoryActive = metadata.CategoryActive,
                            CategoryIcon = metadata.CategoryIcon
                        };
                        var mp = mps[product.ProductId];
                        product.ProfitOutOfMerchantPricePercent = mp.ProfitOutOfMerchantPricePercent;
                        product.MerchantPrice = mp.MerchantPrice;
                        product.Discount = mp.Discount;
                        product.DiscountPercent = mp.DiscountPercent;
                        product.PriceUsd = mp.PriceUsd;
                        product.OriginalPrice = mp.OriginalPrice;
                        product.UsdExchangeRate = mp.UsdExchangeRate;
                        product.MaxOrderQuantity = mp.MaxOrderQuantity;
                        product.MerchantKind = mp.MerchantKind;
                        product.MerchantId = mid;
                        resultList.Add(product);
                    }
                }
            }

            return Ok(resultList.ToArray());
        }

        /// <summary>
        /// Get active categories list for store menu filtering and item categorization
        /// </summary>
        [HttpGet]
        [Route("Categories")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<ProductCategoryDto[]>> GetCategories()
        {
            var categories = await _categoryService.Queryable()
                .Where(c => c.DeletionDate == null && c.Active)
                .OrderBy(c => c.Order)
                .Select(c => new ProductCategoryDto
                {
                    Id = c.Id,
                    Title = c.Title,
                    Icon = c.Icon,
                    ParentId = c.ParentId,
                    Active = c.Active,
                    Order = c.Order
                })
                .ToArrayAsync();

            return Ok(categories);
        }

        /// <summary>
        /// Create a new Product for this Merchant
        /// </summary>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<int>> Create([FromBody] MerchantProductManageDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.Title))
                return BadRequest("اسم الصنف مطلوب.");

            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids == null || mids.Length == 0) return Forbid();
            if (dto.Price <= 0) return BadRequest("سعر الصنف يجب أن يكون أكبر من صفر.");
            if (dto.ProductCategoryId.HasValue && !await _categoryService.Queryable().AnyAsync(x => x.Id == dto.ProductCategoryId && x.DeletionDate == null && x.Active))
                return BadRequest("التصنيف المحدد غير موجود أو غير مفعّل.");
            if (dto.MaxOrderQuantity.HasValue && (dto.MaxOrderQuantity.Value < 1 || dto.MaxOrderQuantity.Value > 999))
                return BadRequest("يجب أن يكون الحد الأقصى للطلب بين 1 و999.");
            var maxOrderQuantity = await AreRestaurantMerchants(mids) ? dto.MaxOrderQuantity : null;

            var product = new Product
            {
                Title = dto.Title.Trim(),
                Description = dto.Description?.Trim(),
                Photos = dto.Photos != null ? string.Join(",", dto.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null,
                Unit = string.IsNullOrWhiteSpace(dto.Unit) ? "وجبة" : dto.Unit.Trim(),
                ProductCategoryId = dto.ProductCategoryId,
                Active = dto.Active
            };

            _service.Insert(product);
            await _unitOfWork.SaveChangesAsync();

            await _merchantService.SetMerchantProductPrices(mids, new[]
            {
                new MerchantProductPriceDto
                {
                    ProductId = product.Id,
                    MerchantPrice = dto.Price,
                    MaxOrderQuantity = maxOrderQuantity
                }
            });

            foreach (var mid in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }

            InvalidateProduct(product.Id, mids);
            return Ok(product.Id);
        }

        /// <summary>
        /// Update an existing Product for this Merchant
        /// </summary>
        [HttpPut]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<bool>> Update(int id, [FromBody] MerchantProductManageDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.Title))
                return BadRequest("بيانات الصنف غير صحيحة.");

            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids == null || mids.Length == 0) return Forbid();
            if (dto.Price <= 0) return BadRequest("سعر الصنف يجب أن يكون أكبر من صفر.");
            if (dto.ProductCategoryId.HasValue && !await _categoryService.Queryable().AnyAsync(x => x.Id == dto.ProductCategoryId && x.DeletionDate == null))
                return BadRequest("التصنيف المحدد غير موجود.");
            if (dto.MaxOrderQuantity.HasValue && (dto.MaxOrderQuantity.Value < 1 || dto.MaxOrderQuantity.Value > 999))
                return BadRequest("يجب أن يكون الحد الأقصى للطلب بين 1 و999.");
            var maxOrderQuantity = await AreRestaurantMerchants(mids) ? dto.MaxOrderQuantity : null;

            var product = await FindOwnedProduct(id, mids);
            if (product == null) return NotFound();

            if (product.MerchantProducts.Any(mp => !mids.Contains(mp.MerchantId)) &&
                ((product.Title ?? "").Trim() != dto.Title.Trim() || (product.Description ?? "").Trim() != (dto.Description ?? "").Trim() ||
                (dto.Photos != null && (product.Photos ?? "") != NormalizePhotos(dto.Photos)) ||
                (!string.IsNullOrEmpty(dto.Unit) && product.Unit != dto.Unit.Trim()) ||
                (dto.ProductCategoryId.HasValue && product.ProductCategoryId != dto.ProductCategoryId) || product.Active != dto.Active))
                return BadRequest("هذا المنتج مشترك بين متاجر. يمكنك تعديل سعرك؛ لتغيير بياناته اطلب من الإدارة نسخة مستقلة لمتجرك.");

            product.Title = dto.Title.Trim();
            product.Description = dto.Description?.Trim();
            if (dto.Photos != null)
            {
                product.Photos = NormalizePhotos(dto.Photos);
            }
            if (!string.IsNullOrEmpty(dto.Unit))
            {
                product.Unit = dto.Unit.Trim();
            }
            if (dto.ProductCategoryId.HasValue)
            {
                product.ProductCategoryId = dto.ProductCategoryId;
            }
            product.Active = dto.Active;

            await _unitOfWork.SaveChangesAsync();

            if (dto.Price > 0)
            {
                await _merchantService.SetMerchantProductPrices(mids, new[]
                {
                    new MerchantProductPriceDto
                    {
                        ProductId = product.Id,
                        MerchantPrice = dto.Price,
                        MaxOrderQuantity = maxOrderQuantity
                    }
                });
            }

            foreach (var mid in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }

            InvalidateProduct(id, mids);
            return Ok(true);
        }

        /// <summary>
        /// Quick Toggle in-stock / out-of-stock availability
        /// </summary>
        [HttpPut]
        [Route("{id}/Availability")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<bool>> ToggleAvailability(int id, [FromBody] ProductAvailabilityDto dto = null)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids == null || mids.Length == 0) return Forbid();

            var product = await FindOwnedProduct(id, mids);
            if (product == null) return NotFound();

            if (product.MerchantProducts.Any(mp => !mids.Contains(mp.MerchantId)))
                return BadRequest("هذا المنتج مشترك بين متاجر. اطلب من الإدارة نسخة مستقلة قبل تغيير توافره.");
            if (dto != null && dto.Active.HasValue)
            {
                product.Active = dto.Active.Value;
            }
            else
            {
                product.Active = !product.Active;
            }

            await _unitOfWork.SaveChangesAsync();

            foreach (var mid in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }

            InvalidateProduct(id, mids);
            return Ok(product.Active);
        }

        /// <summary>
        /// Soft delete product
        /// </summary>
        [HttpDelete]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            if (mids == null || mids.Length == 0) return Forbid();

            var product = await FindOwnedProduct(id, mids);
            if (product == null) return NotFound();

            if (product.MerchantProducts.Any(mp => !mids.Contains(mp.MerchantId)))
            {
                foreach (var mid in mids)
                {
                    var remaining = await _service.Queryable().Where(x => x.Id != id && x.DeletionDate == null)
                        .SelectMany(x => x.MerchantProducts.Where(mp => mp.MerchantId == mid))
                        .Select(mp => new MerchantProductAssignDto { ProductId = mp.ProductId, MerchantPrice = mp.MerchantPrice,
                            PriceUsd = mp.PriceUsd, OriginalPrice = mp.OriginalPrice, Discount = mp.Discount,
                            DiscountPercent = mp.DiscountPercent, MaxOrderQuantity = mp.MaxOrderQuantity }).ToArrayAsync();
                    await _merchantService.AssignMerchantProducts(new[] { mid }, remaining);
                }
                InvalidateProduct(id, mids);
                InvalidateProduct(id, mids);
            return Ok(true);
            }
            product.DeletionDate = DateTime.UtcNow;
            product.Active = false;
            await _unitOfWork.SaveChangesAsync();

            foreach (var mid in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }

            InvalidateProduct(id, mids);
            return Ok(true);
        }

        private async Task<bool> AreRestaurantMerchants(int[] merchantIds)
        {
            foreach (var merchantId in merchantIds)
            {
                var merchant = await _merchantService.FindAsync(merchantId);
                if (merchant == null || merchant.MerchantKind != MerchantKind.Restaurant)
                    return false;
            }
            return true;
        }

        /// <summary>
        /// Get a specific Product by id
        /// </summary>
        [HttpGet]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<MerchantProductDto>> Get(int id)
        {
            var result = await Get();
            if (result.Result is not OkObjectResult ok) return result.Result;
            var product = ((MerchantProductDto[])ok.Value).FirstOrDefault(x => x.ProductId == id);
            if (product == null) return NotFound();
            return product;
        }

        private Task<Product> FindOwnedProduct(int id, int[] mids) => _service.Queryable()
            .Include(x => x.MerchantProducts).FirstOrDefaultAsync(x => x.Id == id && x.DeletionDate == null &&
                x.MerchantProducts.Any(mp => mids.Contains(mp.MerchantId)));

        private static string NormalizePhotos(string photos) => string.Join(",", photos.Split(",",
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));

        private void InvalidateProduct(int id, int[] mids)
        {
            _cache.Remove($"Product-{id}");
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("PopularProductsCache");
            foreach (var mid in mids)
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
                _cache.Remove($"MerchantProduct_{mid}_{id}");
            }
        }
    }

    public class MerchantProductManageDto
    {
        public int? Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Photos { get; set; }
        public string Unit { get; set; }
        public decimal Price { get; set; }
        public int? ProductCategoryId { get; set; }
        public bool Active { get; set; } = true;
        public int? MaxOrderQuantity { get; set; }
    }

    public class ProductAvailabilityDto
    {
        public bool? Active { get; set; }
    }
}
