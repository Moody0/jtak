using App.ApiModels;
using App.Extensions;
using App.Shared.Services;
using App.Shared.Services.Domain;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using Modules.Catalog.Services;
using App.Orders.Data;
using App.Shared.Entities.Domain;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class FavoriteProductsController : SolApiController
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IFavoriteProductService _service;
        private readonly IProductService _productService;

        public FavoriteProductsController(IOrdersUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IFavoriteProductService service,
            IProductService productService,
            ILogger<FavoriteProductsController> logger,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _service = service;
            _productService = productService;
        }

        /// <summary>
        /// Add favorite product
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<bool>> Add(int id)
        {
            var uid = User.GetUserId();
            var product = _productService.Queryable().FirstOrDefault(x => x.Id == id && x.DeletionDate == null);
            if (product == null)
            {
                return BadRequest("Not Found!");
            }

            var entity = _service.Queryable().FirstOrDefault(x => x.UserId == uid && x.ProductId == id);

            if (entity == null)
            {
                entity = new FavoriteProduct
                {
                    UserId = uid.Value,

                    ProductId = id,
                    ProductTitle = product.Title,
                    ProductImage = product.Photos
                };
                _service.Insert(entity);
                await _uow.SaveChangesAsync();
            }

            return true;
        }


        /// <summary>
        /// Delete favorite product
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var uid = User.GetUserId();
            await _service.DeleteAsync(new { uid.Value, id });
            await _uow.SaveChangesAsync();
            return true;
        }

        /// <summary>
        /// Get my favorite products
        /// </summary>
        /// <returns></returns>
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [HttpGet]
        [Route("Mine")]
        public async Task<ActionResult<FavoriteProductDto[]>> GetMine()
        {
            var uid = User.GetUserId();
            var products = await _service.Queryable()
                                       .Where(x => x.UserId == uid.Value)
                                       .OrderByDescending(x => x.CreatedDate)
                                       .Select(x => _mapper.Map<FavoriteProductDto>(x))
                                       .ToArrayAsync();

            return products;
        }
    }
}
