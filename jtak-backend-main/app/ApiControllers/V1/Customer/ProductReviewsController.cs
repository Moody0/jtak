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
using App.Shared.Services.eCommerce;
using App.Shared.Services.Extentions;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class ProductReviewsController : SolApiController
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IProductService _productService;
        private readonly IProductReviewService _service;
        private readonly IOrderDetailService _orderDetailService;

        public ProductReviewsController(IOrdersUnitOfWork unitOfWork,
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
        /// Create or updates product review
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(ProductReviewDto model)
        {
            var uid = User.GetUserId();
            var product = _productService.Queryable().FirstOrDefault(x => x.Id == model.ProductId && x.DeletionDate == null);
            if (product == null)
            {
                return BadRequest("Not Found!");
            }
            var entity = _service.Queryable().FirstOrDefault(x => x.ReviewerId == uid && x.ProductId == model.ProductId);

            if (entity == null)
            {
                entity = new ProductReview
                {
                    ReviewerId = uid.Value,

                    ImageReview = model.ImageReview,
                    TextReview = model.TextReview,

                    ProductId = model.ProductId,
                    ProductTitle = product.Title,
                    ProductImage = product.Photos,

                    Rate = model.Rate
                };
                _service.Insert(entity);
            }
            else
            {
                entity.ReviewerId = uid.Value;

                entity.ImageReview = model.ImageReview;
                entity.TextReview = model.TextReview;

                entity.ProductId = model.ProductId;
                entity.ProductTitle = product.Title;
                entity.ProductImage = product.Photos;

                entity.Rate = model.Rate;
            }
            await _uow.SaveChangesAsync();
            return entity.Id;
        }

        /// <summary>
        /// Create or updates order review
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("{id}")]
        public async Task<ActionResult<int>> Create(int orderId, CreateOrderReview model)
        {
            var uid = User.GetUserId();
            var orderDetails = await _orderDetailService.Queryable()
                                                  .Include(x => x.Order)
                                                  .Where(x => x.OrderId == model.OrderId && x.Order.UserId == uid)
                                                  .ToArrayAsync();

            var reviews = orderDetails.Select(x => new ProductReview
            {
                ReviewerId = uid.Value,

                //ImageReview = model.ImageReview,
                TextReview = model.TextReview,

                ProductId = x.Id,
                ProductTitle = x.ProductTitle,
                ProductImage = x.ProductImage,

                Rate = model.Rate
            });
            _service.Insert(reviews);

            await _uow.SaveChangesAsync();
            return reviews.Count();
        }


        /// <summary>
        /// Delete product review
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

        /// <summary>
        /// Get my product reviews
        /// </summary>
        /// <returns></returns>
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [HttpGet]
        [Route("Mine")]
        public async Task<ActionResult<ProductReviewDto[]>> GetMine()
        {
            var uid = User.GetUserId();
            var orders = await _service.Queryable()
                                       .Where(x => x.ReviewerId == uid.Value)
                                       .OrderByDescending(x => x.CreatedDate)
                                       .Select(x => _mapper.Map<ProductReviewDto>(x))
                                       .ToArrayAsync();

            return orders;
        }
    }
}
