using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.Domain;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using Modules.Catalog.Services;
using App.Shared.Entities.Domain;
using App.Shared.Services.eCommerce;
using System.Globalization;
using Solf.Models;
using App.Shared.Entities.Enums;
using App.Shared.Data.App;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    [ApiVersion("1")]
    public class ProductReviewsController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IProductService _productService;
        private readonly IProductReviewService _service;
        private readonly IOrderDetailService _orderDetailService;

        public ProductReviewsController(IAppUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IProductService productService,
            IOrderDetailService orderDetailService,
            IProductReviewService service,
            ILogger<ProductReviewsController> logger,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _productService = productService;
            _orderDetailService = orderDetailService;
            _service = service;
        }


        /// <summary>
        /// Get product reviews
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Datatable")]
        public async Task<ActionResult<TableResponseModel<ProductReviewDto>>> Datatable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new ProductReviewDto
            {
                Id = x.Id,
                ProductTitle = x.ProductTitle,
                ProductImage = x.ProductImage,
                Rate = x.Rate,
                TextReview = x.TextReview,
            });
            return list;
        }
    }
}
