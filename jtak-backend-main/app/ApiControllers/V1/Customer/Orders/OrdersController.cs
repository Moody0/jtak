using App.ApiModels;
using App.Extensions;
using App.Shared.Services;
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
using Modules.Orders.Entities;
using App.Orders.Data;
using App.Shared.Entities.Enums;
using App.Shared.Services.Extentions;
using Solf.Models;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using Modules.Catalog.Services;
using System.Collections.Generic;

namespace App.ApiControllers.V1.Customer.Orders
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.CustomerPermission))]
    public class OrdersController : SolApiController
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly UserManager<AppUser> _userManager;
        private readonly INotificationService _notificationService;
        private readonly IMerchantService _merchantService;
        private readonly IDeliveryService _deliveryService;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IOrderService _service;

        public OrdersController(IOrdersUnitOfWork unitOfWork,
            UserManager<AppUser> userManager,
            INotificationService notificationService,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IOrderService service,
            ILogger<OrdersController> logger,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _service = service;
        }

        /// <summary>
        /// Get My Orders
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<OrderDto>>> GetMine([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var orders = await _service.ListMetronicTable(request,
                x => new OrderDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    DeliveryId = x.DeliveryId,
                    DeliveryUser = x.DeliveryUser,
                    DeliveryLat = x.DeliveryLat,
                    DeliveryLng = x.DeliveryLng,
                    DeliveryLocationUpdatedAt = x.DeliveryLocationUpdatedAt,
                    Description = x.Description,
                    Phonenumber = x.Phonenumber,
                    OrderStatus = x.OrderStatus,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = x.User,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Address = x.Address,
                    OrderDetails = x.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                    .Select(d => new OrderDetailDto
                                    {
                                        Id = d.Id,
                                        Quantity = d.Quantity,
                                        ProductId = d.ProductId,
                                        ProductTitle = d.ProductTitle,
                                        ProductUnit = d.ProductUnit,
                                        ProductImage = d.ProductImage,
                                        MerchantId = d.MerchantId,
                                        MerchantTitle = d.MerchantTitle,
                                        SinglePrice = d.SinglePrice,
                                        SingleFinalPrice = d.SingleFinalPrice,
                                        Currency = d.Currency,
                                        OrderId = d.OrderId,
                                        OrderDetailStatus = d.OrderDetailStatus
                                    }).ToArray()
                }, x => x.UserId == uid.Value && x.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) &&
                x.OrderStatus == OrderStatus.Success, x => x.OrderDetails);
            return orders;
        }

        /// <summary>
        /// Get My Signle order
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<OrderDto>> Get(int id)
        {
            var uid = User.GetUserId();
            var order = await _service.Queryable().Include(x => x.OrderDetails)
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == uid.Value && x.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) && x.OrderStatus == OrderStatus.Success);

            if (order == null)
                return NotFound();

            var result = new OrderDto
            {
                Id = order.Id,
                UserId = order.UserId,
                DeliveryId = order.DeliveryId,
                DeliveryUser = order.DeliveryUser,
                DeliveryLat = order.DeliveryLat,
                DeliveryLng = order.DeliveryLng,
                DeliveryLocationUpdatedAt = order.DeliveryLocationUpdatedAt,
                Description = order.Description,
                Phonenumber = order.Phonenumber,
                OrderStatus = order.OrderStatus,
                PurchaseDate = order.PurchaseDate,
                CreatedDate = order.CreatedDate,
                User = order.User,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                OrderDetails = order.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                    .Select(d => new OrderDetailDto
                                    {
                                        Id = d.Id,
                                        Quantity = d.Quantity,
                                        ProductId = d.ProductId,
                                        ProductTitle = d.ProductTitle,
                                        ProductUnit = d.ProductUnit,
                                        ProductImage = d.ProductImage,
                                        MerchantId = d.MerchantId,
                                        MerchantTitle = d.MerchantTitle,
                                        SinglePrice = d.SinglePrice,
                                        SingleFinalPrice = d.SingleFinalPrice,
                                        Currency = d.Currency,
                                        OrderId = d.OrderId,
                                        OrderDetailStatus = d.OrderDetailStatus
                                    }).ToArray()
            };
            return result;
        }

        [HttpPost]
        [Route("AcceptChange/{id}")]
        public async Task<ActionResult<bool>> AcceptChange(int id)
        {
            var order = await _service.CustomerAcceptOrderChange(id, User.GetUserId());

            // Notify new merchants
            var merchantOrders = order.OrderDetails.GroupBy(x => x.MerchantId).ToArray();
            foreach (var merchantOrder in merchantOrders)
            {
                var ownerId = await _merchantService.GetOwnerId(merchantOrder.Key);
                var details = merchantOrder.ToArray();
                await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, order.Id, details);
            }
            return true;
        }

        [HttpPost]
        [Route("Cancel/{id}")]
        public async Task<ActionResult<bool>> CustomerCancel(int id)
        {
            var order = await _service.CustomerCancelOrder(id, User.GetUserId());
            
            // No need to update bills or balances as it is not yet created!
            // Notify all related merchants about canceled order
            var merchantIds = order.OrderDetails.Select(x => x.MerchantId).ToArray().Distinct();
            foreach (var merchantId in merchantIds)
            {
                var ownerId = await _merchantService.GetOwnerId(merchantId);
                await _notificationService.SendOrderCanceled(new[] { ownerId }, id, order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray());
            }
            return true;
        }
        //[HttpPost]
        //[Route("TestAcceptChange/{id}")]
        //[AllowAnonymous]
        //public async Task<ActionResult<bool>> TestAcceptChange(int id)
        //{
        //    var order = await _service.CustomerAcceptOrderChange(id);
        //
        //    // Notify new merchants
        //    var merchantOrders = order.OrderDetails.GroupBy(x => x.MerchantId).ToArray();
        //    foreach (var merchantOrder in merchantOrders)
        //    {
        //        var ownerId = await _merchantService.GetOwnerId(merchantOrder.Key);
        //        var details = merchantOrder.ToArray();
        //        await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, order.Id, details);
        //    }
        //    return true;
        //}
        //
        //[HttpPost]
        //[Route("TestCancel/{id}")]
        //[AllowAnonymous]
        //public async Task<ActionResult<bool>> TestCustomerCancel(int id)
        //{
        //    var order = await _service.CustomerCancelOrder(id);
        //
        //    var merchantIds = order.OrderDetails.Select(x => x.MerchantId).ToArray().Distinct();
        //    foreach (var merchantId in merchantIds)
        //    {
        //        var ownerId = await _merchantService.GetOwnerId(merchantId);
        //        await _notificationService.SendOrderCanceled(new[] { ownerId }, id, order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray());
        //    }
        //    return true;
        //}
    }
}
