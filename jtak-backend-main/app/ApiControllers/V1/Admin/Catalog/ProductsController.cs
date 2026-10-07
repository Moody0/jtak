using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Globalization;
using System.Linq;
using System.Linq.Expressions;
using System.Collections.Generic;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;
using App.Catalog.Data;
using Solf.Models;
using App.ApiModels;
using App.ApiModels.Admin;
using System.IO;
using OfficeOpenXml;
using Microsoft.AspNetCore.Hosting;
using App.Helpers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using URF.Core.Abstractions.Trackable;
using App.Shared.Data.MultiContext;
using App.Shared.Services;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    public class ProductsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IProductCategoryService _productCategoryService;
        private readonly IMerchantService _merchantService;
        private readonly ITagService _tagService;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepo;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IMemoryCache _cache;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IWebHostEnvironment _env;
        private readonly IAdminAuditService _auditService;

        public ProductsController(IProductService service,
            IProductCategoryService productCategoryService,
            IMerchantService merchantService,
            ITagService tagService,
            ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepo,
            ICatalogUnitOfWork uow,
            IMemoryCache cache,
            IMapper mapper,
            IWebHostEnvironment env,
            ILogger<ProductsController> logger,
            IAdminAuditService auditService = null)
        {
            _env = env;
            _service = service;
            _productCategoryService = productCategoryService;
            _merchantService = merchantService;
            _tagService = tagService;
            _merchantProductRepo = merchantProductRepo;
            _uow = uow;
            _cache = cache;
            _logger = logger;
            _mapper = mapper;
            _auditService = auditService;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Products
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<ProductDto>>> DataTable(
            [FromBody] MetronicTable request, [FromQuery] int? categoryId = null, [FromQuery] bool? active = null)
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            var visibleCategoryIds = await CatalogCategoryVisibility.GetIdsAsync(_productCategoryService.Queryable());
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            Expression<Func<Product, bool>> productFilter = x => x.DeletionDate == null && (!active.HasValue || x.Active == active.Value);
            if (categoryId.HasValue)
            {
                if (categoryId.Value <= 0)
                    return BadRequest(ApiErr.Create("معرّف التصنيف غير صالح."));

                var categories = await _productCategoryService.Queryable()
                    .Where(x => x.DeletionDate == null)
                    .Select(x => new { x.Id, x.ParentId })
                    .ToListAsync();
                var childrenByParent = categories.ToLookup(x => x.ParentId);
                var selectedIds = new HashSet<int>();
                if (categories.Any(x => x.Id == categoryId.Value))
                {
                    var pending = new Queue<int>();
                    pending.Enqueue(categoryId.Value);
                    while (pending.Count > 0)
                    {
                        var current = pending.Dequeue();
                        if (!selectedIds.Add(current)) continue;
                        foreach (var child in childrenByParent[current])
                            pending.Enqueue(child.Id);
                    }
                }

                var categoryIds = selectedIds.ToList();
                productFilter = x => x.DeletionDate == null && (!active.HasValue || x.Active == active.Value) &&
                    x.ProductCategoryId.HasValue && categoryIds.Contains(x.ProductCategoryId.Value);
            }
            var list = await _service.ListMetronicTableQueryable(request, x => new ProductDto
            {
                Id = x.Id,
                IsPublishedToCustomer = x.Active && (!x.ProductCategoryId.HasValue || visibleCategoryIds.Contains(x.ProductCategoryId.Value)) && x.MerchantProducts.Any(mp => mp.Merchant != null && mp.Merchant.Active && mp.Merchant.DeletionDate == null && mp.MerchantPrice > 0),
                Title = x.Title,
                TitleEn = x.TitleEn,
                Barcode = x.Barcode,
                Brand = x.Brand,
                Unit = x.Unit,
                Description = x.Description,
                DescriptionEn = x.DescriptionEn,
                Photos = x.Photos,
                Currency = x.Currency,
                ExpiryDate = x.ExpiryDate,
                IsFeatured = x.IsFeatured,
                ProductCategoryId = x.ProductCategoryId,
                ProductCategory = x.ProductCategory != null ? x.ProductCategory.Title : string.Empty,
                Active = x.Active,
                MerchantId = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => (int?)mp.MerchantId)
                    .FirstOrDefault(),
                Merchant = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.Merchant != null ? mp.Merchant.Title : string.Empty)
                    .FirstOrDefault(),
                MerchantTitle = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.Merchant != null ? mp.Merchant.Title : string.Empty)
                    .FirstOrDefault(),
                Price = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.MerchantPrice)
                    .FirstOrDefault(),
                PriceUsd = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.PriceUsd)
                    .FirstOrDefault(),
                OriginalPrice = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.OriginalPrice)
                    .FirstOrDefault(),
                Discount = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.Discount)
                    .FirstOrDefault(),
                DiscountPercent = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.DiscountPercent)
                    .FirstOrDefault(),
                ProfitOutOfMerchantPricePercent = x.MerchantProducts
                    .Where(mp => mp.Merchant != null && mp.Merchant.DeletionDate == null)
                    .OrderBy(mp => mp.Merchant.Active ? 0 : 1)
                    .ThenBy(mp => mp.Merchant.MerchantKind == MerchantKind.Restaurant ? 0 : 1)
                    .ThenBy(mp => mp.MerchantId)
                    .Select(mp => mp.ProfitOutOfMerchantPricePercent)
                    .FirstOrDefault(),
            }, productFilter, x => x.ProductCategory, x => x.MerchantProducts);
            return list;
        }

        /// <summary>
        /// Create a new Product
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("BulkImport")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<BulkImportDesc>> BulkImport(ProductsBulkImport item)
        {
            if (item == null || !System.Text.RegularExpressions.Regex.IsMatch(item.File ?? "", @"^\d{4}_\d{1,2}_\d{1,2}_[a-fA-F0-9]{32}\.xlsx$"))
                return BadRequest(ApiErr.Create("اختر ملف Excel صالحاً تم رفعه إلى النظام."));
            var marketMerchantId = await _merchantService.GetJtakMarketMerchantId();
            if (!marketMerchantId.HasValue)
            {
                return BadRequest(ApiErr.Create("تعذر تحديد متجر جيتك ماركت. لم يتم استيراد المنتجات."));
            }

            var file = _env.ContentRootPath + FileHelper.GetVirtualPath(item.File).Replace("/", "\\").Replace("~", "");
            if (!System.IO.File.Exists(file)) return BadRequest(ApiErr.Create("ملف الاستيراد غير موجود. أعد رفعه أولاً."));
            BulkImportDesc result = new();
            var importedProducts = new System.Collections.Generic.List<Product>();
            ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
            ExcelPackage workbook;
            try { workbook = new ExcelPackage(new FileInfo(file)); }
            catch (Exception ex) {
                _logger.LogWarning(ex, "Could not open uploaded catalog workbook");
                return BadRequest(ApiErr.Create("تعذر قراءة ملف Excel. تأكد من سلامة الملف وأعد رفعه."));
            }
            using (var package = workbook)
            {
                if (package.Workbook.Worksheets.Count < 3 || package.Workbook.Worksheets.Take(3).Any(x => x.Dimension == null))
                {
                    return BadRequest(ApiErr.Create("يجب أن يحتوي الملف على ثلاث أوراق غير فارغة: المنتجات، التصنيفات الفرعية، التصنيفات الرئيسية."));
                }

                var cat1Sheet = package.Workbook.Worksheets[2];
                var cat2Sheet = package.Workbook.Worksheets[1];
                var productsSheet = package.Workbook.Worksheets[0];

                // Import Cat1
                var allCats = await _productCategoryService.Queryable().ToArrayAsync();
                for (int row = cat1Sheet.Dimension.Start.Row; row <= cat1Sheet.Dimension.End.Row; row++)
                {
                    var title = cat1Sheet.Cells[row, 1].Text?.Trim();
                    if (string.IsNullOrWhiteSpace(title) || IsImportHeader(title)) continue;
                    var cat = new ProductCategory { Title = title, Active = true };
                    if (!allCats.Any(x => x.Title == cat.Title))
                    {
                        result.ImportedCat1++;
                        _productCategoryService.Insert(cat);
                        allCats = allCats.Append(cat).ToArray();
                    }
                }
                await _uow.SaveChangesAsync();
                allCats = await _productCategoryService.Queryable().ToArrayAsync();

                // Import Cat2
                for (int row = cat2Sheet.Dimension.Start.Row; row <= cat2Sheet.Dimension.End.Row; row++)
                {
                    var parentTitle = cat2Sheet.Cells[row, 2].Text?.Trim();
                    var parentCatId = allCats.FirstOrDefault(x => x.Title == parentTitle)?.Id;

                    if (!parentCatId.HasValue)
                        continue;

                    var title = cat2Sheet.Cells[row, 1].Text?.Trim();
                    if (string.IsNullOrWhiteSpace(title) || IsImportHeader(title)) continue;
                    var cat = new ProductCategory { Title = title, Active = true, ParentId = parentCatId.Value };
                    if (!allCats.Any(x => x.Title == cat.Title && x.ParentId == parentCatId.Value))
                    {
                        result.ImportedCat2++;
                        _productCategoryService.Insert(cat);
                        allCats = allCats.Append(cat).ToArray();
                    }
                }
                await _uow.SaveChangesAsync();
                allCats = await _productCategoryService.Queryable().ToArrayAsync();

                // Import Products
                var allProds = await _service.Queryable().ToArrayAsync();
                var productTitles = new System.Collections.Generic.HashSet<string>(
                    allProds.Select(x => x.Title?.Trim()).Where(x => !string.IsNullOrWhiteSpace(x)),
                    StringComparer.OrdinalIgnoreCase);
                for (int row = productsSheet.Dimension.Start.Row; row <= productsSheet.Dimension.End.Row; row++)
                {
                    var catTitle = productsSheet.Cells[row, 2].Text?.Trim();
                    var catId = allCats.FirstOrDefault(x => x.Title == catTitle)?.Id;

                    if (!catId.HasValue)
                        continue;

                    var title = productsSheet.Cells[row, 1].Text?.Trim();
                    if (string.IsNullOrWhiteSpace(title))
                        continue;

                    var prod = new Product { Title = title, Active = true, ProductCategoryId = catId.Value };
                    if (productTitles.Add(prod.Title))
                    {
                        result.ImportedProds++;
                        _service.Insert(prod);
                        importedProducts.Add(prod);
                    }
                }
                await _uow.SaveChangesAsync();

                var market = await _merchantService.FindAsync(marketMerchantId.Value);
                foreach (var product in importedProducts)
                {
                    _merchantProductRepo.Insert(new MerchantProduct
                    {
                        MerchantId = marketMerchantId.Value,
                        ProductId = product.Id,
                        MerchantPrice = 0m,
                        ProfitOutOfMerchantPricePercent = market?.ProfitOutOfMerchantPricePercent ?? 0m,
                        AdditionalProfitPercent = 0m
                    });
                    _cache.Remove($"MerchantProduct_{marketMerchantId.Value}_{product.Id}");
                }
                if (importedProducts.Count > 0)
                {
                    await _uow.SaveChangesAsync();
                    _cache.Remove($"ActiveMerchantPrices_{marketMerchantId.Value}");
                    _cache.Remove($"AllMerchantPrices_{marketMerchantId.Value}");
                    _cache.Remove("ProductCategoriesTree");
                    _cache.Remove("ProductCategories");
                }
            }
            // TODO: Import images from zip?
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");
            _cache.Remove("VisibleProductCategoryIds");
            return result;
        }

        private static bool IsImportHeader(string title) =>
            new[] { "title", "category", "name", "اسم التصنيف", "التصنيف", "اسم المنتج" }.Contains(title.ToLowerInvariant());

        /// <summary>
        /// Create a new Product
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<int>> Create(ProductDto item)
        {
            if (string.IsNullOrWhiteSpace(item?.Title))
            {
                return BadRequest(ApiErr.Create("اسم المنتج مطلوب."));
            }

            if (item.PriceUsd < 0 || item.OriginalPrice < 0)
                return BadRequest(ApiErr.Create("السعر بالدولار غير صالح."));
            if (item.ProductCategoryId.HasValue && !await _productCategoryService.Queryable().AnyAsync(x => x.Id == item.ProductCategoryId && x.DeletionDate == null))
                return BadRequest(ApiErr.Create("التصنيف المحدد غير موجود."));
            if (!item.ProductCategoryId.HasValue || item.ProductCategoryId.Value <= 0)
            {
                return BadRequest(ApiErr.Create("يرجى اختيار تصنيف صالح للمنتج."));
            }

            if (item.Price < 0)
            {
                return BadRequest(ApiErr.Create("سعر البيع غير صالح."));
            }

            if (item.Discount < 0)
            {
                return BadRequest(ApiErr.Create("قيمة الخصم غير صالحة."));
            }

            if (item.DiscountPercent.HasValue && (item.DiscountPercent.Value < 0m || item.DiscountPercent.Value >= 100m))
            {
                return BadRequest(ApiErr.Create("نسبة الخصم يجب أن تكون بين 0 و99.99٪."));
            }

            var marketMerchantId = await _merchantService.GetJtakMarketMerchantId();
            var merchantId = item.MerchantId.GetValueOrDefault() > 0
                ? item.MerchantId.Value
                : marketMerchantId;
            if (!merchantId.HasValue)
            {
                return BadRequest(ApiErr.Create("تعذر تحديد متجر جيتك ماركت تلقائياً. اختر جيتك ماركت أو المطعم الذي يبيع هذا المنتج."));
            }

            var merchantError = await ValidateProductMerchant(merchantId.Value, marketMerchantId);
            if (merchantError != null)
            {
                return BadRequest(ApiErr.Create(merchantError));
            }

            var price = item.Price > 0 ? item.Price : 0m;
            var priceUsd = item.PriceUsd;
            var discount = item.Discount > 0 ? item.Discount : 0m;
            var originalPrice = item.OriginalPrice;
            var merchantProfit = merchantId.HasValue ? await _merchantService.Queryable()
                .Where(x => x.Id == merchantId.Value).Select(x => x.ProfitOutOfMerchantPricePercent).FirstOrDefaultAsync() : 0m;
            if (item.DiscountPercent.HasValue)
            {
                if (item.DiscountPercent.Value > 0m)
                {


                    var pricing = CalculateDiscountPricing(
                        price,
                        priceUsd,
                        item.DiscountPercent.Value,
                        await _merchantService.GetUsdRate(),
                        profitOutOfMerchantPricePercent: merchantProfit);
                    price = pricing.SalePrice;
                    priceUsd = pricing.SalePriceUsd;
                    discount = pricing.DiscountAmount;
                    originalPrice = pricing.OriginalPriceUsd;
                }
                else
                {
                    discount = 0m;
                    originalPrice = null;
                }
            }

            var entity = new Product
            {
                Title = item.Title.Trim(),
                TitleEn = item.TitleEn?.Trim(),
                Barcode = item.Barcode?.Trim(),
                Brand = item.Brand?.Trim(),
                Description = item.Description?.Trim(),
                DescriptionEn = item.DescriptionEn?.Trim(),
                Unit = !string.IsNullOrWhiteSpace(item.Unit) ? item.Unit.Trim() : "قطعة",
                Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null,
                ProductCategoryId = item.ProductCategoryId,
                Active = item.Active,
                IsFeatured = item.IsFeatured,
                Currency = item.Currency
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();

            if (merchantId.HasValue)
            {
                _merchantProductRepo.Insert(new MerchantProduct
                {
                    MerchantId = merchantId.Value,
                    ProductId = entity.Id,
                    MerchantPrice = price,
                    PriceUsd = priceUsd,
                    OriginalPrice = originalPrice,
                    Discount = discount,
                    DiscountPercent = item.DiscountPercent,
                    ProfitOutOfMerchantPricePercent = merchantProfit
                });
                await _uow.SaveChangesAsync();

                _cache.Remove($"ActiveMerchantPrices_{merchantId.Value}");
                _cache.Remove($"AllMerchantPrices_{merchantId.Value}");
                _cache.Remove($"MerchantProduct_{merchantId.Value}_{entity.Id}");
            }

            _cache.Remove($"ProductPrices_{entity.Id}");
            _cache.Remove($"Product-{entity.Id}");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.Id).ToArray() ?? Array.Empty<int>());
            _logger.LogInformation("Created New {0} #{1}", entity.GetType().Name, entity.Id);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "Create",
                    EntityType = "Product",
                    EntityId = entity.Id.ToString(),
                    Description = $"إضافة منتج جديد: {entity.Title}",
                    Result = "Success",
                    AfterState = new
                    {
                        entity.Id,
                        entity.Title,
                        entity.ProductCategoryId,
                        Price = price,
                        PriceUsd = priceUsd,
                        Discount = discount,
                        DiscountPercent = item.DiscountPercent,
                        MerchantId = merchantId,
                        entity.Active
                    }
                });
            }

            return entity.Id;
        }

        /// <summary>
        /// Edit a Product
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, ProductDto item)
        {
            var entity = await _service.FindAsync(id);
            if (entity == null)
                return NotFound();

            if (string.IsNullOrWhiteSpace(item?.Title))
            {
                return BadRequest(ApiErr.Create("اسم المنتج مطلوب."));
            }

            if (item.PriceUsd < 0 || item.OriginalPrice < 0)
                return BadRequest(ApiErr.Create("السعر بالدولار غير صالح."));
            if (item.ProductCategoryId.HasValue && !await _productCategoryService.Queryable().AnyAsync(x => x.Id == item.ProductCategoryId && x.DeletionDate == null))
                return BadRequest(ApiErr.Create("التصنيف المحدد غير موجود."));
            if (!item.ProductCategoryId.HasValue || item.ProductCategoryId.Value <= 0)
            {
                return BadRequest(ApiErr.Create("يرجى اختيار تصنيف صالح للمنتج."));
            }

            if (item.Price < 0)
            {
                return BadRequest(ApiErr.Create("سعر البيع غير صالح."));
            }

            if (item.Discount < 0)
            {
                return BadRequest(ApiErr.Create("قيمة الخصم غير صالحة."));
            }

            if (item.DiscountPercent.HasValue && (item.DiscountPercent.Value < 0m || item.DiscountPercent.Value >= 100m))
            {
                return BadRequest(ApiErr.Create("نسبة الخصم يجب أن تكون بين 0 و99.99٪."));
            }

            var existingMps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == entity.Id).ToListAsync();
            var marketMerchantId = await _merchantService.GetJtakMarketMerchantId();
            var requestedMerchantId = item.MerchantId.GetValueOrDefault() > 0
                ? item.MerchantId
                : existingMps.Count == 0 ? marketMerchantId : null;
            if (!requestedMerchantId.HasValue && existingMps.Count == 0)
            {
                return BadRequest(ApiErr.Create("تعذر تحديد متجر جيتك ماركت تلقائياً. اختر جيتك ماركت أو المطعم الذي يبيع هذا المنتج."));
            }

            if (requestedMerchantId.HasValue)
            {
                var merchantError = await ValidateProductMerchant(requestedMerchantId.Value, marketMerchantId);
                if (merchantError != null)
                {
                    return BadRequest(ApiErr.Create(merchantError));
                }
            }

            var targetMpForPrice = requestedMerchantId.HasValue
                ? existingMps.FirstOrDefault(mp => mp.MerchantId == requestedMerchantId.Value)
                : null;
            var price = item.Price > 0 ? item.Price : 0m;
            var priceUsd = item.PriceUsd;
            var discount = item.Discount > 0 ? item.Discount : 0m;
            var originalPrice = item.OriginalPrice;
            var merchantProfit = requestedMerchantId.HasValue ? await _merchantService.Queryable()
                .Where(x => x.Id == requestedMerchantId.Value).Select(x => x.ProfitOutOfMerchantPricePercent).FirstOrDefaultAsync()
                : targetMpForPrice?.ProfitOutOfMerchantPricePercent ?? 0m;
            if (item.DiscountPercent.HasValue)
            {
                if (item.DiscountPercent.Value > 0m)
                {
                    var pricing = CalculateDiscountPricing(
                        price,
                        priceUsd,
                        item.DiscountPercent.Value,
                        await _merchantService.GetUsdRate(),
                        merchantProfit);
                    price = pricing.SalePrice;
                    priceUsd = pricing.SalePriceUsd;
                    discount = pricing.DiscountAmount;
                    originalPrice = pricing.OriginalPriceUsd;
                }
                else
                {
                    discount = 0m;
                    originalPrice = null;
                }
            }

            var primaryMp = existingMps.FirstOrDefault();
            var beforeState = new
            {
                entity.Id,
                entity.Title,
                entity.ProductCategoryId,
                MerchantId = primaryMp?.MerchantId,
                Price = primaryMp?.MerchantPrice,
                PriceUsd = primaryMp?.PriceUsd,
                Discount = primaryMp?.Discount,
                entity.Active
            };

            entity.Title = item.Title.Trim();
            entity.TitleEn = item.TitleEn?.Trim();
            entity.Barcode = item.Barcode?.Trim();
            entity.Brand = item.Brand?.Trim();
            entity.Description = item.Description?.Trim();
            entity.DescriptionEn = item.DescriptionEn?.Trim();
            entity.Unit = !string.IsNullOrWhiteSpace(item.Unit) ? item.Unit.Trim() : "قطعة";
            entity.Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null;
            entity.ProductCategoryId = item.ProductCategoryId;
            entity.Active = item.Active;
            entity.IsFeatured = item.IsFeatured;
            entity.Currency = item.Currency;

            // Update MerchantProduct linkage & pricing
            if (requestedMerchantId.HasValue)
            {
                var targetMp = targetMpForPrice;
                if (targetMp != null)
                {
                    targetMp.MerchantPrice = price;
                    targetMp.PriceUsd = priceUsd;
                    targetMp.OriginalPrice = originalPrice;
                    targetMp.Discount = discount;
                    targetMp.ProfitOutOfMerchantPricePercent = merchantProfit;
                    targetMp.DiscountPercent = item.DiscountPercent ?? targetMp.DiscountPercent;
                    _merchantProductRepo.Update(targetMp);


                }
                else
                {
                    foreach (var oldMp in existingMps)
                    {
                        _merchantProductRepo.Delete(oldMp);
                        _cache.Remove($"ActiveMerchantPrices_{oldMp.MerchantId}");
                        _cache.Remove($"AllMerchantPrices_{oldMp.MerchantId}");
                        _cache.Remove($"MerchantProduct_{oldMp.MerchantId}_{entity.Id}");
                    }

                    _merchantProductRepo.Insert(new MerchantProduct
                    {
                        MerchantId = requestedMerchantId.Value,
                        ProductId = entity.Id,
                        MerchantPrice = price,
                        PriceUsd = priceUsd,
                        OriginalPrice = originalPrice,
                        Discount = discount,
                        DiscountPercent = item.DiscountPercent,
                        ProfitOutOfMerchantPricePercent = merchantProfit
                    });
                }

                _cache.Remove($"ActiveMerchantPrices_{requestedMerchantId.Value}");
                _cache.Remove($"AllMerchantPrices_{requestedMerchantId.Value}");
                _cache.Remove($"MerchantProduct_{requestedMerchantId.Value}_{entity.Id}");
            }
            else
            {
                // A partial edit that omits MerchantId must not detach the
                // product. Restaurant products stay with their restaurant;
                // existing market assignment and price are preserved too.
            }

            _cache.Remove($"ProductPrices_{entity.Id}");
            _cache.Remove($"Product-{entity.Id}");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.Id).ToArray() ?? Array.Empty<int>());

            await _uow.SaveChangesAsync();
            _logger.LogInformation("Updated Product #{0}", entity.Id);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "Edit",
                    EntityType = "Product",
                    EntityId = entity.Id.ToString(),
                    Description = $"تعديل بيانات المنتج: {entity.Title}",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = new
                    {
                        entity.Id,
                        entity.Title,
                        entity.ProductCategoryId,
                        MerchantId = requestedMerchantId ?? primaryMp?.MerchantId,
                        Price = item.Price,
                        PriceUsd = priceUsd,
                        Discount = discount,
                        DiscountPercent = item.DiscountPercent,
                        entity.Active
                    }
                });
            }

            return entity.Id;
        }

        /// <summary>
        /// Delete Product (Safe Soft-Delete)
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var product = await _service.FindAsync(id);
            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove("ProductCategoriesTree");

            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            _logger.LogInformation("Soft-deleted Product #{0}", id);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "Delete",
                    EntityType = "Product",
                    EntityId = id.ToString(),
                    Description = $"حذف المنتج: {product?.Title ?? id.ToString()}",
                    Result = "Success"
                });
            }

            return true;
        }

        /// <summary>
        /// Bulk Delete / Archive Products (Safe Soft-Delete)
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DeleteSelected")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
        public async Task<ActionResult<bool>> DeleteSelected([FromBody] int[] ids)
        {
            if (ids == null || ids.Length == 0)
                return BadRequest("No product IDs provided");

            foreach (var id in ids)
            {
                var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
                foreach (var mp in mps)
                {
                    _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                    _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                    _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
                }
                _cache.Remove($"ProductPrices_{id}");
            _cache.Remove($"Product-{id}");

                await _service.DeleteAsync(id);
            }
            _cache.Remove("ProductCategoriesTree");
            await _uow.SaveChangesAsync();
            _logger.LogInformation("Bulk soft-deleted {0} products by Admin", ids.Length);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "BulkDelete",
                    EntityType = "Product",
                    EntityId = string.Join(",", ids),
                    Description = $"حذف جماعي لـ {ids.Length} منتج",
                    Result = "Success",
                    AfterState = new { Count = ids.Length, ProductIds = ids }
                });
            }

            return true;
        }

        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Duplicate/{id}")]
        public async Task<ActionResult<int>> Duplicate(int id)
        {
            var item = await _service.FindAsync(id);
            if (item == null)
                return NotFound();

            var restaurantAssignment = item.MerchantProducts?
                .FirstOrDefault(x => x.Merchant?.MerchantKind == MerchantKind.Restaurant);
            var marketMerchantId = await _merchantService.GetJtakMarketMerchantId();
            var sourceOffer = restaurantAssignment ?? item.MerchantProducts?.OrderBy(x => x.MerchantId == marketMerchantId ? 0 : 1).FirstOrDefault();
            var targetMerchantId = sourceOffer?.MerchantId ?? marketMerchantId;
            if (!targetMerchantId.HasValue)
            {
                return BadRequest(ApiErr.Create("تعذر تحديد متجر جيتك ماركت لربط النسخة الجديدة."));
            }

            var entity = new Product
            {
                Title = item.Title, TitleEn = item.TitleEn, Barcode = item.Barcode, Brand = item.Brand,
                Unit = item.Unit, Currency = item.Currency, Active = item.Active, IsFeatured = item.IsFeatured,
                DescriptionEn = item.DescriptionEn,
                Description = item.Description,
                Photos = item.Photos,
                ProductCategoryId = item.ProductCategoryId,
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();

            var targetMerchant = await _merchantService.FindAsync(targetMerchantId.Value);
            _merchantProductRepo.Insert(new MerchantProduct
            {
                MerchantId = targetMerchantId.Value,
                ProductId = entity.Id,
                MerchantPrice = sourceOffer?.MerchantPrice ?? 0m,
                PriceUsd = sourceOffer?.PriceUsd,
                Discount = sourceOffer?.Discount ?? 0m,
                DiscountPercent = sourceOffer?.DiscountPercent,
                OriginalPrice = sourceOffer?.OriginalPrice, MaxOrderQuantity = sourceOffer?.MaxOrderQuantity,
                ProfitOutOfMerchantPricePercent = targetMerchant?.ProfitOutOfMerchantPricePercent ?? 0m,
                AdditionalProfitPercent = 0m
            });
            await _uow.SaveChangesAsync();
            _cache.Remove($"ActiveMerchantPrices_{targetMerchantId.Value}");
            _cache.Remove($"AllMerchantPrices_{targetMerchantId.Value}");
            _cache.Remove($"MerchantProduct_{targetMerchantId.Value}_{entity.Id}");
            _cache.Remove($"ProductPrices_{entity.Id}");
            _cache.Remove($"Product-{entity.Id}");

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.TagId).ToArray() ?? Array.Empty<int>());
            _logger.LogInformation("Duplicate New {0}", entity.GetType().Name);

            return entity.Id;
        }

        private async Task<string> ValidateProductMerchant(int merchantId, int? marketMerchantId)
        {
            var merchant = await _merchantService.FindAsync(merchantId);
            if (merchant == null || merchant.DeletionDate != null)
            {
                return "المتجر المحدد غير موجود أو غير مفعّل.";
            }

            if (merchant.MerchantKind == MerchantKind.Restaurant || merchant.Id == marketMerchantId)
            {
                return null;
            }

            return null;
        }


        /// <summary>
        /// Enable Product
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}/Enable")]
        public async Task<ActionResult<bool>> Enable(int id)
        {
            var item = await _service.FindAsync(id);
            if (item == null) return NotFound();
            item.Active = true;
            _service.Update(item);
            await _uow.SaveChangesAsync();

            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "Enable",
                    EntityType = "Product",
                    EntityId = id.ToString(),
                    Description = $"تفعيل المنتج: {item.Title}",
                    Result = "Success"
                });
            }

            return true;
        }

        /// <summary>
        /// Disable Product
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}/Disable")]
        public async Task<ActionResult<bool>> Disable(int id)
        {
            var item = await _service.FindAsync(id);
            if (item == null) return NotFound();
            item.Active = false;
            _service.Update(item);
            await _uow.SaveChangesAsync();

            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = "Disable",
                    EntityType = "Product",
                    EntityId = id.ToString(),
                    Description = $"تعطيل المنتج: {item.Title}",
                    Result = "Success"
                });
            }

            return true;
        }

        /// <summary>
        /// Toggle Featured / Most Ordered status of a Product
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}/ToggleFeatured")]
        public async Task<ActionResult<bool>> ToggleFeatured(int id, [FromQuery] bool? isFeatured = null)
        {
            var item = await _service.FindAsync(id);
            if (item == null) return NotFound();

            var newFeatured = isFeatured ?? !item.IsFeatured;
            item.IsFeatured = newFeatured;
            _service.Update(item);
            await _uow.SaveChangesAsync();

            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove($"Product-{id}");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("ProductCategories");
            _cache.Remove("PopularProductsCache");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Products",
                    Action = newFeatured ? "Feature" : "Unfeature",
                    EntityType = "Product",
                    EntityId = id.ToString(),
                    Description = $"{(newFeatured ? "تمييز" : "إلغاء تمييز")} المنتج (الأكثر طلباً): {item.Title}",
                    Result = "Success"
                });
            }

            return item.IsFeatured;
        }

        public static (decimal SalePrice, decimal? SalePriceUsd, decimal DiscountAmount, decimal? OriginalPriceUsd)
            CalculateDiscountPricing(
                decimal originalPriceLocal,
                decimal? originalPriceUsd,
                decimal discountPercent,
                decimal usdRate,
                decimal profitOutOfMerchantPricePercent)
        {
            var hasUsdPrice = originalPriceUsd.HasValue && originalPriceUsd.Value > 0m;
            if (hasUsdPrice && usdRate <= 0m)
                throw new InvalidOperationException("سعر صرف الدولار غير صالح.");
            var exactBaseLocal = hasUsdPrice ? originalPriceUsd.Value * usdRate : originalPriceLocal;
            var quote = MerchantProductPricing.Calculate(exactBaseLocal, profitOutOfMerchantPricePercent, discountPercent);
            // The merchant quote is never reduced. Savings come out of platform markup.
            return (quote.MerchantPrice, hasUsdPrice ? originalPriceUsd : null, quote.Discount,
                discountPercent > 0m && hasUsdPrice ? originalPriceUsd : null);
        }
    }
}
