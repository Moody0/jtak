using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using System.Linq;
using App.Shared.Services.Extentions;
using App.Shared.Entities.Enums;
using Modules.Orders.Entities;
using App.Shared.Entities;
using Solf.Models;
using System;
using Modules.Catalog.Services;
using System.Collections.Generic;
using App.Extensions;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using App.Orders.Data;
using Modules.Shipping.Entities;

namespace App.ApiControllers.V1.Warehouse
{
    [Route("api/v{version:apiVersion}/Warehouse/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]
    public class OrdersController : SolApiController
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly IMapper _mapper;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMerchantService _merchantService;
        private readonly IOrderService _service;
        private readonly IProductService _productService;
        private readonly IDeliveryService _deliveryService;
        private readonly IOrderDetailService _orderDetailService;

        public OrdersController(IOrdersUnitOfWork unitOfWork,
            UserManager<AppUser> userManager,
            INotificationService notificationService,
            IMerchantService merchantService,
            IOrderService service,
            IProductService productService,
            IOrderDetailService orderDetailService,
            IDeliveryService deliveryService,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _notificationService = notificationService;
            _userManager = userManager;
            _mapper = mapper;
            _merchantService = merchantService;
            _service = service;
            _productService = productService;
            _orderDetailService = orderDetailService;
            _deliveryService = deliveryService;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Orders
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<OrderDto>>> PostMine([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var threeDaysAgo = DateTime.UtcNow.AddDays(-3);
            var orders = await _service.ListMetronicTableQueryable(request,
                x => new OrderDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    Description = x.Description,
                    Phonenumber = x.Phonenumber,
                    OrderStatus = x.OrderStatus,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = x.User,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Address = x.Address,
                    PaymentMethod = x.PaymentMethod,
                    OrderDetails = x.OrderDetails.Where(d => mids.Contains(d.MerchantId) && d.OrderDetailStatus != OrderDetailStatus.MerchantRejected && d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).Select(d => d.ToDto()).ToArray()
                }, x =>
                x.OrderDetails.Any(d => mids.Contains(d.MerchantId) && d.OrderDetailStatus != OrderDetailStatus.MerchantRejected && d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                && x.OrderStatus == OrderStatus.Success
                && x.PurchaseDate > threeDaysAgo, x => x.OrderDetails);
            return orders;
        }

        [HttpPost]
        [Route("Accept/{id}")]
        public async Task<ActionResult<bool>> MerchantAccept(int id)
        {
            var merchantIds = await _merchantService.GetMerchantIds(User.GetUserId().Value);
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var actionableDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();
            var willCompleteApproval = !currentOrder.DeliveryId.HasValue &&
                actionableDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted ||
                                           (merchantIds.Contains(x.MerchantId) &&
                                            x.OrderDetailStatus == OrderDetailStatus.Pending));

            var allMerchantStops = Array.Empty<(decimal Lat, decimal Lng, int MerchantId)>();
            (Guid Id, int Distance) bestDelivery = default;
            if (willCompleteApproval)
            {
                var orderMerchantIds = actionableDetails.Select(x => x.MerchantId).Distinct().ToArray();
                allMerchantStops = await _merchantService.GetMerchantStops(orderMerchantIds);
                bestDelivery = await _deliveryService.PickBestDelivery(allMerchantStops);
            }

            var order = await _service.MerchantAccept(id, merchantIds);

            var allAccepted = order.OrderDetails
                                   .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                                   .All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);

            if (allAccepted && !order.DeliveryId.HasValue && bestDelivery.Id != default)
            {
                order.DeliveryId = bestDelivery.Id;
                order.DeliveryUser = await _userManager.Users.Where(x => x.Id == order.DeliveryId).Select(x => x.FullName).FirstOrDefaultAsync();
                order.DeliveryLat = null;
                order.DeliveryLng = null;
                order.DeliveryLocationUpdatedAt = null;
                await _uow.SaveChangesAsync();

                var customerSO = new ShippingOrderDto { OrderId = order.Id, DriverId = order.DeliveryId.Value, MerchantId = null, CustomerId = order.UserId, Lat = order.Lat, Lng = order.Lng };
                var merchantsSOs = allMerchantStops.Select(x => new ShippingOrderDto
                {
                    OrderId = order.Id,
                    DriverId = order.DeliveryId.Value,
                    MerchantId = x.MerchantId,
                    CustomerId = order.UserId,
                    Lat = x.Lat,
                    Lng = x.Lng,
                }).ToArray();

                await _deliveryService.AddOrder(bestDelivery.Id, id, merchantsSOs, customerSO);

                // Sending Notification will save to DB
                await _notificationService.SendDeliveryNewOrderRecived(new[] { bestDelivery.Id }, id, order.OrderDetails.ToArray());
            }
            return true;
        }

        [HttpPost]
        [Route("Reject/{id}")]
        public async Task<ActionResult<bool>> MerchantReject(int id)
        {
            var userId = User.GetUserId();
            var merchantIds = await _merchantService.GetMerchantIds(User.GetUserId().Value);

            var order = await _service.FindAsync(id);

            var customerIds = new[] { order.UserId };

            var merchantOrderDetails = order.OrderDetails.Where(x => merchantIds.Contains(x.MerchantId)).ToArray();

            // If was rejected before : notify customer order failed
            var wasRejectedBefore = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.MerchantRejected);
            if (wasRejectedBefore)
            {
                foreach (var item in order.OrderDetails)
                {
                    item.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
                }
                await _uow.SaveChangesAsync();
                await _notificationService.SendCustomerOrderItemsNotFound(customerIds, id, order.OrderDetails.ToArray());
                return true;
            }

            // Update Merchant Order Detail Statuses
            foreach (var merchantOrderdetail in merchantOrderDetails)
            {
                merchantOrderdetail.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
            }
            _service.Log(id, OrderDetailStatus.MerchantRejected, merchantOrderDetails);
            await _uow.SaveChangesAsync();

            // Add Alternative Merchant Order Details (from other merchant products)
            var pids = merchantOrderDetails.Select(x => x.ProductId).ToArray();
            var alternativeOrderDetails = new List<OrderDetail>();
            foreach (var item in merchantOrderDetails)
            {
                string warning = null;

                var p = await _productService.GetProduct(item.ProductId);
                var alternative = await _merchantService.GetBestAlternativeProductPrice(item.ProductId, merchantIds, order.Lat, order.Lng);
                var alternativeOptionAvailable = p != null && alternative != null;
                if (!alternativeOptionAvailable)
                {
                    warning = $"!للأسف، هذا المنتج لم يعد متوفرا" + Environment.NewLine;
                }
                //else if (item.SingleFinalPrice > 0 && alternative.FinalPrice != item.SingleFinalPrice)
                //{
                //    warning += $"لقد تغير سعر هذا المنتج من {item.SingleFinalPrice} إلى {alternative.FinalPrice}";
                //}
                alternativeOrderDetails.Add(new OrderDetail
                {
                    Quantity = item.Quantity,
                    ProductId = p?.Id ?? item.Id,
                    ProductTitle = p?.Title ?? item.ProductTitle,
                    ProductUnit = p?.Unit ?? item.ProductUnit,
                    ProductImage = p?.Photos ?? item.ProductImage,
                    MerchantId = alternative?.MerchantId ?? item.MerchantId,
                    MerchantTitle = item.MerchantTitle,
                    SinglePrice = alternative?.Price ?? item.SinglePrice,
                    SingleFinalPrice = alternative?.FinalPrice ?? item.SingleFinalPrice,
                    OrderId = id,
                    Warning = warning,
                    OrderDetailStatus = alternativeOptionAvailable ? OrderDetailStatus.CustomerPending : OrderDetailStatus.DeliveryCanceled
                });
            }
            var alternativeOptionsAvailable = alternativeOrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.CustomerPending);
            if (alternativeOptionsAvailable)
            {
                _orderDetailService.Insert(alternativeOrderDetails);
                await _uow.SaveChangesAsync();
                var details = order.OrderDetails.ToArray();
                await _notificationService.SendCustomerOrderItemsChanged(customerIds, id, details);

                // Notify Customer: Ordered Items Changed
                // TODO: Notify Customer: Ordered Items removed?
            }

            return true;
        }

        /// <summary>
        /// Get My Signle order
        /// </summary>
        /// 
        /// <returns></returns>
        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<OrderDto>> Get(int id)
        {
            var uid = User.GetUserId();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var order = await _service.Queryable()
                                      .Include(x => x.OrderDetails)
                                      .FirstOrDefaultAsync(x => x.Id == id &&
                                      x.OrderDetails.Any(d =>
                                      mids.Contains(d.MerchantId) &&
                                      d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                      d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                      d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled) &&
                                      x.OrderStatus == OrderStatus.Success);
            //x.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected) && x.OrderStatus == OrderStatus.Success);

            if (order == null)
                return NotFound();

            var result = new OrderDto
            {
                Id = order.Id,
                UserId = order.UserId,
                Description = order.Description,
                Phonenumber = order.Phonenumber,
                OrderStatus = order.OrderStatus,
                PurchaseDate = order.PurchaseDate,
                CreatedDate = order.CreatedDate,
                User = order.User,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                OrderDetails = order.OrderDetails.Where(d => mids.Contains(d.MerchantId) &&
                                                              d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                              d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                              d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
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

    }
}
