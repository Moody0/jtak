using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.Globalization;
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
using Modules.Orders.Services;
using App.Extensions;
using Modules.Shipping.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Services;
using Microsoft.Extensions.Logging;
using Modules.Shipping.Entities;
using App.Orders.Data;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class OrdersController : SolApiController
    {
        //private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMerchantService _merchantService;
        private readonly IOrderService _service;
        private readonly IOrderDetailService _orderDetailService;
        private readonly IDeliveryService _deliveryService;
        private readonly IBillService _billService;
        private readonly IBalanceService _balanceService;
        private readonly IOrdersUnitOfWork _ouow;
        private readonly IAccountingUnitOfWork _auow;

        public OrdersController(INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IDeliveryService deliveryService,
            IOrderService service,
            IOrderDetailService orderDetailService,
            IOrdersUnitOfWork ouow,
            IAccountingUnitOfWork auow,
            IBillService billService,
            IBalanceService balanceService,
            ILogger<OrdersController> logger,
            IMapper mapper)
        {
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _deliveryService = deliveryService;
            _service = service;
            _orderDetailService = orderDetailService;
            _billService = billService;
            _balanceService = balanceService;
            _auow = auow;
            _ouow = ouow;
        }

        /// <summary>
        /// Get a paged/filtered/ordered list of Orders
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<OrderDto>>> DataTable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var user = await _userManager.GetUserAsync(User);
            var isAdmin = await _userManager.IsInRoleAsync(user, AppRoleName.Admin.ToString());

            var list = await _service.ListMetronicTableQueryable(request,
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
                    OrderDetails = x.OrderDetails.Select(d => d.ToDto()).ToArray()
                }, x => x.OrderStatus == OrderStatus.Success, x => x.OrderDetails);
            return list;
        }

        ///// <summary>                                           
        ///// Change order status   +---------+                   
        /////                       |  Order  |                   
        /////                       +----+----+                   
        /////                            |                        
        /////                         Success                     
        /////                            |                        
        ///// ---------------------------|------------------------
        /////   +-------------------+    |                        
        /////   |                   |    |                        
        /////   |                +--+----+-------+                
        /////   |          +-----+ Order Details +----+           
        ///// Found?       |     +---------------+    |           
        /////   |       Merchant                   Merchant       
        /////   |       Rejected?                  Accepted?      
        /////   |          |                          |           
        /////   | +--------+--------+        +--------+--------+  
        /////   +-+ Find Alternative|        | Notify Delivery |  
        /////     +--------+--------+        +--------+--------+  
        /////              |                          |           
        /////              |                 +--------+--------+  
        /////          Not Found?            |Shipping Started |  
        /////              |                 +--------+--------+  
        /////              |                          |           
        /////     +--------+--------+        +--------+--------+  
        /////     | Notify Customer |        |    Delivered    |  
        /////     +-----------------+        +--------+--------+  
        ///// </summary>
        ///// <returns></returns>
        ///// <summary>
        ///// Get a specific order with Details
        ///// </summary>
        ///// <returns></returns>

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
        public async Task<ActionResult<bool>> DeliveryCancel(int id)
        {
            var order = await _service.FindAsync(id);
            var needToDeleteBill = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            var needToCorrectMerchantBalance = needToDeleteBill;
            var needToCorrectDeliveryBalance = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Delivered);
            order = await _service.DeliveryCancelOrder(id);

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
            // Redundent save?
            await _auow.SaveChangesAsync();
            return true;
        }

        [HttpPost]
        [Route("Approve/{id}")]
        public async Task<ActionResult<bool>> Approve(int id)
        {
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var actionableDetails = currentOrder.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();
            var merchantIds = actionableDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var allMerchantStops = await _merchantService.GetMerchantStops(merchantIds);
            var bestDelivery = await _deliveryService.PickBestDelivery(allMerchantStops);

            var order = await _service.MerchantAccept(id, merchantIds);

            if (!order.DeliveryId.HasValue && bestDelivery.Id != default && order.OrderDetails
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected)
                .All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted))
            {
                order.DeliveryId = bestDelivery.Id;
                order.DeliveryUser = await _userManager.Users.Where(x => x.Id == bestDelivery.Id).Select(x => x.FullName).FirstOrDefaultAsync();
                order.DeliveryLat = null;
                order.DeliveryLng = null;
                order.DeliveryLocationUpdatedAt = null;
                await _ouow.SaveChangesAsync();

                var customerStop = new ShippingOrderDto { OrderId = order.Id, DriverId = bestDelivery.Id, CustomerId = order.UserId, Lat = order.Lat, Lng = order.Lng };
                var merchantStops = allMerchantStops.Select(x => new ShippingOrderDto
                {
                    OrderId = order.Id,
                    DriverId = bestDelivery.Id,
                    MerchantId = x.MerchantId,
                    CustomerId = order.UserId,
                    Lat = x.Lat,
                    Lng = x.Lng,
                }).ToArray();

                await _deliveryService.AddOrder(bestDelivery.Id, id, merchantStops, customerStop);
                await _notificationService.SendDeliveryNewOrderRecived(new[] { bestDelivery.Id }, id, order.OrderDetails.ToArray());
            }
            return true;
        }

        [HttpPut]
        [Route("SetDelivery/{id}/{uid}")]
        public async Task<ActionResult<bool>> SetDelivery(int id, Guid uid)
        {
            var order = await _service.FindAsync(id);
            if (order == null)
                return NotFound();

            var bestDelivery = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == uid);
            if (bestDelivery == null || !await _userManager.IsInRoleAsync(bestDelivery, AppRoleName.Delivery.ToString()))
                return BadRequest(ApiErr.Create("The selected user is not a delivery driver."));

            if (order.DeliveryId.HasValue)
            {
                await _deliveryService.RemoveOrder(order.DeliveryId.Value, id);
            }

            order.DeliveryId = bestDelivery.Id;
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            order.DeliveryUser = await _userManager.Users.Where(x => x.Id == order.DeliveryId).Select(x => x.FullName).FirstOrDefaultAsync();
            await _ouow.SaveChangesAsync();

            var customerSO = new ShippingOrderDto { OrderId = order.Id, DriverId = order.DeliveryId.Value, MerchantId = null, CustomerId = order.UserId, Lat = order.Lat, Lng = order.Lng };

            var orderMerchantIds = await _service.GetMerchantIds(id);
            var allMerchantStops = await _merchantService.GetMerchantStops(orderMerchantIds);
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
            return true;
        }
    }
}
