using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;
using App.Catalog.Data;
using Solf.Models;
using App.ApiModels.Admin;
using System.IO;
using OfficeOpenXml;
using Microsoft.AspNetCore.Hosting;
using App.Helpers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using URF.Core.Abstractions.Trackable;
using App.Shared.Services;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class ProductsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IProductCategoryService _productCategoryService;
        private readonly ITagService _tagService;
        private readonly ITrackableRepository<MerchantProduct> _merchantProductRepo;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IMemoryCache _cache;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IWebHostEnvironment _env;
        private readonly IAdminAuditService _auditService;

        public ProductsController(IProductService service,
            IProductCategoryService productCategoryService,
            ITagService tagService,
            ITrackableRepository<MerchantProduct> merchantProductRepo,
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
        public async Task<ActionResult<TableResponseModel<ProductDto>>> DataTable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new ProductDto
            {
                Id = x.Id,
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
                MerchantId = x.MerchantProducts.Select(mp => (int?)mp.MerchantId).FirstOrDefault(),
                Merchant = x.MerchantProducts.Select(mp => mp.Merchant != null ? mp.Merchant.Title : string.Empty).FirstOrDefault(),
                MerchantTitle = x.MerchantProducts.Select(mp => mp.Merchant != null ? mp.Merchant.Title : string.Empty).FirstOrDefault(),
                Price = x.MerchantProducts.Select(mp => mp.MerchantPrice).FirstOrDefault(),
                PriceUsd = x.MerchantProducts.Select(mp => mp.PriceUsd).FirstOrDefault()
            }, x => x.DeletionDate == null, x => x.ProductCategory, x => x.MerchantProducts);
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
            var file = _env.ContentRootPath + FileHelper.GetVirtualPath(item.File).Replace("/", "\\").Replace("~", "");
            BulkImportDesc result = new();
            ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
            using (var package = new ExcelPackage(new FileInfo(file)))
            {
                if (!package.Workbook.Worksheets.Any())
                {
                    return BadRequest("Invalid file");
                }

                var cat1Sheet = package.Workbook.Worksheets[2];
                var cat2Sheet = package.Workbook.Worksheets[1];
                var productsSheet = package.Workbook.Worksheets[0];

                // Import Cat1
                var allCats = await _productCategoryService.Queryable().ToArrayAsync();
                for (int row = cat1Sheet.Dimension.Start.Row; row <= cat1Sheet.Dimension.End.Row; row++)
                {
                    var cat = new ProductCategory { Title = cat1Sheet.Cells[row, 0].Text, Active = true };
                    if (!allCats.Any(x => x.Title == cat.Title))
                    {
                        result.ImportedCat1++;
                        _productCategoryService.Insert(cat);
                    }
                }
                await _uow.SaveChangesAsync();
                allCats = await _productCategoryService.Queryable().ToArrayAsync();

                // Import Cat2
                for (int row = cat2Sheet.Dimension.Start.Row; row <= cat2Sheet.Dimension.End.Row; row++)
                {
                    var parentTitle = cat2Sheet.Cells[row, 1].Text;
                    var parentCatId = allCats.FirstOrDefault(x => x.Title == parentTitle)?.Id;

                    if (!parentCatId.HasValue)
                        continue;

                    var cat = new ProductCategory { Title = cat2Sheet.Cells[row, 0].Text, Active = true, ParentId = parentCatId.Value };
                    if (!allCats.Any(x => x.Title == cat.Title))
                    {
                        result.ImportedCat2++;
                        _productCategoryService.Insert(cat);
                    }
                }
                await _uow.SaveChangesAsync();
                allCats = await _productCategoryService.Queryable().ToArrayAsync();

                // Import Products
                var allProds = await _service.Queryable().ToArrayAsync();
                for (int row = productsSheet.Dimension.Start.Row; row <= productsSheet.Dimension.End.Row; row++)
                {
                    var catTitle = productsSheet.Cells[row, 1].Text;
                    var catId = allCats.FirstOrDefault(x => x.Title == catTitle)?.Id;

                    if (!catId.HasValue)
                        continue;

                    var prod = new Product { Title = productsSheet.Cells[row, 0].Text, Active = true, ProductCategoryId = catId.Value };
                    if (!allProds.Any(x => x.Title == prod.Title))
                    {
                        result.ImportedProds++;
                        _service.Insert(prod);
                    }
                }
                await _uow.SaveChangesAsync();
            }
            // TODO: Import images from zip?
            return result;
        }

        /// <summary>
        /// Create a new Product
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<int>> Create(ProductDto item)
        {
            var entity = new Product
            {
                Title = item.Title,
                TitleEn = item.TitleEn,
                Barcode = item.Barcode,
                Brand = item.Brand,
                Description = item.Description,
                DescriptionEn = item.DescriptionEn,
                Unit = item.Unit,
                Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null,
                ProductCategoryId = item.ProductCategoryId,
                Active = item.Active,
                IsFeatured = item.IsFeatured,
                Currency = item.Currency
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();

            if (item.MerchantId.HasValue && item.MerchantId.Value > 0)
            {
                _merchantProductRepo.Insert(new MerchantProduct
                {
                    MerchantId = item.MerchantId.Value,
                    ProductId = entity.Id,
                    MerchantPrice = item.Price > 0 ? item.Price : 0,
                    PriceUsd = item.PriceUsd,
                    Discount = item.Discount
                });
                await _uow.SaveChangesAsync();

                _cache.Remove($"ActiveMerchantPrices_{item.MerchantId.Value}");
                _cache.Remove($"AllMerchantPrices_{item.MerchantId.Value}");
                _cache.Remove($"MerchantProduct_{item.MerchantId.Value}_{entity.Id}");
            }

            _cache.Remove($"ProductPrices_{entity.Id}");
            _cache.Remove("ProductCategoriesTree");

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
                        item.Price,
                        item.PriceUsd,
                        item.MerchantId,
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

            var existingMps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == entity.Id).ToListAsync();
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

            entity.Title = item.Title;
            entity.TitleEn = item.TitleEn;
            entity.Barcode = item.Barcode;
            entity.Brand = item.Brand;
            entity.Description = item.Description;
            entity.DescriptionEn = item.DescriptionEn;
            entity.Unit = item.Unit;
            entity.Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null;
            entity.ProductCategoryId = item.ProductCategoryId;
            entity.Active = item.Active;
            entity.IsFeatured = item.IsFeatured;
            entity.Currency = item.Currency;

            // Update MerchantProduct linkage & pricing
            if (item.MerchantId.HasValue && item.MerchantId.Value > 0)
            {
                var targetMp = existingMps.FirstOrDefault(mp => mp.MerchantId == item.MerchantId.Value);
                if (targetMp != null)
                {
                    targetMp.MerchantPrice = item.Price;
                    targetMp.PriceUsd = item.PriceUsd;
                    targetMp.Discount = item.Discount;
                    _merchantProductRepo.Update(targetMp);

                    // Clean up any extraneous merchant links if product is uniquely assigned
                    foreach (var otherMp in existingMps.Where(mp => mp.MerchantId != item.MerchantId.Value))
                    {
                        _merchantProductRepo.Delete(otherMp);
                        _cache.Remove($"ActiveMerchantPrices_{otherMp.MerchantId}");
                        _cache.Remove($"AllMerchantPrices_{otherMp.MerchantId}");
                        _cache.Remove($"MerchantProduct_{otherMp.MerchantId}_{entity.Id}");
                    }
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
                        MerchantId = item.MerchantId.Value,
                        ProductId = entity.Id,
                        MerchantPrice = item.Price > 0 ? item.Price : 0,
                        PriceUsd = item.PriceUsd,
                        Discount = item.Discount
                    });
                }

                _cache.Remove($"ActiveMerchantPrices_{item.MerchantId.Value}");
                _cache.Remove($"AllMerchantPrices_{item.MerchantId.Value}");
                _cache.Remove($"MerchantProduct_{item.MerchantId.Value}_{entity.Id}");
            }
            else
            {
                // Merchant unassigned (pure central catalog draft)
                foreach (var oldMp in existingMps)
                {
                    _merchantProductRepo.Delete(oldMp);
                    _cache.Remove($"ActiveMerchantPrices_{oldMp.MerchantId}");
                    _cache.Remove($"AllMerchantPrices_{oldMp.MerchantId}");
                    _cache.Remove($"MerchantProduct_{oldMp.MerchantId}_{entity.Id}");
                }
            }

            _cache.Remove($"ProductPrices_{entity.Id}");
            _cache.Remove("ProductCategoriesTree");

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
                        MerchantId = item.MerchantId,
                        Price = item.Price,
                        PriceUsd = item.PriceUsd,
                        Discount = item.Discount,
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
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
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

            var entity = new Product
            {
                Title = item.Title,
                Description = item.Description,
                Photos = item.Photos,
                ProductCategoryId = item.ProductCategoryId,
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.TagId).ToArray() ?? Array.Empty<int>());
            _logger.LogInformation("Duplicate New {0}", entity.GetType().Name);

            return entity.Id;
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
            await _uow.SaveChangesAsync();

            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove("ProductCategoriesTree");

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
            await _uow.SaveChangesAsync();

            var mps = await _merchantProductRepo.Queryable().Where(mp => mp.ProductId == id).ToListAsync();
            foreach (var mp in mps)
            {
                _cache.Remove($"ActiveMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"AllMerchantPrices_{mp.MerchantId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{id}");
            }
            _cache.Remove($"ProductPrices_{id}");
            _cache.Remove("ProductCategoriesTree");

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
    }
}
