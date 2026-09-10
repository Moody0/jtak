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
        private readonly ICatalogUnitOfWork _uow;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IWebHostEnvironment _env;

        public ProductsController(IProductService service, IProductCategoryService productCategoryService, ITagService tagService, ICatalogUnitOfWork uow, IMapper mapper, IWebHostEnvironment env, ILogger<ProductsController> logger)
        {
            _env = env;
            _service = service;
            _productCategoryService = productCategoryService;
            _tagService = tagService;
            _uow = uow;
            _logger = logger;
            _mapper = mapper;
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
                Unit = x.Unit,
                Description = x.Description,
                Photos = x.Photos,
                Currency = x.Currency,
                ExpiryDate = x.ExpiryDate,
                IsFeatured = x.IsFeatured,
                ProductCategoryId = x.ProductCategoryId,
                ProductCategory = x.ProductCategory.Title,
                Active = x.Active
            }, x => true, x => x.ProductCategory);
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
                Description = item.Description,
                Unit = item.Unit,
                Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null,
                ProductCategoryId = item.ProductCategoryId,
                Active = item.Active
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.Id).ToArray() ?? Array.Empty<int>());
            _logger.LogInformation("Created New {0}", entity.GetType().Name);

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

            entity.Title = item.Title;
            entity.Description = item.Description;
            entity.Unit = item.Unit;
            entity.Photos = item.Photos != null ? string.Join(",", item.Photos.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)) : null;
            entity.ProductCategoryId = item.ProductCategoryId;
            entity.Active = item.Active;

            await _tagService.SetTags(entity.Id, item.Tags?.Select(x => x.Id).ToArray() ?? Array.Empty<int>());

            await _uow.SaveChangesAsync();

            return entity.Id;
        }

        /// <summary>
        /// Delete Product
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
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
            item.Active = true;
            await _uow.SaveChangesAsync();
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
            item.Active = false;
            await _uow.SaveChangesAsync();
            return true;
        }
    }
}
