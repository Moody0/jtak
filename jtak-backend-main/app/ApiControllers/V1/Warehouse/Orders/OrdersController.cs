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
            var mids = await _merchantService.GetMerchantIds(uid.Value);
            var threeDaysAgo = DateTime.UtcNow.AddDays(-3);
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
                    DeliveryId = x.DeliveryId,
                    DeliveryUser = x.DeliveryUser,
                    OrderDetails = x.OrderDetails.Where(d => mids.Contains(d.MerchantId)).Select(d => d.ToDto()).ToArray()
                }, x =>
                x.OrderDetails.Any(d => mids.Contains(d.MerchantId))
                && x.OrderStatus == OrderStatus.Success
                && x.PurchaseDate > threeDaysAgo, x => x.OrderDetails);
            return orders;
        }

        [HttpPost]
        [Route("Accept/{id}")]
        public async Task<ActionResult<bool>> MerchantAccept(int id, [FromBody] OrderActionRequestDto dto = null)
        {
            var merchantIds = await _merchantService.GetMerchantIds(User.GetUserId().Value);
            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();
            var order = await _service.MerchantAccept(id, merchantIds);
            var firstDetail = order.OrderDetails.FirstOrDefault(x => merchantIds.Contains(x.MerchantId));
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
            var merchantIds = await _merchantService.GetMerchantIds(User.GetUserId().Value);

            var order = await _service.FindAsync(id);
            if (order == null)
                return NotFound();
            if (string.IsNullOrWhiteSpace(dto?.Reason))
                return BadRequest(ApiErr.Create("يجب تحديد سبب رفض الطلب."));

            var customerIds = new[] { order.UserId };

            var merchantOrderDetails = order.OrderDetails
                .Where(x => merchantIds.Contains(x.MerchantId) && x.OrderDetailStatus == OrderDetailStatus.Pending)
                .ToArray();
            if (merchantOrderDetails.Length == 0)
                return BadRequest(ApiErr.Create("تم اتخاذ قرار بشأن هذا الطلب مسبقاً ولا يمكن رفضه الآن."));

            // Release reservation for this merchant's items
            foreach (var mod in merchantOrderDetails)
            {
                await _batchService.ReleaseReservationAsync(id, mod.Id, reason: dto.Reason);
            }

            // Update Merchant Order Detail Statuses
            foreach (var merchantOrderdetail in merchantOrderDetails)
            {
                merchantOrderdetail.OrderDetailStatus = OrderDetailStatus.MerchantRejected;
                merchantOrderdetail.Warning = dto.Reason.Trim();
            }
            order.Notes = dto.Reason.Trim();
            _service.Log(id, OrderDetailStatus.MerchantRejected, merchantOrderDetails);
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
                DeliveryId = order.DeliveryId,
                DeliveryUser = order.DeliveryUser,
                OrderDetails = order.OrderDetails.Where(d => mids.Contains(d.MerchantId))
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
        /// Mark order as prepared and ready for courier pickup
        /// </summary>
        [HttpPost]
        [Route("Ready/{id}")]
        public async Task<ActionResult<bool>> MarkReady(int id, [FromBody] OrderActionRequestDto dto = null)
        {
            var merchantIds = await _merchantService.GetMerchantIds(User.GetUserId().Value);
            var order = await _service.MerchantMarkReady(id, merchantIds);
            if (order == null) return NotFound();

            // Deduct reserved stock upon readiness scoped strictly to this merchant's items
            foreach (var mid in merchantIds)
            {
                await _batchService.DeductReservedStockAsync(id, merchantId: mid);
            }

            var currentMerchant = merchantIds.Length > 0 ? await _merchantService.FindAsync(merchantIds[0]) : null;
            var merchantTitle = currentMerchant?.MerchantKind == MerchantKind.DarkStore
                ? "جيتك ماركت"
                : (currentMerchant?.Title ?? "المتجر");

            if (order.DeliveryId.HasValue)
                await _notificationService.SendDeliveryOrderReadyForPickup(new[] { order.DeliveryId.Value }, id, merchantTitle);

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
