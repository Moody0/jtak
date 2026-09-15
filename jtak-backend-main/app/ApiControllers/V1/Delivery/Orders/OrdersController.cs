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
using App.Orders.Data;
using Modules.Shipping.Entities;
using Microsoft.AspNetCore.SignalR;
using App.Shared.Services.Hubs;

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
        private readonly ILedgerService _ledgerService;
        private readonly IAccountingUnitOfWork _auow;
        private readonly IInventoryBatchService _batchService;
        private readonly IProductService _productService;
        private readonly IHubContext<TrackingHub> _trackingHub;
        private readonly IOrdersUnitOfWork _ouow;

        public OrdersController(IAppUnitOfWork unitOfWork,
            IAccountingUnitOfWork auow,
            IOrdersUnitOfWork ouow,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IMerchantService merchantService,
            IProductService productService,
            IDeliveryService deliveryService,
            IOrderService service,
            IBillService billService,
            IBalanceService balanceService,
            ILedgerService ledgerService,
            IInventoryBatchService batchService,
            IHubContext<TrackingHub> trackingHub,
            IMapper mapper)
        {
            _auow = auow;
            _ouow = ouow;
            _userManager = userManager;
            _notificationService = notificationService;
            _mapper = mapper;
            _merchantService = merchantService;
            _productService = productService;
            _deliveryService = deliveryService;
            _service = service;
            _billService = billService;
            _balanceService = balanceService;
            _ledgerService = ledgerService;
            _batchService = batchService;
            _trackingHub = trackingHub;
        }


        private async Task<DeliveryOrderDto[]> BuildDeliveryOrderDtosAsync(IEnumerable<OrderDto> orderDtos)
        {
            var dtosList = orderDtos?.ToList() ?? new List<OrderDto>();
            if (dtosList.Count == 0) return Array.Empty<DeliveryOrderDto>();

            var allDetails = dtosList
                .Where(x => x.OrderDetails != null)
                .SelectMany(x => x.OrderDetails)
                .Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToArray();

            var merchantIds = allDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var merchants = await _merchantService.Queryable()
                .Where(m => merchantIds.Contains(m.Id))
                .Select(m => new { m.Id, m.Title, m.Lat, m.Lng, m.MerchantKind, m.Address, m.Photo, Phone = m.Phone1 ?? m.Phone2 })
                .ToDictionaryAsync(m => m.Id);

            var productIds = allDetails.Where(d => string.IsNullOrEmpty(d.ProductImage)).Select(d => d.ProductId).Distinct().ToArray();
            var productPhotos = productIds.Length > 0
                ? await _productService.Queryable()
                    .Where(p => productIds.Contains(p.Id))
                    .Select(p => new { p.Id, p.Photos })
                    .ToDictionaryAsync(p => p.Id, p => p.Photos)
                : new Dictionary<int, string>();

            return dtosList.Select(x =>
            {
                var validDetails = (x.OrderDetails ?? Array.Empty<OrderDetailDto>())
                    .Where(d => d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                    .ToArray();

                var groupedMerchants = validDetails
                    .GroupBy(d => d.MerchantId)
                    .Select(g =>
                    {
                        merchants.TryGetValue(g.Key, out var m);
                        var isDark = m != null && (m.MerchantKind == MerchantKind.DarkStore ||
                                                    (m.Title != null && (m.Title.Contains("Dark") ||
                                                                        m.Title.Contains("مستودع") ||
                                                                        m.Title.Contains("Warehouse"))));
                        var items = g.Select(detail =>
                        {
                            if (string.IsNullOrEmpty(detail.ProductImage) && productPhotos.TryGetValue(detail.ProductId, out var photo) && !string.IsNullOrEmpty(photo))
                            {
                                detail.ProductImage = photo;
                            }
                            if (string.IsNullOrEmpty(detail.MerchantTitle) && m != null)
                            {
                                detail.MerchantTitle = m.Title;
                            }
                            return detail;
                        }).ToArray();

                        return new DeliveryOrderDetailDto
                        {
                            OrderDetailStatus = g.FirstOrDefault()?.OrderDetailStatus ?? OrderDetailStatus.MerchantAccepted,
                            MerchantId = g.Key,
                            MerchantTitle = m?.Title ?? g.FirstOrDefault()?.MerchantTitle ?? $"Store #{g.Key}",
                            MerchantLogo = m?.Photo,
                            Lat = m?.Lat ?? 0,
                            Lng = m?.Lng ?? 0,
                            MerchantPhone = m?.Phone,
                            MerchantAddress = m?.Address,
                            IsDarkStore = isDark,
                            OrderDetails = items
                        };
                    }).ToArray();

                return new DeliveryOrderDto
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
                    OrderDetails = groupedMerchants
                };
            }).ToArray();
        }

        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<DeliveryOrderDto>>> PostMine([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            var timeTurkey = TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time"));
            var dayStart = timeTurkey.Date.AddDays(-2);

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
                (x.PurchaseDate != null ? x.PurchaseDate > dayStart : x.CreatedDate > dayStart),
                x => x.OrderDetails);

            var result = new TableResponseModel<DeliveryOrderDto>()
            {
                Items = await BuildDeliveryOrderDtosAsync(orders.Items),
                Error = orders.Error,
                TotalRecords = orders.TotalRecords,
                TotalRecordsFiltered = orders.TotalRecordsFiltered
            };
            return result;
        }

        /// <summary>
        /// Get a paged/filtered list of Available (unassigned approved) Orders for couriers to claim
        /// </summary>
        [HttpPost]
        [Route("Available")]
        public async Task<ActionResult<TableResponseModel<DeliveryOrderDto>>> PostAvailable([FromBody] MetronicTable request)
        {
            var timeTurkey = TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time"));
            var dayStart = timeTurkey.Date.AddDays(-2);

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
                },
                x => x.DeliveryId == Guid.Empty &&
                     x.OrderStatus == OrderStatus.Success &&
                     x.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup) &&
                     (x.PurchaseDate != null ? x.PurchaseDate > dayStart : x.CreatedDate > dayStart),
                x => x.OrderDetails);

            var result = new TableResponseModel<DeliveryOrderDto>()
            {
                Items = await BuildDeliveryOrderDtosAsync(orders.Items),
                Error = orders.Error,
                TotalRecords = orders.TotalRecords,
                TotalRecordsFiltered = orders.TotalRecordsFiltered
            };
            return result;
        }

        /// <summary>
        /// Courier claims an available unassigned order
        /// </summary>
        [HttpPost]
        [Route("Claim/{id}")]
        public async Task<ActionResult<bool>> ClaimOrder(int id)
        {
            return BadRequest(ApiErr.Create("يتم تعيين المندوب من قبل الإدارة بعد أن يؤكد التاجر أن الطلب جاهز للاستلام."));
#pragma warning disable CS0162
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            var order = await _service.FindAsync(id);
            if (order == null)
                return NotFound(ApiErr.Create("الطلب غير موجود."));

            if (order.DeliveryId.HasValue)
                return BadRequest(ApiErr.Create("تم استلام هذا الطلب بالفعل من قبل كابتن آخر."));

            if (order.OrderStatus != OrderStatus.Success)
                return BadRequest(ApiErr.Create("الطلب غير متاح للاستلام حالياً."));

            var courier = await _userManager.FindByIdAsync(uid.Value.ToString());
            if (courier == null)
                return BadRequest(ApiErr.Create("بيانات السائق غير متوفرة."));

            order.DeliveryId = uid.Value;
            order.DeliveryUser = courier.FullName ?? courier.UserName ?? "Delivery Courier";
            order.DeliveryLat = null;
            order.DeliveryLng = null;
            order.DeliveryLocationUpdatedAt = null;
            await _ouow.SaveChangesAsync();

            var customerSO = new ShippingOrderDto
            {
                OrderId = order.Id,
                DriverId = uid.Value,
                MerchantId = null,
                CustomerId = order.UserId,
                Lat = order.Lat,
                Lng = order.Lng,
                StopType = ShippingStopType.Dropoff,
                StopTitle = $"Customer: {order.User ?? order.Phonenumber}"
            };

            var orderMerchantIds = await _service.GetMerchantIds(id);
            var allMerchantStops = await _merchantService.GetMerchantStops(orderMerchantIds);
            var merchantsSOs = new List<ShippingOrderDto>();
            foreach (var x in allMerchantStops)
            {
                var m = await _merchantService.FindAsync(x.MerchantId);
                var isDarkStore = m != null && (m.MerchantKind == MerchantKind.DarkStore || m.Title.Contains("Dark") || m.Title.Contains("مستودع") || m.Title.Contains("Warehouse"));
                merchantsSOs.Add(new ShippingOrderDto
                {
                    OrderId = order.Id,
                    DriverId = uid.Value,
                    MerchantId = x.MerchantId,
                    CustomerId = order.UserId,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    StopType = ShippingStopType.Pickup,
                    StopTitle = m?.Title ?? $"Merchant #{x.MerchantId}",
                    IsDarkStore = isDarkStore
                });
            }

            await _deliveryService.AddOrder(uid.Value, id, merchantsSOs.ToArray(), customerSO);
            await _notificationService.SendDeliveryNewOrderRecived(new[] { uid.Value }, id, order.OrderDetails.ToArray());

            await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnDriverAssigned", new { orderId = id, driverId = uid.Value, driverName = order.DeliveryUser });
            await _trackingHub.Clients.Group(TrackingHub.FleetDispatchGroup).SendAsync("OnOrderClaimed", new { orderId = id, driverId = uid.Value, driverName = order.DeliveryUser });

            return true;
#pragma warning restore CS0162
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
                                                                x.OrderStatus == OrderStatus.Success);
            if (order == null)
                return NotFound();

            if (order.DeliveryId != uid.Value)
                return Forbid();

            var orderDto = new OrderDto
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
                PaymentMethod = order.PaymentMethod,
                OrderDetails = order.OrderDetails != null
                    ? order.OrderDetails
                        .Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                        .Select(d => d.ToDto())
                        .ToArray()
                    : Array.Empty<OrderDetailDto>()
            };

            var dtos = await BuildDeliveryOrderDtosAsync(new[] { orderDto });
            var result = dtos.FirstOrDefault();
            if (result == null)
                return NotFound();

            return result;
        }

        [HttpPost]
        [Route("StartShipping/{id}/{mid}")]
        public async Task<ActionResult<bool>> StartShipping(int id, int mid)
        {
            // Delivery Accepted Shipping Order Details
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null) return NotFound();
            if (currentOrder.DeliveryId != uid.Value) return Forbid();

            if (!await _service.CanStartShippingOrder(id, mid, uid.Value))
                return false;

            var order = await _service.StartShippingOrder(id, mid, uid.Value);
            var merchant = await _merchantService.FindAsync(mid);
            var merchantShippingStartedOrderDetails = order.OrderDetails.Where(x => x.MerchantId == mid && x.OrderDetailStatus == OrderDetailStatus.ShippingStarted).ToArray();

            // Create or update bill idempotently with concurrency unique constraint handling
            var existingBill = await _billService.Queryable().FirstOrDefaultAsync(x => x.OrderId == id && x.MerchantId == mid);
            if (existingBill == null)
            {
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
                    IsAddedToDues = false // Under Zero-Cash model, dues activate upon successful customer delivery
                };
                if (bill.PaymentMethod != 0)
                {
                    bill.DueDate = DateTime.UtcNow.AddDays(7);
                    bill.IsAddedToDues = false;
                }
                try
                {
                    _billService.Insert(bill);
                    await _auow.SaveChangesAsync();
                }
                catch (DbUpdateException)
                {
                    // Concurrency race: Another concurrent request inserted the bill first.
                    // Fall back to updating the existing bill.
                    _auow.Context.ChangeTracker.Clear();
                    existingBill = await _billService.Queryable().FirstOrDefaultAsync(x => x.OrderId == id && x.MerchantId == mid);
                    if (existingBill != null)
                    {
                        existingBill.TotalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity);
                        existingBill.MerchantAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleMerchantProfit * d.Quantity);
                        existingBill.JTakAmount = merchantShippingStartedOrderDetails.Sum(d => (d.SingleFinalPrice - d.SingleMerchantProfit) * d.Quantity);
                        existingBill.JTakAdditionalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleAdditionalProfit * d.Quantity);
                        existingBill.PaymentMethod = (int)order.PaymentMethod;
                        _billService.Update(existingBill);
                        await _auow.SaveChangesAsync();
                    }
                }
            }
            else
            {
                existingBill.TotalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity);
                existingBill.MerchantAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleMerchantProfit * d.Quantity);
                existingBill.JTakAmount = merchantShippingStartedOrderDetails.Sum(d => (d.SingleFinalPrice - d.SingleMerchantProfit) * d.Quantity);
                existingBill.JTakAdditionalAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleAdditionalProfit * d.Quantity);
                existingBill.PaymentMethod = (int)order.PaymentMethod;
                _billService.Update(existingBill);
                await _auow.SaveChangesAsync();
            }

            // Zero-Cash Merchant Handover: Couriers do NOT pay merchants in cash upon pickup.
            // Goods are handed over on platform credit; therefore, no cash deduction from merchant balance at pickup.

            // Remove Current delivery Task from delivery user queue
            await _deliveryService.RemoveOrder(uid.Value, id, mid);

            // Notify Customer & broadcast: Shipping Started (resilient)
            try
            {
                var isFirstShipping = order.OrderDetails.Count(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted)
                                      == merchantShippingStartedOrderDetails.Length;
                if (isFirstShipping)
                {
                    await _notificationService.SendShippingStarted(new[] { order.UserId }, id, order.OrderDetails.ToArray());
                }

                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnStopCompleted", new { orderId = id, merchantId = mid, completedAt = DateTime.UtcNow });
            }
            catch
            {
                // Resilient: Notification/SignalR errors must never fail committed StartShipping
            }

            return true;
        }

        [HttpPost]
        [HttpPut]
        [Route("Location")]
        public async Task<ActionResult<bool>> UpdateDriverLocation([FromBody] DeliveryLocationUpdate location)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng), location.Heading, location.Speed);

            var courierPayload = new
            {
                driverId = uid.Value,
                lat = location.Lat,
                lng = location.Lng,
                heading = location.Heading,
                speed = location.Speed,
                updatedAt = DateTime.UtcNow
            };
            await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierLocationUpdated", courierPayload);
            await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetLocationUpdated", courierPayload);

            return true;
        }

        [HttpGet]
        [Route("Shift/Status")]
        public async Task<ActionResult<object>> GetShiftStatus()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var status = await _deliveryService.GetDeliveryStatus(uid.Value);
            return Ok(new
            {
                isOnline = status.IsOnline,
                shiftStartedAt = status.ShiftStartedAt
            });
        }

        [HttpPost]
        [Route("Shift/Status")]
        public async Task<ActionResult<bool>> SetShiftStatus([FromBody] ShiftStatusRequest request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            await _deliveryService.SetDutyStatus(uid.Value, request.IsOnline);

            var statusPayload = new
            {
                driverId = uid.Value,
                isOnline = request.IsOnline,
                updatedAt = DateTime.UtcNow
            };
            await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierDutyStatusChanged", statusPayload);
            await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetDutyStatusChanged", statusPayload);

            return true;
        }

        [HttpPost]
        [HttpPut]
        [Route("{id}/Location")]
        public async Task<ActionResult<bool>> UpdateLocation(int id, [FromBody] DeliveryLocationUpdate location)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();
            if (order.DeliveryId != uid.Value) return Forbid();

            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng), location.Heading, location.Speed);
            await _service.UpdateDeliveryLocation(id, uid.Value, location.Lat, location.Lng);

            // Broadcast real-time location via SignalR (resilient)
            try
            {
                var livePayload = new
                {
                    orderId = id,
                    driverId = uid.Value,
                    lat = location.Lat,
                    lng = location.Lng,
                    heading = location.Heading,
                    speed = location.Speed,
                    updatedAt = DateTime.UtcNow
                };
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnLocationUpdated", livePayload);
                await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierLocationUpdated", livePayload);
                await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetLocationUpdated", livePayload);
            }
            catch
            {
                // SignalR failure should not fail location update
            }

            return true;
        }

        [HttpGet]
        [Route("{id}/Stops")]
        public async Task<ActionResult<List<ShippingOrderDto>>> GetStops(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();
            if (order.DeliveryId != uid.Value) return Forbid();

            var stops = await _deliveryService.GetOrderStops(id);
            return Ok(stops);
        }

        [HttpPost]
        [Route("DeliverOrder/{id}")]
        public async Task<ActionResult<bool>> DeliverOrder(int id, [FromBody] DeliverOrderRequest request = null, [FromQuery] string otp = null)
        {
            // Delivery Declared Order Details (Delivered)
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var dUser = await _userManager.Users.Where(x => x.Id == uid).Select(x => x.FullName).FirstOrDefaultAsync();

            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            if (currentOrder.DeliveryId != uid.Value)
                return Forbid();

            // Proof of Delivery (PoD) OTP Verification / Photo Fallback:
            var submittedOtp = request?.Otp ?? otp;
            var hasValidPhoto = !string.IsNullOrWhiteSpace(request?.PhotoUrl);
            if (!string.IsNullOrEmpty(currentOrder.DeliveryOtp))
            {
                string NormalizeOtp(string val)
                {
                    if (string.IsNullOrWhiteSpace(val)) return string.Empty;
                    var sb = new System.Text.StringBuilder();
                    foreach (var ch in val.Trim())
                    {
                        if (ch >= '0' && ch <= '9') sb.Append(ch);
                        else if (ch >= '\u0660' && ch <= '\u0669') sb.Append((char)('0' + (ch - '\u0660')));
                        else if (ch >= '\u06F0' && ch <= '\u06F9') sb.Append((char)('0' + (ch - '\u06F0')));
                    }
                    return sb.ToString();
                }

                var cleanSubmitted = NormalizeOtp(submittedOtp);
                var cleanDb = NormalizeOtp(currentOrder.DeliveryOtp);
                var cleanDbReversed = new string(cleanDb.Reverse().ToArray());

                bool otpValid = !string.IsNullOrEmpty(cleanSubmitted) &&
                    (cleanSubmitted == cleanDb
                     || cleanSubmitted == cleanDbReversed);

                if (!otpValid && !hasValidPhoto)
                {
                    return BadRequest(ApiErr.Create("رمز تأكيد التسليم غير صحيح. يرجى إدخال رمز التحقق المستلم من العميل أو التقاط صورة لتوثيق التسليم (PoD)."));
                }
            }

            var isAlreadyDelivered = currentOrder.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                                        x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                                        x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                                                             .All(x => x.OrderDetailStatus == OrderDetailStatus.Delivered);

            if (!isAlreadyDelivered && !await _service.CanDeliverOrder(id, uid.Value))
            {
                return BadRequest(ApiErr.Create("لا يمكن تأكيد تسليم هذا الطلب. يرجى التأكد من استلام الطلب وتعيينه لك."));
            }

            // Check if not already delivered and update with PoD metadata atomically
            var order = isAlreadyDelivered
                ? currentOrder
                : await _service.DeliverOrder(id, uid.Value, request?.PhotoUrl, request?.Signature, request?.Notes);

            // Execute financial operations in an atomic relational transaction
            using (var transaction = await _auow.Context.Database.BeginTransactionAsync())
            {
                try
                {
                    // Mark merchant bills as due now that delivery is complete
                    var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
                    foreach (var b in bills)
                    {
                        b.IsAddedToDues = true;
                        _billService.Update(b);
                    }
                    await _auow.SaveChangesAsync();

                    // Double-Entry Ledger Posting: Revenue Split (COD or Electronic/Prepaid)
                    var isCod = order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
                    if (bills.Length > 0)
                    {
                        var merchantSplits = new List<MerchantSplitItem>();
                        foreach (var b in bills)
                        {
                            var m = await _merchantService.FindAsync(b.MerchantId);
                            merchantSplits.Add(new MerchantSplitItem
                            {
                                MerchantId = b.MerchantId,
                                MerchantTitle = m?.Title ?? $"Merchant #{b.MerchantId}",
                                TotalAmount = b.TotalAmount,
                                MerchantAmount = b.MerchantAmount,
                                PlatformCommission = b.JTakAmount,
                                IsPlatformOwned = m?.MerchantKind == MerchantKind.DarkStore,
                                CaptainEarningAmount = b.JTakAdditionalAmount
                            });
                        }

                        var splitReq = new OrderDeliveredSplitRequest
                        {
                            OrderId = id,
                            CaptainUserId = uid.Value,
                            CaptainName = dUser,
                            DeliveryFee = bills.Sum(x => x.JTakAdditionalAmount),
                            TotalsIncludeDeliveryFee = true,
                            Currency = "SYP",
                            IsCod = isCod,
                            MerchantSplits = merchantSplits
                        };

                        await _ledgerService.PostOrderDeliveredSplitAsync(splitReq);
                    }

                    // Maintain legacy balance for backwards compatibility with legacy mobile views
                    var recivedAmount = bills.Where(x => x.PaymentMethod == 0).Sum(x => x.TotalAmount);
                    if (recivedAmount > 0 && !isAlreadyDelivered)
                    {
                        await _balanceService.IncreaseAppBalance(uid.Value, recivedAmount, dUser);
                    }

                    await transaction.CommitAsync();
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            }

            // Remove Customer from delivery task list
            await _deliveryService.RemoveOrder(uid.Value, id);

            // Resilient SignalR broadcast
            try
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderDelivered", new { orderId = id, deliveredAt = DateTime.UtcNow });
            }
            catch
            {
                // Push/SignalR failure should never fail DeliverOrder after commit
            }

            return true;
        }

        [HttpPost]
        [Route("Cancel/{id}")]
        public async Task<ActionResult<bool>> DeliveryCancel(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var existingOrder = await _service.FindAsync(id);
            if (existingOrder == null)
                return NotFound();

            if (existingOrder.DeliveryId != uid.Value)
                return Forbid();

            if (existingOrder.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Delivered))
            {
                return BadRequest(ApiErr.Create("لا يمكن إلغاء طلب تم تسليمه."));
            }

            var order = await _service.DeliveryCancelOrder(id, uid);

            // Delivery should return products to each merchant (offline), Without return confirmation
            // Bills are preserved for audit trail (never deleted), but deactivated from dues
            var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
            foreach (var bill in bills)
            {
                bill.IsAddedToDues = false;
                _billService.Update(bill);
            }

            // Reverse double-entry ledger entries if order had been delivered
            await _ledgerService.PostOrderCancellationReversalAsync(id, "Canceled by courier");

            // Release reserved warehouse batch inventory
            await _batchService.ReleaseReservationAsync(id, reason: "Canceled by courier");

            // Maintain legacy balance rollback if previously delivered
            if (order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.Delivered))
            {
                var recivedAmount = bills.Where(x => x.PaymentMethod == 0).Sum(x => x.TotalAmount);
                if (recivedAmount > 0)
                {
                    var dUser = await _userManager.Users.Where(x => x.Id == uid).Select(x => x.FullName).FirstOrDefaultAsync();
                    await _balanceService.DecreaseAppBalance(uid.Value, recivedAmount, dUser);
                }
            }

            try
            {
                var merchantIds = order.OrderDetails.Select(x => x.MerchantId).ToArray().Distinct();
                foreach (var merchantId in merchantIds)
                {
                    var mId = await _merchantService.GetOwnerId(merchantId);
                    // Notify related merchant about canceled order
                    await _notificationService.SendOrderCanceled(new[] { mId }, id, order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray());
                }
            }
            catch
            {
                // Resilient notification dispatch
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

    public class ShiftStatusRequest
    {
        public bool IsOnline { get; set; }
    }
}
