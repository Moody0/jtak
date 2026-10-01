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
using Modules.Catalog.Entities;
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
using Microsoft.AspNetCore.SignalR;
using App.Shared.Services.Hubs;
using App.Shared.Services.Pricing;

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
        private readonly IInventoryBatchService _batchService;
        private readonly IOrderTransitionService _transitionService;
        private readonly IOrderMoneyCalculationService _moneyCalculationService;
        private readonly IHubContext<TrackingHub> _trackingHub;

        public OrdersController(IOrdersUnitOfWork unitOfWork,
            UserManager<AppUser> userManager,
            INotificationService notificationService,
            IMerchantService merchantService,
            IOrderService service,
            IProductService productService,
            IOrderDetailService orderDetailService,
            IDeliveryService deliveryService,
            IInventoryBatchService batchService,
            IMapper mapper,
            IOrderTransitionService transitionService = null,
            IOrderMoneyCalculationService moneyCalculationService = null,
            IHubContext<TrackingHub> trackingHub = null)
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
            _batchService = batchService;
            _transitionService = transitionService;
            _moneyCalculationService = moneyCalculationService;
            _trackingHub = trackingHub;
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
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);

            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }

            var orders = await _service.ListMetronicTableQueryable(request,
                x => new OrderDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    Description = x.Description,
                    Notes = x.Notes,
                    Phonenumber = x.Phonenumber,
                    OrderStatus = x.OrderStatus,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = x.User,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Address = x.Address,
                    PaymentMethod = x.PaymentMethod,
                    DeliveryFee = x.DeliveryFee,
                    MoneySnapshotVersion = x.MoneySnapshotVersion,
                    CaptainEarning = x.CaptainEarning,
                    DeliveryId = x.DeliveryId,
                    CourierMatchingStartedAtUtc = x.CourierMatchingStartedAtUtc,
                    CourierMatchingDeadlineAtUtc = x.CourierMatchingDeadlineAtUtc,
                    CourierMatchingCompletedAtUtc = x.CourierMatchingCompletedAtUtc,
                    DeliveryUser = x.DeliveryUser,
                    DeliveryNotes = x.DeliveryNotes,
                    DeliveredAt = x.DeliveredAt,
                    OrderDetails = x.OrderDetails.Where(d => mids.Contains(d.MerchantId)).Select(d => d.ToDto()).ToArray()
                }, x =>
                x.OrderDetails.Any(d => mids.Contains(d.MerchantId))
                && x.OrderStatus == OrderStatus.Success, x => x.OrderDetails);

            if (orders?.Items != null && orders.Items.Length > 0)
            {
                foreach (var ord in orders.Items)
                {
                    ord.Money = ResolveMerchantMoney(ord);
                }

                var deliveryIds = orders.Items
                    .Where(x => x.DeliveryId.HasValue && x.DeliveryId.Value != Guid.Empty)
                    .Select(x => x.DeliveryId.Value)
                    .Distinct()
                    .ToArray();

                if (deliveryIds.Length > 0)
                {
                    var deliveryUsers = await _userManager.Users
                        .Where(u => deliveryIds.Contains(u.Id))
                        .Select(u => new { u.Id, u.PhoneNumber, u.FullName })
                        .ToDictionaryAsync(u => u.Id);

                    foreach (var ord in orders.Items)
                    {
                        if (ord.DeliveryId.HasValue && deliveryUsers.TryGetValue(ord.DeliveryId.Value, out var delUser))
                        {
                            ord.DeliveryUserPhone = delUser.PhoneNumber;
                            if (string.IsNullOrWhiteSpace(ord.DeliveryUser))
                            {
                                ord.DeliveryUser = delUser.FullName;
                            }
                        }
                    }
                }
            }

            return orders;
        }

        [HttpPost]
        [Route("Accept/{id}")]
        public async Task<ActionResult<bool>> MerchantAccept(int id, [FromBody] OrderActionRequestDto dto = null)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var merchantIds = await _merchantService.GetMerchantIds(uid.Value);
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            var matchingDetails = currentOrder.OrderDetails.Where(x => merchantIds.Contains(x.MerchantId)).ToList();
            if (!matchingDetails.Any())
                return NotFound();

            if (_transitionService != null)
            {
                foreach (var mid in merchantIds)
                {
                    if (currentOrder.OrderDetails.Any(x => x.MerchantId == mid))
                    {
                        await _transitionService.TransitionMerchantOrderAsync(id, mid, OrderDetailStatus.MerchantAccepted, dto?.Reason, uid.Value);
                    }
                }
            }
            else
            {
                await _service.MerchantAccept(id, merchantIds);
            }

            // Matching starts only after every active item from this (single) merchant
            // has been accepted. The three-minute clock is server-owned.
            var acceptedOrder = await _service.FindAsync(id);
            var activeDetails = acceptedOrder?.OrderDetails?.Where(x =>
                x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).ToArray() ?? Array.Empty<OrderDetail>();
            if (acceptedOrder != null && activeDetails.Length > 0 &&
                activeDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted) &&
                (!acceptedOrder.DeliveryId.HasValue || acceptedOrder.DeliveryId == Guid.Empty) &&
                !acceptedOrder.CourierMatchingStartedAtUtc.HasValue)
            {
                var matchingStarted = DateTime.UtcNow;
                acceptedOrder.CourierMatchingRound = Math.Max(1, acceptedOrder.CourierMatchingRound + 1);
                acceptedOrder.CourierMatchingStartedAtUtc = matchingStarted;
                acceptedOrder.CourierMatchingDeadlineAtUtc = matchingStarted.AddMinutes(3);
                acceptedOrder.CourierMatchingCompletedAtUtc = null;
                await _uow.SaveChangesAsync();
                if (_trackingHub != null)
                    await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnCourierMatchingStarted", new
                    {
                        orderId = id,
                        deadlineAtUtc = acceptedOrder.CourierMatchingDeadlineAtUtc
                    });
            }

            var firstDetail = matchingDetails.FirstOrDefault();
            var currentMerchant = firstDetail != null ? await _merchantService.FindAsync(firstDetail.MerchantId) : null;
            var acceptedMerchantTitle = currentMerchant?.MerchantKind == MerchantKind.DarkStore
                ? "جيتك ماركت"
                : (currentMerchant?.Title ?? firstDetail?.MerchantTitle ?? "المتجر");

            var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
            if (admins.Length > 0)
                await _notificationService.SendAdminMerchantDecision(admins, id, true, acceptedMerchantTitle, dto?.Reason);
            return true;
        }

        [HttpPost]
        [Route("Reject/{id}")]
        public async Task<ActionResult<bool>> MerchantReject(int id, [FromBody] OrderActionRequestDto dto = null)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var merchantIds = await _merchantService.GetMerchantIds(uid.Value);

            var order = await _service.FindAsync(id);
            if (order == null)
                return NotFound();
            if (order.CourierMatchingCompletedAtUtc.HasValue &&
                order.DeliveryId.HasValue && order.DeliveryId != Guid.Empty)
                return Conflict(ApiErr.Create("تم تأكيد استلام الطلب من السائق، لا يمكن رفضه الآن."));
            if (string.IsNullOrWhiteSpace(dto?.Reason))
                return BadRequest(ApiErr.Create("يجب تحديد سبب رفض الطلب."));

            var customerIds = new[] { order.UserId };

            var merchantOrderDetails = order.OrderDetails
                .Where(x => merchantIds.Contains(x.MerchantId) && 
                            (x.OrderDetailStatus == OrderDetailStatus.Pending || 
                             x.OrderDetailStatus == OrderDetailStatus.MerchantAccepted))
                .ToArray();

            if (merchantOrderDetails.Length == 0)
            {
                var alreadyRejected = order.OrderDetails.Any(x => merchantIds.Contains(x.MerchantId) && x.OrderDetailStatus == OrderDetailStatus.MerchantRejected);
                if (alreadyRejected)
                    return Ok(true); // Idempotent

                return BadRequest(ApiErr.Create("تم اتخاذ قرار بشأن هذا الطلب مسبقاً ولا يمكن رفضه الآن."));
            }

            // Release reservation for this merchant's items
            foreach (var mid in merchantIds)
            {
                if (order.OrderDetails.Any(x => x.MerchantId == mid))
                {
                    await _batchService.ReleaseReservationAsync(id, reason: dto.Reason, merchantId: mid);
                    if (_transitionService != null)
                    {
                        await _transitionService.TransitionMerchantOrderAsync(id, mid, OrderDetailStatus.MerchantRejected, dto.Reason, User.GetUserId());
                    }
                    else
                    {
                        var detailsForMid = merchantOrderDetails.Where(x => x.MerchantId == mid).ToArray();
                        foreach (var mod in detailsForMid)
                        {
                            mod.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
                            mod.Warning = dto.Reason.Trim();
                        }
                        _service.Log(id, OrderDetailStatus.MerchantRejected, detailsForMid);
                        await _uow.SaveChangesAsync();
                    }
                }
            }

            order.Notes = dto.Reason.Trim();
            await _uow.SaveChangesAsync();

            // A merchant rejection is final for that merchant's part of the order.
            // Never silently reroute the customer's purchase to another store.
            var rejectedMerchant = await _merchantService.FindAsync(merchantOrderDetails.FirstOrDefault()?.MerchantId ?? 0);
            var rejectedMerchantTitle = rejectedMerchant?.MerchantKind == MerchantKind.DarkStore
                ? "جيتك ماركت"
                : (rejectedMerchant?.Title ?? merchantOrderDetails.FirstOrDefault()?.MerchantTitle ?? "المتجر");
            await _notificationService.SendCustomerOrderRejected(customerIds, id, rejectedMerchantTitle, dto.Reason);

            var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
            if (admins.Length > 0)
                await _notificationService.SendAdminMerchantDecision(admins, id, false, rejectedMerchantTitle, dto.Reason);

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
            if (!uid.HasValue) return Unauthorized();
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var order = await _service.Queryable()
                                      .Include(x => x.OrderDetails)
                                      .FirstOrDefaultAsync(x => x.Id == id &&
                                      x.OrderDetails.Any(d => mids.Contains(d.MerchantId)) &&
                                      x.OrderStatus == OrderStatus.Success);

            if (order == null)
                return NotFound();

            var result = new OrderDto
            {
                Id = order.Id,
                UserId = order.UserId,
                Description = order.Description,
                Notes = order.Notes,
                Phonenumber = order.Phonenumber,
                OrderStatus = order.OrderStatus,
                PurchaseDate = order.PurchaseDate,
                CreatedDate = order.CreatedDate,
                User = order.User,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                PaymentMethod = order.PaymentMethod,
                DeliveryFee = order.DeliveryFee,
                MoneySnapshotVersion = order.MoneySnapshotVersion,
                CaptainEarning = order.CaptainEarning,
                DeliveryId = order.DeliveryId,
                CourierMatchingStartedAtUtc = order.CourierMatchingStartedAtUtc,
                CourierMatchingDeadlineAtUtc = order.CourierMatchingDeadlineAtUtc,
                CourierMatchingCompletedAtUtc = order.CourierMatchingCompletedAtUtc,
                DeliveryUser = order.DeliveryUser,
                DeliveryNotes = order.DeliveryNotes,
                DeliveredAt = order.DeliveredAt,
                OrderDetails = order.OrderDetails.Where(d => mids.Contains(d.MerchantId))
                                    .Select(d => d.ToDto()).ToArray()
            };

            result.Money = ResolveMerchantMoney(result);

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

        private CanonicalOrderMoneyDto ResolveMerchantMoney(OrderDto order)
        {
            if (_moneyCalculationService == null) return null;
            var details = order.OrderDetails ?? Array.Empty<OrderDetailDto>();
            var commissions = details.GroupBy(x => x.MerchantId).Select(g => new MerchantCommissionInfo
            {
                MerchantId = g.Key,
                MerchantTitle = g.FirstOrDefault()?.MerchantTitle,
                CommissionRatePercent = g.FirstOrDefault()?.CommissionRatePercent ?? 0m,
                IsDarkStore = g.All(x => x.IsPlatformOwnedSnapshot)
            });
            return _moneyCalculationService.CalculateOrderMoney(
                details,
                order.DeliveryFee,
                order.PaymentMethod,
                merchantCommissionInfos: commissions,
                captainEarning: order.MoneySnapshotVersion > 0 ? order.CaptainEarning : order.DeliveryFee,
                currency: details.FirstOrDefault()?.Currency.ToString() ?? "SYP",
                commissionIsMarkup: order.MoneySnapshotVersion == 2,
                commissionIsPercentageOfGross: order.MoneySnapshotVersion >= 3);
        }

        /// <summary>
        /// Mark order as prepared and ready for courier pickup
        /// </summary>
        [HttpPost]
        [Route("Ready/{id}")]
        public async Task<ActionResult<bool>> MarkReady(int id, [FromBody] OrderActionRequestDto dto = null)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var merchantIds = await _merchantService.GetMerchantIds(uid.Value);
            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();

            if (order.CourierMatchingStartedAtUtc.HasValue &&
                (!order.DeliveryId.HasValue || order.DeliveryId == Guid.Empty))
            {
                return Conflict(ApiErr.Create("سيبدأ تجهيز الطلب بعد تأكيد استلامه من أحد سائقي التوصيل."));
            }

            var wasAvailableToDrivers =
                (!order.DeliveryId.HasValue || order.DeliveryId.Value == Guid.Empty) &&
                order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);

            var matchingDetails = order.OrderDetails.Where(x => merchantIds.Contains(x.MerchantId)).ToList();
            if (!matchingDetails.Any()) return NotFound();

            if (_transitionService != null)
            {
                foreach (var mid in merchantIds)
                {
                    if (order.OrderDetails.Any(x => x.MerchantId == mid))
                    {
                        await _transitionService.TransitionMerchantOrderAsync(id, mid, OrderDetailStatus.ReadyForPickup, dto?.Reason, uid.Value);
                        await _batchService.DeductReservedStockAsync(id, merchantId: mid);
                    }
                }
            }
            else
            {
                await _service.MerchantMarkReady(id, merchantIds);
                foreach (var mid in merchantIds)
                {
                    await _batchService.DeductReservedStockAsync(id, merchantId: mid);
                }
            }

            var currentMerchant = merchantIds.Length > 0 ? await _merchantService.FindAsync(merchantIds[0]) : null;
            var merchantTitle = currentMerchant?.MerchantKind == MerchantKind.DarkStore
                ? "جيتك ماركت"
                : (currentMerchant?.Title ?? "المتجر");

            if (order.DeliveryId.HasValue)
                await _notificationService.SendDeliveryOrderReadyForPickup(new[] { order.DeliveryId.Value }, id, merchantTitle);
            else
            {
                var latestOrder = await _service.Queryable()
                    .Include(x => x.OrderDetails)
                    .FirstOrDefaultAsync(x => x.Id == id);
                var isAvailableToDrivers = latestOrder != null &&
                    (!latestOrder.DeliveryId.HasValue || latestOrder.DeliveryId.Value == Guid.Empty) &&
                    latestOrder.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);

                if (!wasAvailableToDrivers && isAvailableToDrivers)
                {
                    var onlineDrivers = await _deliveryService.GetOnlineDeliveryIds();
                    if (onlineDrivers.Length > 0)
                    {
                        await _notificationService.SendDeliveryNewOrderRecived(
                            onlineDrivers, id, latestOrder.OrderDetails.ToArray());
                    }
                }
            }

            var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
            if (admins.Length > 0)
                await _notificationService.SendAdminOrderReadyForAssignment(admins, id, merchantTitle);

            if (order.UserId != Guid.Empty)
            {
                await _notificationService.SendCustomerOrderReadyForPickup(new[] { order.UserId }, id, merchantTitle);
            }

            if (_trackingHub != null)
            {
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnOrderReadyForPickup", new { orderId = id, merchantTitle });
                if (order.DeliveryId.HasValue)
                {
                    await _trackingHub.Clients.User(order.DeliveryId.Value.ToString()).SendAsync("OnOrderReadyForPickup", new { orderId = id, merchantTitle });
                }
            }
            return Ok(true);
        }

        /// <summary>
        /// Get the warehouse picking list with shelf/bin locations, batch numbers, and barcodes
        /// </summary>
        [HttpGet("{id}/PickingList")]
        public async Task<ActionResult<List<WarehousePickingItemDto>>> GetPickingList(int id)
        {
            var userId = User.GetUserId();
            var mids = userId.HasValue ? await _merchantService.GetMerchantIds(userId.Value) : Array.Empty<int>();

            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();

            var relevantDetails = order.OrderDetails
                .Where(d => mids.Contains(d.MerchantId) &&
                            d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                .ToList();

            var reservations = await _batchService.GetOrderReservationsAsync(id);

            var pickingItems = new List<WarehousePickingItemDto>();
            foreach (var detail in relevantDetails)
            {
                var detailReservations = reservations
                    .Where(r => r.OrderDetailId == detail.Id && !r.IsReleased && !r.IsDeducted)
                    .ToList();
                var matchingRes = detailReservations.FirstOrDefault();

                pickingItems.Add(new WarehousePickingItemDto
                {
                    OrderDetailId = detail.Id,
                    ProductId = detail.ProductId,
                    ProductTitle = detail.ProductTitle,
                    ProductImage = detail.ProductImage,
                    ProductUnit = detail.ProductUnit,
                    Quantity = detail.Quantity,
                    LocationBin = matchingRes?.LocationBin ?? "General Shelf",
                    BatchNumber = matchingRes?.BatchNumber,
                    Barcode = matchingRes?.Barcode,
                    ExpirationDate = matchingRes?.ExpirationDate,
                    // For batch-managed lines, every allocated batch must be
                    // picked. MerchantAccepted alone is not a picking event.
                    IsPicked = detailReservations.Count > 0
                        ? detailReservations.All(r => r.IsPicked)
                        : detail.OrderDetailStatus == OrderDetailStatus.MerchantAccepted
                });
            }

            return Ok(pickingItems);
        }

        /// <summary>
        /// Verify scanned barcode against the order item and assigned batch
        /// </summary>
        [HttpPost("{id}/PickItem")]
        public async Task<ActionResult<BatchPickResultDto>> PickItem(int id, [FromBody] BatchPickVerificationDto dto)
        {
            if (dto == null) return BadRequest("Invalid verification payload.");
            dto.OrderId = id;

            var userId = User.GetUserId();
            var merchantIds = userId.HasValue ? await _merchantService.GetMerchantIds(userId.Value) : Array.Empty<int>();

            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();
            if (order.CourierMatchingStartedAtUtc.HasValue &&
                (!order.DeliveryId.HasValue || order.DeliveryId == Guid.Empty))
                return Conflict(ApiErr.Create("لا يمكن بدء تجهيز الطلب قبل تأكيد استلامه من سائق."));

            var detail = order.OrderDetails.FirstOrDefault(d => d.Id == dto.OrderDetailId);
            if (detail == null)
                return NotFound("Order detail item not found.");

            if (!merchantIds.Contains(detail.MerchantId))
                return Forbid();

            var userName = User.Identity?.Name ?? userId?.ToString() ?? "Warehouse";
            var result = await _batchService.VerifyPickItemBarcodeAsync(id, dto.OrderDetailId, dto.ScannedBarcode, pickedBy: userName, merchantId: detail.MerchantId);
            return Ok(result);
        }

        /// <summary>
        /// Complete picking and packing: deducts reserved stock and dispatches order
        /// </summary>
        [HttpPost("{id}/CompletePicking")]
        public async Task<ActionResult<bool>> CompletePicking(int id)
        {
            var userId = User.GetUserId();
            var merchantIds = userId.HasValue ? await _merchantService.GetMerchantIds(userId.Value) : Array.Empty<int>();

            var order = await _service.FindAsync(id);
            if (order == null) return NotFound();
            if (order.CourierMatchingStartedAtUtc.HasValue &&
                (!order.DeliveryId.HasValue || order.DeliveryId == Guid.Empty))
                return Conflict(ApiErr.Create("لا يمكن تجهيز الطلب قبل تأكيد استلامه من سائق."));

            // Verify that all batch-managed reservations for this merchant's order details are picked
            var reservations = await _batchService.GetOrderReservationsAsync(id);
            var merchantDetailIds = order.OrderDetails.Where(d => merchantIds.Contains(d.MerchantId)).Select(d => d.Id).ToHashSet();
            var unpickedReservations = reservations
                .Where(r => merchantDetailIds.Contains(r.OrderDetailId) && !r.IsReleased && !r.IsDeducted && !r.IsPicked)
                .ToList();

            if (unpickedReservations.Any())
            {
                return BadRequest(ApiErr.Create("لا يمكن إتمام التجهيز قبل فحص جميع المنتجات المطلوبة وتأكيد الباركود الخاص بها."));
            }

            // Permanently deduct reserved stock for fulfilled items scoped strictly to this merchant
            foreach (var mid in merchantIds)
            {
                await _batchService.DeductReservedStockAsync(id, merchantId: mid);
            }

            await _service.MerchantAccept(id, merchantIds);
            return await MarkReady(id);
        }
    }

    public class OrderActionRequestDto
    {
        public int? PrepMinutes { get; set; }
        public string Reason { get; set; }
    }
}
