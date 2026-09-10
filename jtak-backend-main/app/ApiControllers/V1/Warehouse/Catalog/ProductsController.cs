using App.Catalog.Data;
using App.Shared.Entities;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
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
    public class ProductsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IMerchantService _merchantService;
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
                Description = x.Description,
                ProductCategory = x.ProductCategory.Title,
                Photos = x.Photos,
                ProductCategoryId = x.ProductCategoryId
            }, x => true, x => x.ProductCategoryId);

            return list;
        }


        /// <summary>
        /// SetPrices of a Merchant (Merchant Price)
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Prices")]
        public async Task<ActionResult<int>> SetPrices(int mid, [FromBody] MerchantProductPriceDto[] products)
        {
            var mids = await _merchantService.GetMerchantIds(User.GetUserId().Value);
            var result = await _merchantService.SetMerchantProductPrices(mids, products);



            return result;
        }

        /// <summary>
        /// Get all Products, including the ones linked to this Merchant
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<MerchantProductDto[]>> Get()
        {
            var products = await _service.Queryable()
                                   .Include(x => x.MerchantProducts)
                                   .Include(x => x.ProductCategory)
                                   .ThenInclude(x => x.Parent)
                                   .Where(x => x.DeletionDate == null && x.ProductCategory.Active && x.Active)
                                   .OrderBy(x => x.ProductCategory.Order)
                                      .Select(x => new MerchantProductDto
                                      {
                                          ProductId = x.Id,
                                          Product = x.Title,
                                          ProductCat1 = x.ProductCategory != null ? x.ProductCategory.Title : "",
                                          ProductCat2 = x.ProductCategory != null && x.ProductCategory.Parent != null ? x.ProductCategory.Parent.Title : "",
                                          ProductPhotos = x.Photos
                                      })
                                      .ToArrayAsync();

            var mids = await _merchantService.GetMerchantIds(User.GetUserId().Value);
            foreach (var mid in mids)
            {
                var mps = await _merchantService.GetActiveMerchantPrices(mid);

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
            }

            return products.Where(x => x.MerchantId != 0).ToArray();
        }

        /// <summary>
        /// Get a specific Product by id
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [AllowAnonymous]
        public async Task<ActionResult<ProductDto>> Get(int id)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var item = await _service.FindAsync(id);
            var user = await _userManager.GetUserAsync(User);
            var isAdmin = user != null ? await _userManager.IsInRoleAsync(user, AppRoleName.Admin.ToString()) : false;
            if (item == null || !isAdmin && (!item.Active || !item.ProductCategory.Active))
                return NotFound();

            var model = _mapper.Map<ProductDto>(item);
            model.Tags = item.Tags.Select(x => _mapper.Map<TagDto>(x.Tag)).ToArray();
            model.ProductCategory = item.ProductCategory?.Title;
            return model;
        }
    }
}
