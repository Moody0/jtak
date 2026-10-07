using App.ApiModels;
using App.Catalog.Data;
using App.Shared.Entities.Enums;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Globalization;
using System.Linq;
using System.Linq.Dynamic.Core;
using System.Threading.Tasks;
using App.Shared.Services;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    public class ProductCategoriesController : SolApiController
    {
        private readonly IProductCategoryService _service;
        private readonly ICatalogUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IMemoryCache _cache;
        private readonly IAdminAuditService _auditService;

        public ProductCategoriesController(IProductCategoryService service,
            ICatalogUnitOfWork unitOfWork,
            ILogger<ProductCategoriesController> logger, IMapper mapper, IMemoryCache cache,
            IAdminAuditService auditService = null)
        {
            _service = service;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
            _cache = cache;
            _auditService = auditService;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of ProductCategories
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<ProductCategoryDto>>> DataTable(
            [FromBody] MetronicTable request,
            [FromQuery] string level = null, [FromQuery] int? parentId = null, [FromQuery] bool? active = null)
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            return await _service.ListMetronicTableQueryable(request, x => new ProductCategoryDto
            {
                Id = x.Id, Title = x.Title, ParentId = x.ParentId, Active = x.Active, Icon = x.Icon, Order = x.Order
            }, x => x.DeletionDate == null &&
                (level != "root" || x.ParentId == null) && (level != "sub" || x.ParentId != null) &&
                (!parentId.HasValue || x.ParentId == parentId.Value) && (!active.HasValue || x.Active == active.Value));
        }

        /// <summary>
        /// Create a new ProductCategory
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(ProductCategoryDto item)
        {
            var validationError = await ValidateCategoryAsync(0, item);
            if (validationError != null) return BadRequest(ApiErr.Create(validationError));
            item.Title = item.Title.Trim();
            var entity = new ProductCategory { Icon = item.Icon, Title = item.Title, ParentId = item.ParentId, Active = item.Active, Order = item.Order };
            _service.Insert(entity);
            await _unitOfWork.SaveChangesAsync();

            _logger.LogInformation("Created New {0}", entity.GetType().Name);

            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("VisibleProductCategoryIds");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Catalog",
                    Action = "CreateCategory",
                    EntityType = "ProductCategory",
                    EntityId = entity.Id.ToString(),
                    Description = $"إضافة تصنيف جديد: {entity.Title}",
                    Result = "Success",
                    AfterState = new { entity.Id, entity.Title, entity.ParentId, entity.Active, entity.Order }
                });
            }

            return entity.Id;
        }

        /// <summary>
        /// Get a ProductCategories
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<ProductCategoryDto>> Get(int id)
        {
            var x = await _service.Queryable()
                                  .FirstOrDefaultAsync(x => x.DeletionDate == null && x.Id == id);

            if (x == null)
                return NotFound();

            return new ProductCategoryDto
            {
                Id = x.Id,
                Active = x.Active,
                ParentId = x.ParentId,
                Title = x.Title,
                Icon = x.Icon,
                Order = x.Order
            };
        }

        /// <summary>
        /// Get a list of all ProductCategories
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        public async Task<ProductCategoryDto[]> Get(bool root = false, bool includeInactive = false)
        {
            var list = await _service.Queryable()
                                     .Where(x => x.DeletionDate == null && (includeInactive || x.Active) && root == (x.ParentId == null))
                                     .OrderBy(x => x.Order)
                                     .Select(x => _mapper.Map<ProductCategoryDto>(x))
                                     .ToArrayAsync();
            return list;
        }

        /// <summary>
        /// Edit a ProductCategory
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, ProductCategoryDto item)
        {
            var validationError = await ValidateCategoryAsync(id, item);
            if (validationError != null) return BadRequest(ApiErr.Create(validationError));
            var entity = await _service.FindAsync(id);
            if (entity == null)
                return BadRequest(ApiErr.Create("Not Found"));

            var beforeState = new
            {
                entity.Id,
                entity.Title,
                entity.ParentId,
                entity.Active,
                entity.Order
            };

            entity.Title = item.Title.Trim();
            entity.Icon = item.Icon;
            entity.ParentId = item.ParentId;
            entity.Active = item.Active;
            entity.Order = item.Order;

            _service.Update(entity);
            await _unitOfWork.SaveChangesAsync();
            _logger.LogInformation("Edited ProductCategory {0} #{1}", entity.GetType().Name, entity.Id);

            await InvalidateCategoryProductsAsync(id);
            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("VisibleProductCategoryIds");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Catalog",
                    Action = "EditCategory",
                    EntityType = "ProductCategory",
                    EntityId = entity.Id.ToString(),
                    Description = $"تعديل التصنيف: {entity.Title}",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = new
                    {
                        entity.Id,
                        entity.Title,
                        entity.ParentId,
                        entity.Active,
                        entity.Order
                    }
                });
            }

            return entity.Id;
        }


        /// <summary>
        /// Edit a ProductCategory
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            using var transaction = await _unitOfWork.Context.Database
                .BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var entity = await _service.Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null)
                return BadRequest(ApiErr.Create("Not Found"));

            // Include deleted descendants when checking references: deleting a
            // category must never hide a remaining product in its subtree.
            var rows = await _service.Queryable().Select(x => new { x.Id, x.ParentId }).ToArrayAsync();
            var ids = new System.Collections.Generic.HashSet<int> { id };
            bool added;
            do
            {
                added = false;
                foreach (var row in rows)
                    if (row.ParentId.HasValue && ids.Contains(row.ParentId.Value)) added |= ids.Add(row.Id);
            } while (added);

            var blockingCategories = await _service.Queryable().Where(x => ids.Contains(x.Id))
                .Select(x => new { x.Title, ProductCount = x.Products.Count(p => p.DeletionDate == null) })
                .Where(x => x.ProductCount > 0).ToArrayAsync();
            if (blockingCategories.Length > 0)
            {
                var reason = "لا يمكن حذف التصنيف لوجود منتجات مرتبطة به أو بتصنيفاته الفرعية: " +
                    string.Join("، ", blockingCategories.Select(x => $"{x.Title} ({x.ProductCount})")) +
                    ". يشمل ذلك المنتجات المعطلة أو غير الظاهرة للعملاء. انقلها إلى تصنيف آخر أولاً.";
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Catalog",
                        Action = "DeleteCategory",
                        EntityType = "ProductCategory",
                        EntityId = id.ToString(),
                        Description = $"فشل حذف التصنيف {entity.Title} لاحتوائه على منتجات",
                        Result = "Failed",
                        FailureReason = reason
                    });
                }
                return BadRequest(ApiErr.Create(reason));
            }

            var categoriesToDelete = await _service.Queryable()
                .Where(x => ids.Contains(x.Id) && x.DeletionDate == null).ToArrayAsync();
            foreach (var category in categoriesToDelete) _service.Delete(category);
            await _unitOfWork.SaveChangesAsync();
            await transaction.CommitAsync();
            _logger.LogInformation("Deleted ProductCategory {0} #{1}", entity.GetType().Name, entity.Id);

            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");
            _cache.Remove("VisibleProductCategoryIds");

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Catalog",
                    Action = "DeleteCategory",
                    EntityType = "ProductCategory",
                    EntityId = id.ToString(),
                    Description = $"حذف التصنيف وتصنيفاته الفرعية الفارغة: {entity.Title}",
                    Result = "Success",
                    BeforeState = categoriesToDelete.Select(x => new { x.Id, x.Title, x.ParentId }).ToArray()
                });
            }

            return true;
        }

        private async Task InvalidateCategoryProductsAsync(int id)
        {
            var rows = await _service.Queryable().Select(x => new { x.Id, x.ParentId }).ToArrayAsync();
            var ids = new System.Collections.Generic.HashSet<int> { id };
            bool added;
            do {
                added = false;
                foreach (var row in rows)
                    if (row.ParentId.HasValue && ids.Contains(row.ParentId.Value)) added |= ids.Add(row.Id);
            } while (added);
            var products = await _service.Queryable().Where(x => ids.Contains(x.Id))
                .SelectMany(x => x.Products).Select(x => new { x.Id, MerchantIds = x.MerchantProducts.Select(mp => mp.MerchantId).ToArray() }).ToArrayAsync();
            foreach (var product in products) {
                _cache.Remove($"Product-{product.Id}");
                _cache.Remove($"ProductPrices_{product.Id}");
                foreach (var mid in product.MerchantIds) {
                    _cache.Remove($"MerchantProduct_{mid}_{product.Id}");
                    _cache.Remove($"ActiveMerchantPrices_{mid}");
                    _cache.Remove($"AllMerchantPrices_{mid}");
                }
            }
            _cache.Remove("PopularProductsCache");
        }

        private async Task<string> ValidateCategoryAsync(int id, ProductCategoryDto item)
        {
            if (string.IsNullOrWhiteSpace(item?.Title)) return "اسم التصنيف مطلوب.";
            if (item.Order < 0) return "ترتيب التصنيف لا يمكن أن يكون سالباً.";
            if (item.ParentId == 0) item.ParentId = null;
            var visited = new System.Collections.Generic.HashSet<int>();
            var parentId = item.ParentId;
            while (parentId.HasValue)
            {
                if (parentId.Value == id || !visited.Add(parentId.Value))
                    return "لا يمكن وضع التصنيف داخل نفسه أو داخل أحد تصنيفاته الفرعية.";
                var parent = await _service.Queryable().AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == parentId.Value && x.DeletionDate == null);
                if (parent == null) return "التصنيف الرئيسي المحدد غير موجود.";
                parentId = parent.ParentId;
            }
            return null;
        }
    }
}
