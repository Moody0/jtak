using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using System.Linq;
using App.Shared.Data.App;
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
using Modules.Accounting.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;

namespace App.ApiControllers.V1.Delivery
{
    [Route("api/v{version:apiVersion}/Delivery/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.DeliveryPermission))]
    public class OrdersController : SolApiController
    {
        //private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMerchantService _merchantService;
        private readonly IDeliveryService _deliveryService;
        private readonly IOrderService _service;
        private readonly IBillService _billService;
        private readonly IBalanceService _balanceService;
        private readonly IAccountingUnitOfWork _auow;

        public OrdersController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IOrderService service,
            IBillService billService,
            IBalanceService balanceService,
            IMapper mapper)
        {
            _auow = auow;
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _service = service;
            _billService = billService;
            _balanceService = balanceService;
        }


        /// <summary>
        /// Get a paged/filtered/ordered list of Orders
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<DeliveryOrderDto>>> PostMine([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var timeTurkey = TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time"));
            var dayStart = timeTurkey.Date.AddHours(-5);

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
                    OrderDetails = x.OrderDetails.Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected && d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).Select(d => d.ToDto()).ToArray()
                }, x => x.DeliveryId == uid && x.OrderDetails.Any(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected && d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled) &&
                x.OrderStatus == OrderStatus.Success &&
                x.PurchaseDate > dayStart,
                x => x.OrderDetails);

            var result = new TableResponseModel<DeliveryOrderDto>()
            {
                Items = orders.Items?.Select(x => new DeliveryOrderDto
                {
                    Address = x.Address,
                    CreatedDate = x.CreatedDate,
                    Description = x.Description,
                    Id = x.Id,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    OrderStatus = x.OrderStatus,
                    PaymentMethod = x.PaymentMethod,
                    Phonenumber = x.Phonenumber,
                    PurchaseDate = x.PurchaseDate,
                    UserId = x.UserId,
                    User = x.User,
                    OrderDetails = x.OrderDetails
                                    .Where(x => x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && x.OrderDetailStatus != OrderDetailStatus.MerchantRejected && x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                                    .GroupBy(d => d.MerchantId)
                                    .Select(d =>
                                    {
                                        var loc = _merchantService.GetMerchantLocations(new[] { d.Key }).GetAwaiter().GetResult().FirstOrDefault();
                                        return new DeliveryOrderDetailDto
                                        {
                                            OrderDetailStatus = d.FirstOrDefault()?.OrderDetailStatus ?? OrderDetailStatus.MerchantAccepted,
                                            MerchantId = d.Key,
                                            MerchantTitle = d.FirstOrDefault()?.MerchantTitle,
                                            Lat = loc.Lat,
                                            Lng = loc.Lng,
                                            OrderDetails = d.ToArray()
                                        };
                                    }).ToArray(),
                }).ToArray(),
                Error = orders.Error,
                TotalRecords = orders.TotalRecords,
                TotalRecordsFiltered = orders.TotalRecordsFiltered
            };
            return result;
        }

        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<DeliveryOrderDto>> Get(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            var order = await _service.Queryable()
                                      .AsNoTracking()
                                      .Include(x => x.OrderDetails)
                                      .FirstOrDefaultAsync(x => x.Id == id &&
                                                                x.DeliveryId == uid.Value &&
                                                                x.OrderStatus == OrderStatus.Success);
            if (order == null)
                return NotFound();

            var visibleDetails = order.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();
            var merchantIds = visibleDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var merchantStops = await _merchantService.GetMerchantStops(merchantIds);

            return new DeliveryOrderDto
            {
                Address = order.Address,
                CreatedDate = order.CreatedDate,
                Description = order.Description,
                Id = order.Id,
                Lat = order.Lat,
                Lng = order.Lng,
                OrderStatus = order.OrderStatus,
                PaymentMethod = order.PaymentMethod,
                Phonenumber = order.Phonenumber,
                PurchaseDate = order.PurchaseDate,
                UserId = order.UserId,
                User = order.User,
                OrderDetails = visibleDetails
                    .GroupBy(d => d.MerchantId)
                    .Select(group =>
                    {
                        var location = merchantStops.FirstOrDefault(x => x.MerchantId == group.Key);
                        return new DeliveryOrderDetailDto
                        {
                            OrderDetailStatus = group.First().OrderDetailStatus,
                            MerchantId = group.Key,
                            MerchantTitle = group.First().MerchantTitle,
                            Lat = location.Lat,
                            Lng = location.Lng,
                            OrderDetails = group.Select(d => d.ToDto()).ToArray()
                        };
                    }).ToArray()
            };
        }

        [HttpPost]
        [Route("StartShipping/{id}/{mid}")]
        public async Task<ActionResult<bool>> StartShipping(int id, int mid)
        {
            // Delivery Accepted Shipping Order Details
            var uid = User.GetUserId();

            if (!await _service.CanStartShippingOrder(id, mid, uid.Value))
                return false;

            var order = await _service.StartShippingOrder(id, mid, uid.Value);
            var merchant = await _merchantService.FindAsync(mid);
            var merchantShippingStartedOrderDetails = order.OrderDetails.Where(x => x.MerchantId == mid && x.OrderDetailStatus == OrderDetailStatus.ShippingStarted).ToArray();

            // TODO: handel StartShipping in transaction only?
            // double bill issuing
            // use composite key in bills table?
            // Create new bill
            var bill = new Bill
            {
                MerchantId = mid,
                OrderId = id,
                TotalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity),
                MerchantAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleMerchantProfit * d.Quantity),
                JTakAmount = merchantShippingStartedOrderDetails.Sum(d => (d.SingleFinalPrice - d.SingleMerchantProfit) * d.Quantity),
                JTakAdditionalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleAdditionalProfit * d.Quantity),
                PaymentMethod = (int)order.PaymentMethod,
                DueDate = DateTime.UtcNow,
                IsAddedToDues = true
            };
            if (bill.PaymentMethod != 0)
            {
                bill.DueDate = DateTime.UtcNow.AddDays(7);
                bill.IsAddedToDues = false;
            }
            _billService.Insert(bill);
            await _auow.SaveChangesAsync();

            // If Is Pay of delivery: update merchant user balance NOW
            if (bill.PaymentMethod == 0)
            {
                var mUserId = await _merchantService.GetOwnerId(mid);
                var mUser = await _userManager.Users.Where(x => x.Id == mUserId).Select(x => x.FullName).FirstOrDefaultAsync();

                // Decrease our balance from this merchant
                await _balanceService.DecreaseAppBalance(mUserId, bill.MerchantAmount, mUser); // VERIFIED
            }

            // Remove Current delivery Task from delivery user queue
            await _deliveryService.RemoveOrder(uid.Value, id, mid);

            // Notify Customer: Shipping Started!
            var isFirstShipping = order.OrderDetails.Count(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted)
                                  == merchantShippingStartedOrderDetails.Length;
            if (isFirstShipping)
            {
                await _notificationService.SendShippingStarted(new[] { order.UserId }, id, order.OrderDetails.ToArray());
            }

            return true;
        }

        [HttpPut]
        [Route("Location")]
        public async Task<ActionResult<bool>> UpdateDriverLocation([FromBody] DeliveryLocationUpdate location)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng));
            return true;
        }

        [HttpPut]
        [Route("{id}/Location")]
        public async Task<ActionResult<bool>> UpdateLocation(int id, [FromBody] DeliveryLocationUpdate location)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng));
            await _service.UpdateDeliveryLocation(id, uid.Value, location.Lat, location.Lng);
            return true;
        }

        [HttpPost]
        [Route("DeliverOrder/{id}")]
        public async Task<ActionResult<bool>> DeliverOrder(int id)
        {
            // Delivery Declared Order Details (Delivered)
            var uid = User.GetUserId();
            var dUser = await _userManager.Users.Where(x => x.Id == uid).Select(x => x.FullName).FirstOrDefaultAsync();


            if (!await _service.CanDeliverOrder(id, uid.Value))
                return false;

            // Check if not already delivered
            var order = await _service.DeliverOrder(id, uid.Value);

            // Add recived amount to balance
            var bills = await _billService.Queryable().Where(x => x.OrderId == id && x.PaymentMethod == 0).ToArrayAsync();
            var recivedAmount = bills.Sum(x => x.TotalAmount);
            if (recivedAmount > 0)
                await _balanceService.IncreaseAppBalance(uid.Value, recivedAmount, dUser); // VERIFIED

            // Remove Customer from delivery task list
            await _deliveryService.RemoveOrder(uid.Value, id);

            return true;
        }

        [HttpPost]
        [Route("Cancel/{id}")]
        public async Task<ActionResult<bool>> DeliveryCancel(int id)
        {
            var order = await _service.DeliveryCancelOrder(id, User.GetUserId());

            // Delivery should return products to each merchant (offline), Without return confirmation
            // Bill is deleted, Delivery and merchant balanced are adjusted
            var merchantIds = order.OrderDetails.Select(x => x.MerchantId).ToArray().Distinct();
            var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
            foreach (var merchantId in merchantIds)
            {
                var mId = await _merchantService.GetOwnerId(merchantId);
                var mUser = await _userManager.Users.Where(x => x.Id == mId).Select(x => x.FullName).FirstOrDefaultAsync();

                var balance = await _balanceService.GetBalance(mId);
                var oldBalance = balance?.Amount ?? 0;
                var oldPendingBalance = balance?.PendingAmount ?? 0;

                var bill = bills.FirstOrDefault(x => x.MerchantId == merchantId && x.PaymentMethod == 0);
                if (bill != null)
                {
                    // Increase our balance from this merchant
                    await _balanceService.IncreaseAppBalance(mId, bill.MerchantAmount, mUser); // VERIFIED

                    await _billService.DeleteAsync(new object[] { bill.Id });
                }

                // Notify related merchant about canceled order
                await _notificationService.SendOrderCanceled(new[] { mId }, id, order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray());
            }
            await _auow.SaveChangesAsync();
            return true;
        }


        //[HttpPost]
        //[Route("TestStartShipping/{id}/{mid}")]
        //[AllowAnonymous]
        //public async Task<ActionResult<bool>> TestStartShipping(int id, int mid)
        //{
        //    // Delivery Accepted Shipping Order Details
        //    var deriveries = await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString());
        //    var userId = deriveries.FirstOrDefault()?.Id;
        //
        //    var order = await _service.StartShippingOrder(id, mid, userId.Value);
        //
        //    _deliveryService.RemoveOrder(userId.Value, id, mid);
        //
        //    // Notify Customer: Shipping Started!
        //    var isFirstShipping = order.OrderDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);
        //    if (isFirstShipping)
        //    {
        //        await _notificationService.SendShippingStarted(new[] { order.UserId }, id, order.OrderDetails.ToArray());
        //    }
        //
        //    return true;
        //}
        //
        //[HttpPost]
        //[Route("TestDeliverOrder/{id}")]
        //[AllowAnonymous]
        //public async Task<ActionResult<bool>> TestDeliverOrder(int id)
        //{
        //    // Delivery Declared Order Details (Delivered)
        //    var deriveries = await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString());
        //    var userId = deriveries.FirstOrDefault()?.Id;
        //    var order = await _service.Queryable()
        //                              .Include(x => x.OrderDetails)
        //                              .FirstOrDefaultAsync(x => x.Id == id);
        //    var customerIds = new[] { order.UserId };
        //
        //    // Update Order Detail Statuses
        //    foreach (var orderDetail in order.OrderDetails)
        //    {
        //        orderDetail.OrderDetailStatus = OrderDetailStatus.Delivered;
        //    }
        //    _service.Log(id, OrderDetailStatus.Delivered, order.OrderDetails.ToArray());
        //    await _uow.SaveChangesAsync();
        //
        //    return true;
        //}
    }
}
