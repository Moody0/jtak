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
using System.Globalization;
using System.Linq;
using System.Linq.Dynamic.Core;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class ProductCategoriesController : SolApiController
    {
        private readonly IProductCategoryService _service;
        private readonly ICatalogUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IMemoryCache _cache;

        public ProductCategoriesController(IProductCategoryService service,
            ICatalogUnitOfWork unitOfWork,
            ILogger<ProductCategoriesController> logger, IMapper mapper, IMemoryCache cache)
        {
            _service = service;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
            _cache = cache;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of ProductCategories
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<ProductCategoryDto>>> DataTable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new ProductCategoryDto
            {
                Id = x.Id,
                Title = x.Title,
                ParentId = x.ParentId,
                Active = x.Active,
                Icon = x.Icon,
                Order = x.Order
            });

            return list;
        }

        /// <summary>
        /// Create a new ProductCategory
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(ProductCategoryDto item)
        {
            var entity = new ProductCategory { Icon = item.Icon, Title = item.Title, ParentId = item.ParentId, Active = item.Active, Order = item.Order };
            _service.Insert(entity);
            await _unitOfWork.SaveChangesAsync();

            _logger.LogInformation("Created New {0}", entity.GetType().Name);

            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");

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
                                  .FirstOrDefaultAsync(x => x.Active && x.Id == id);

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
                                     .Where(x => (includeInactive || x.Active) && root == (x.ParentId == null))
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
            var entity = await _service.FindAsync(id);
            if (entity == null)
                return BadRequest(ApiErr.Create("Not Found"));

            entity.Title = item.Title;
            entity.Icon = item.Icon;
            entity.ParentId = item.ParentId;
            entity.Active = item.Active;
            entity.Order = item.Order;

            _service.Update(entity);
            await _unitOfWork.SaveChangesAsync();
            _logger.LogInformation("Edited ProductCategory {0} #{1}", entity.GetType().Name, entity.Id);

            _cache.Remove("ProductCategories");
            _cache.Remove("ProductCategoriesTree");

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
            var entity = await _service.Queryable().Include(x => x.Products).FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null)
                return BadRequest(ApiErr.Create("Not Found"));

            if (entity.Products.Any())
                return BadRequest(ApiErr.Create("Delete Products First"));

            _service.Delete(entity);
            await _unitOfWork.SaveChangesAsync();
            _logger.LogInformation("Deleted ProductCategory {0} #{1}", entity.GetType().Name, entity.Id);

            return true;
        }
    }
}
