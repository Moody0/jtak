using System;
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
using Modules.Shipping.Entities;
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
        private readonly IInventoryBatchService _batchService;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IOrderService _service;

        public OrdersController(IOrdersUnitOfWork unitOfWork,
            UserManager<AppUser> userManager,
            INotificationService notificationService,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IInventoryBatchService batchService,
            IOrderService service,
            ILogger<OrdersController> logger,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _batchService = batchService;
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
                    DeliveryOtp = x.DeliveryOtp,
                    DeliveredAt = x.DeliveredAt,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = x.User,
                    Notes = x.Notes,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Address = x.Address,
                    OrderDetails = x.OrderDetails
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
                                        OrderDetailStatus = d.OrderDetailStatus,
                                        Warning = d.Warning
                                    }).ToArray()
                }, x => x.UserId == uid.Value && x.OrderStatus == OrderStatus.Success, x => x.OrderDetails);
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
                .FirstOrDefaultAsync(x => x.Id == id && x.UserId == uid.Value && x.OrderStatus == OrderStatus.Success);

            if (order == null)
                return NotFound();

            if (string.IsNullOrEmpty(order.DeliveryOtp))
            {
                order.DeliveryOtp = System.Security.Cryptography.RandomNumberGenerator.GetInt32(1000, 10000).ToString();
                await _uow.SaveChangesAsync();
            }

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
                Notes = order.Notes,
                Phonenumber = order.Phonenumber,
                OrderStatus = order.OrderStatus,
                DeliveryOtp = order.DeliveryOtp,
                DeliveredAt = order.DeliveredAt,
                PurchaseDate = order.PurchaseDate,
                CreatedDate = order.CreatedDate,
                User = order.User,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                OrderDetails = order.OrderDetails
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
                                        OrderDetailStatus = d.OrderDetailStatus,
                                        Warning = d.Warning
                                    }).ToArray()
            };

            if (order.DeliveryId.HasValue)
            {
                var delUser = await _userManager.Users
                    .Where(u => u.Id == order.DeliveryId.Value)
                    .Select(u => new { u.PhoneNumber, u.FullName })
                    .FirstOrDefaultAsync();
                if (delUser != null)
                {
                    result.DeliveryUserPhone = delUser.PhoneNumber;
                    if (string.IsNullOrWhiteSpace(result.DeliveryUser))
                    {
                        result.DeliveryUser = delUser.FullName;
                    }
                }
            }

            return result;
        }

        /// <summary>
        /// Get ultra-lightweight live tracking telemetry and multi-stop route progress for active order
        /// </summary>
        [HttpGet]
        [Route("{id}/LiveTrack")]
        public async Task<ActionResult<OrderLiveTrackDto>> GetLiveTrack(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var order = await _service.Queryable()
                .Where(x => x.Id == id && x.UserId == uid.Value && x.OrderStatus == OrderStatus.Success)
                .Select(x => new
                {
                    x.Id,
                    x.OrderStatus,
                    x.DeliveryId,
                    x.DeliveryUser,
                    x.DeliveryLat,
                    x.DeliveryLng,
                    x.DeliveryLocationUpdatedAt,
                    x.Lat,
                    x.Lng,
                    x.Address
                })
                .FirstOrDefaultAsync();

            if (order == null) return NotFound();

            var stops = await _deliveryService.GetOrderStops(id);

            // Fetch live cached driver telemetry if available
            decimal? driverLat = order.DeliveryLat;
            decimal? driverLng = order.DeliveryLng;
            double? heading = null;
            double? speed = null;
            DateTime? updatedAt = order.DeliveryLocationUpdatedAt;

            if (order.DeliveryId.HasValue)
            {
                var driverStatus = await _deliveryService.GetDeliveryStatus(order.DeliveryId.Value);
                if (driverStatus != null && driverStatus.LastLocationUpdatedAt.HasValue)
                {
                    // If cached telemetry is newer than database, prefer cache
                    if (!updatedAt.HasValue || driverStatus.LastLocationUpdatedAt.Value >= updatedAt.Value)
                    {
                        driverLat = driverStatus.Loc.Lat;
                        driverLng = driverStatus.Loc.Lng;
                        heading = driverStatus.Heading;
                        speed = driverStatus.Speed;
                        updatedAt = driverStatus.LastLocationUpdatedAt;
                    }
                }
            }

            var isLive = updatedAt.HasValue && (DateTime.UtcNow - updatedAt.Value).TotalMinutes < 5;

            // Compute remaining distance through pending stops to customer destination
            int remainingDistanceMeters = 0;
            var currentPos = driverLat.HasValue && driverLng.HasValue ? (driverLat.Value, driverLng.Value) : (order.Lat, order.Lng);
            var pendingStops = stops.Where(s => !s.CompletedDate.HasValue).OrderBy(s => s.Index).ToList();

            var runner = currentPos;
            foreach (var stop in pendingStops)
            {
                remainingDistanceMeters += (int)runner.DistanceInMeters((stop.Lat, stop.Lng));
                runner = (stop.Lat, stop.Lng);
            }
            // Add the final delivery transit leg to the customer destination
            remainingDistanceMeters += (int)runner.DistanceInMeters((order.Lat, order.Lng));

            // ETA: Average urban courier speed ~ 25 km/h (416 m/min) + 2 mins per remaining stop
            int etaMinutes = 0;
            if (remainingDistanceMeters > 0)
            {
                etaMinutes = (int)System.Math.Ceiling(remainingDistanceMeters / 400.0) + (pendingStops.Count * 2);
            }

            var currentStop = pendingStops.FirstOrDefault();

            var driverPhone = string.Empty;
            var driverName = order.DeliveryUser ?? string.Empty;
            if (order.DeliveryId.HasValue)
            {
                var delUser = await _userManager.Users
                    .Where(u => u.Id == order.DeliveryId.Value)
                    .Select(u => new { u.PhoneNumber, u.FullName })
                    .FirstOrDefaultAsync();
                if (delUser != null)
                {
                    driverPhone = delUser.PhoneNumber ?? string.Empty;
                    if (string.IsNullOrWhiteSpace(driverName))
                    {
                        driverName = delUser.FullName ?? string.Empty;
                    }
                }
            }

            return Ok(new OrderLiveTrackDto
            {
                OrderId = order.Id,
                OrderStatus = (int)order.OrderStatus,
                DriverId = order.DeliveryId,
                DriverName = driverName,
                DriverPhoneNumber = driverPhone,
                DriverLat = driverLat,
                DriverLng = driverLng,
                Heading = heading,
                Speed = speed,
                LocationUpdatedAt = updatedAt,
                IsLive = isLive,
                EtaMinutes = etaMinutes,
                RemainingDistanceMeters = remainingDistanceMeters,
                DestinationLat = order.Lat,
                DestinationLng = order.Lng,
                DestinationAddress = order.Address,
                CurrentStopIndex = currentStop?.Index ?? (stops.Count > 0 ? stops.Max(s => s.Index) : 1),
                CurrentStopTitle = currentStop?.StopTitle ?? "عنوان التوصيل (موقعك)",
                CurrentStopIsDarkStore = currentStop?.IsDarkStore ?? false,
                Stops = stops.Select(s => new ShippingStopProgressDto
                {
                    Index = s.Index,
                    Title = s.StopTitle,
                    IsDarkStore = s.IsDarkStore,
                    IsCompleted = s.CompletedDate.HasValue,
                    Lat = s.Lat,
                    Lng = s.Lng,
                    StopType = (int)s.StopType
                }).ToList()
            });
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

            // Release reserved warehouse batch inventory for customer-cancelled order
            await _batchService.ReleaseReservationAsync(id, reason: "Canceled by customer");

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
