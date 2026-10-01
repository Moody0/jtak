using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using App.Helpers;
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
using App.Shared.Services.Pricing;
using Modules.Accounting.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using App.Orders.Data;
using Modules.Shipping.Entities;
using Microsoft.AspNetCore.SignalR;
using App.Shared.Services.Hubs;
using Microsoft.Extensions.Logging;

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
        private readonly DriverFinancialSafetyService _financialSafety;
        private readonly IAccountingUnitOfWork _auow;
        private readonly IInventoryBatchService _batchService;
        private readonly IProductService _productService;
        private readonly IHubContext<TrackingHub> _trackingHub;
        private readonly IOrdersUnitOfWork _ouow;
        private readonly ILogger<OrdersController> _logger;
        private readonly IOrderMoneyCalculationService _moneyCalculationService;
        private readonly IWebHostEnvironment _env;
        private static readonly object _claimLock = new object();

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
            IMapper mapper,
            ILogger<OrdersController> logger = null,
            IOrderMoneyCalculationService moneyCalculationService = null,
            IWebHostEnvironment env = null, DriverFinancialSafetyService financialSafety = null)
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
            _financialSafety = financialSafety;
            _batchService = batchService;
            _trackingHub = trackingHub;
            _logger = logger;
            _moneyCalculationService = moneyCalculationService;
            _env = env;
        }


        private async Task<DeliveryOrderDto[]> BuildDeliveryOrderDtosAsync(IEnumerable<OrderDto> orderDtos, Guid? currentDriverId = null)
        {
            var dtosList = orderDtos?.ToList() ?? new List<OrderDto>();
            if (dtosList.Count == 0) return Array.Empty<DeliveryOrderDto>();

            // Keep terminal detail statuses in the delivery payload. The mobile
            // client needs them to distinguish completed/canceled history from
            // an order that is still pending.
            var allDetails = dtosList
                .Where(x => x.OrderDetails != null)
                .SelectMany(x => x.OrderDetails)
                .ToArray();

            var merchantIds = allDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var merchants = new Dictionary<int, dynamic>();
            try
            {
                var mList = await _merchantService.Queryable()
                    .Where(m => merchantIds.Contains(m.Id))
                    .Select(m => new { m.Id, m.Title, m.Lat, m.Lng, m.MerchantKind, m.Address, m.Photo, Phone = m.Phone1 ?? m.Phone2 })
                    .ToListAsync();
                merchants = mList.ToDictionary(m => m.Id, m => (dynamic)m);
            }
            catch
            {
                var mList = _merchantService.Queryable()
                    .Where(m => merchantIds.Contains(m.Id))
                    .Select(m => new { m.Id, m.Title, m.Lat, m.Lng, m.MerchantKind, m.Address, m.Photo, Phone = m.Phone1 ?? m.Phone2 })
                    .ToList();
                merchants = mList.ToDictionary(m => m.Id, m => (dynamic)m);
            }

            var productIds = allDetails.Where(d => string.IsNullOrEmpty(d.ProductImage)).Select(d => d.ProductId).Distinct().ToArray();
            var productPhotos = new Dictionary<int, string>();
            if (productIds.Length > 0)
            {
                try
                {
                    productPhotos = await _productService.Queryable()
                        .Where(p => productIds.Contains(p.Id))
                        .Select(p => new { p.Id, p.Photos })
                        .ToDictionaryAsync(p => p.Id, p => p.Photos);
                }
                catch
                {
                    productPhotos = _productService.Queryable()
                        .Where(p => productIds.Contains(p.Id))
                        .Select(p => new { p.Id, p.Photos })
                        .ToDictionary(p => p.Id, p => p.Photos);
                }
            }

            var result = dtosList.Select(x =>
            {
                var validDetails = (x.OrderDetails ?? Array.Empty<OrderDetailDto>()).ToArray();

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
                    DeliveredAt = x.DeliveredAt,
                    PaymentMethod = x.PaymentMethod,
                    Phonenumber = x.Phonenumber,
                    PurchaseDate = x.PurchaseDate,
                    UserId = x.UserId,
                    User = x.User,
                    DeliveryFee = x.DeliveryFee,
                    MoneySnapshotVersion = x.MoneySnapshotVersion,
                    CaptainEarning = x.CaptainEarning,
                    CourierMatchingDeadlineAtUtc = x.CourierMatchingDeadlineAtUtc,
                    Money = (!string.IsNullOrWhiteSpace(x.MoneySnapshotJson) ? OrderMoneySnapshot.Deserialize(x.MoneySnapshotJson) : null) ?? x.Money ?? CalculateCanonicalMoney(x.OrderDetails, x.DeliveryFee, x.PaymentMethod,
                        x.CaptainEarning, x.MoneySnapshotVersion == 2, x.MoneySnapshotVersion >= 3),
                    OrderDetails = groupedMerchants
                };
            }).ToArray();

            if (currentDriverId.HasValue)
            {
                var orderIds = dtosList.Select(x => x.Id).ToArray();
                var now = DateTime.UtcNow;
                var activeOffers = await _ouow.Context.OrderDispatchOffers.AsNoTracking()
                    .Where(x => orderIds.Contains(x.OrderId) && x.DriverId == currentDriverId.Value &&
                                x.Status == OrderDispatchOfferStatus.Offered && x.ExpiresAtUtc > now)
                    .ToDictionaryAsync(x => x.OrderId, x => x.ExpiresAtUtc);
                foreach (var dto in dtosList)
                {
                    if (activeOffers.TryGetValue(dto.Id, out var expiresAt))
                    {
                        var target = result.FirstOrDefault(x => x.Id == dto.Id);
                        if (target != null) target.OfferExpiresAtUtc = expiresAt;
                    }
                }
            }
            return result;
        }

        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<TableResponseModel<DeliveryOrderDto>>> PostMine([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            if (request != null && request.PageNumber > 0)
                request.PageNumber -= 1;

            var orders = await _service.ListMetronicTableQueryable(request,
                x => new OrderDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    Description = x.Description,
                    Phonenumber = x.Phonenumber,
                    PaymentMethod = x.PaymentMethod,
                    OrderStatus = x.OrderStatus,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = x.User,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    Address = x.Address,
                    DeliveryFee = x.DeliveryFee,
                    MoneySnapshotVersion = x.MoneySnapshotVersion,
                    MoneySnapshotJson = x.MoneySnapshotJson,
                    CaptainEarning = x.CaptainEarning,
                    DistanceInKm = x.DistanceInKm,
                    CustomerRatePerKm = x.CustomerRatePerKm,
                    OriginalDeliveryFee = x.OriginalDeliveryFee,
                    CaptainCompensationType = x.CaptainCompensationType,
                    CaptainRate = x.CaptainRate,
                    OrderDetails = x.OrderDetails.Select(d => d.ToDto()).ToArray()
                }, x => x.DeliveryId == uid &&
                x.OrderStatus == OrderStatus.Success,
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
        /// Get a paged/filtered list of Available (unassigned approved) Orders for couriers to claim.
        /// Protects customer privacy by masking customer phone, coarsening delivery coordinates,
        /// and hiding exact door/street addresses before claim.
        /// </summary>
        [HttpPost]
        [Route("Available")]
        public async Task<ActionResult<TableResponseModel<DeliveryOrderDto>>> PostAvailable([FromBody] MetronicTable request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            if (!(await _deliveryService.GetDeliveryStatus(uid.Value)).IsOnline)
            {
                return Ok(new TableResponseModel<DeliveryOrderDto>
                {
                    Items = Array.Empty<DeliveryOrderDto>(),
                    TotalRecords = 0,
                    TotalRecordsFiltered = 0
                });
            }

            var timeTurkey = TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time"));
            var dayStart = timeTurkey.Date.AddDays(-2);
            var nowUtc = DateTime.UtcNow;

            if (request != null && request.PageNumber > 0)
                request.PageNumber -= 1;

            var orders = await _service.ListMetronicTableQueryable(request,
                x => new OrderDto
                {
                    Id = x.Id,
                    UserId = x.UserId,
                    Description = x.Description,
                    Phonenumber = null, // Masked before assignment for privacy
                    PaymentMethod = x.PaymentMethod,
                    OrderStatus = x.OrderStatus,
                    PurchaseDate = x.PurchaseDate,
                    CreatedDate = x.CreatedDate,
                    User = "عميل جتك", // Coarsened before assignment
                    Lat = Math.Round(x.Lat, 2), // Coarsened ~1.1km grid
                    Lng = Math.Round(x.Lng, 2), // Coarsened ~1.1km grid
                    Address = !string.IsNullOrWhiteSpace(x.Address) ? "المنطقة العامة (مخفي حتى الاستلام)" : null,
                    DeliveryFee = x.DeliveryFee,
                    MoneySnapshotVersion = x.MoneySnapshotVersion,
                    MoneySnapshotJson = x.MoneySnapshotJson,
                    CaptainEarning = x.CaptainEarning,
                    DistanceInKm = x.DistanceInKm,
                    CustomerRatePerKm = x.CustomerRatePerKm,
                    OriginalDeliveryFee = x.OriginalDeliveryFee,
                    CaptainCompensationType = x.CaptainCompensationType,
                    CaptainRate = x.CaptainRate,
                    CourierMatchingStartedAtUtc = x.CourierMatchingStartedAtUtc,
                    CourierMatchingDeadlineAtUtc = x.CourierMatchingDeadlineAtUtc,
                    CourierMatchingCompletedAtUtc = x.CourierMatchingCompletedAtUtc,
                    CourierMatchingRound = x.CourierMatchingRound,
                    OrderDetails = x.OrderDetails.Select(d => d.ToDto()).ToArray()
                },
                x => (x.DeliveryId == null || x.DeliveryId == Guid.Empty) &&
                     x.OrderStatus == OrderStatus.Success &&
                     ((x.CourierMatchingStartedAtUtc == null &&
                       x.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup)) ||
                      (x.CourierMatchingStartedAtUtc != null &&
                       x.CourierMatchingCompletedAtUtc == null &&
                       x.CourierMatchingDeadlineAtUtc > nowUtc &&
                       _ouow.Context.OrderDispatchOffers.Any(o => o.OrderId == x.Id &&
                           o.DriverId == uid.Value && o.MatchingRound == x.CourierMatchingRound &&
                           (o.Status == OrderDispatchOfferStatus.Offered ||
                            o.Status == OrderDispatchOfferStatus.TimedOut)))) &&
                     (x.PurchaseDate != null ? x.PurchaseDate > dayStart : x.CreatedDate > dayStart),
                x => x.OrderDetails);

            var result = new TableResponseModel<DeliveryOrderDto>()
            {
                Items = await BuildDeliveryOrderDtosAsync(orders.Items, uid.Value),
                Error = orders.Error,
                TotalRecords = orders.TotalRecords,
                TotalRecordsFiltered = orders.TotalRecordsFiltered
            };
            return result;
        }

        /// <summary>
        /// Courier claims an available unassigned order using atomic conditional update
        /// and individual driver configured MaxCashFloat verification.
        /// </summary>
        [HttpPost]
        [Route("Claim/{id}")]
        public async Task<ActionResult<bool>> ClaimOrder(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var safety = _financialSafety ?? new DriverFinancialSafetyService(_auow.Context, _ledgerService, orders: _ouow.Context);
            try { return await safety.WithDriverLockAsync(uid.Value, () => ClaimOrderCore(id, safety)); }
            catch (InvalidOperationException ex) { return BadRequest(ApiErr.Create(ex.Message)); }
        }

        private async Task<ActionResult<bool>> ClaimOrderCore(int id, DriverFinancialSafetyService safety)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue)
                return Unauthorized();

            var order = await _ouow.Context.Orders
                .Include(x => x.OrderDetails)
                .FirstOrDefaultAsync(x => x.Id == id);
            if (order == null)
                return NotFound(ApiErr.Create("الطلب غير موجود."));

            if (order.DeliveryId.HasValue && order.DeliveryId.Value != Guid.Empty)
                return BadRequest(ApiErr.Create("تم استلام هذا الطلب بالفعل من قبل كابتن آخر."));

            if (order.OrderStatus != OrderStatus.Success)
                return BadRequest(ApiErr.Create("الطلب غير متاح للاستلام حالياً."));

            var isInCourierMatching = order.CourierMatchingStartedAtUtc.HasValue &&
                                      !order.CourierMatchingCompletedAtUtc.HasValue &&
                                      order.CourierMatchingDeadlineAtUtc > DateTime.UtcNow;
            var hasClaimableOffer = isInCourierMatching && await _ouow.Context.OrderDispatchOffers.AnyAsync(x =>
                x.OrderId == id && x.DriverId == uid.Value &&
                x.MatchingRound == order.CourierMatchingRound &&
                (x.Status == OrderDispatchOfferStatus.Offered ||
                 x.Status == OrderDispatchOfferStatus.TimedOut));
            var hasLegacyReadyDetails = order.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
            if ((isInCourierMatching && !hasClaimableOffer) || (!isInCourierMatching && !hasLegacyReadyDetails))
                return BadRequest(ApiErr.Create("لم يتم إرسال عرض استلام صالح لهذا الطلب إلى حسابك."));

            var courier = await _userManager.FindByIdAsync(uid.Value.ToString());
            if (courier == null)
                return BadRequest(ApiErr.Create("بيانات السائق غير متوفرة."));

            if (!(await _deliveryService.GetDeliveryStatus(uid.Value)).IsOnline)
                return BadRequest(ApiErr.Create("يجب بدء وردية التوصيل قبل استلام طلب جديد."));

            // Enforce Driver COD Cash Custody Limit against individual configured MaxCashFloat
            decimal maxFloat = courier.MaxCashFloat > 0 ? courier.MaxCashFloat : 5000000m;

            var position = await safety.GetPositionAsync(uid.Value, excludeOrderId: id);
            if (position.HasUnfinishedAccounting)
                return BadRequest(ApiErr.Create("توجد عمليات محاسبية معلّقة للمندوب. أكملها قبل إسناد طلب جديد."));
            var currentFloat = position.Cash + position.ExpectedCollections;

            decimal projectedCod = 0m;
            if (order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery)
            {
                var details = order.OrderDetails?.Where(x =>
                    x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                    x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).ToArray();

                var money = CalculateCanonicalMoney(details?.Select(x => x.ToDto()), order.DeliveryFee, order.PaymentMethod,
                    order.CaptainEarning, order.MoneySnapshotVersion == 2, order.MoneySnapshotVersion >= 3);
                projectedCod = money?.CashToCollect ?? details?.Sum(x => x.Quantity * x.SingleFinalPrice) ?? 0m;
            }

            if (currentFloat + projectedCod > maxFloat)
            {
                if (projectedCod > maxFloat)
                {
                    return BadRequest(ApiErr.Create($"قيمة الطلب النقدية ({projectedCod:N0} ل.س) تتجاوز سقف العهدة النقدية المسموح به لك ({maxFloat:N0} ل.س)."));
                }
                return BadRequest(ApiErr.Create($"استلام هذا الطلب سيتجاوز الحد الأقصى للعهدة النقدية المسموح بها ({maxFloat:N0} ل.س). عهدتك الحالية: {currentFloat:N0} ل.س، وقيمة الطلب: {projectedCod:N0} ل.س."));
            }

            // Atomic Conditional Update: Only one concurrent claiming driver can succeed
            var courierName = courier.FullName ?? courier.UserName ?? "Delivery Courier";
            bool claimWon = false;

            // Prepare captain snapshot prior to atomic conditional update
            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, courier);
            var compTypeVal = order.CaptainCompensationType.HasValue ? (int)order.CaptainCompensationType.Value : 0;

            if (_ouow.Context.Database.IsRelational())
            {
                var now = DateTime.UtcNow;
                var affected = await _ouow.Context.Database.ExecuteSqlInterpolatedAsync($@"
                    UPDATE Orders_Orders AS o
                    SET DeliveryId = {uid.Value},
                        DeliveryUser = {courierName},
                        DistanceInKm = {order.DistanceInKm},
                        CustomerRatePerKm = {order.CustomerRatePerKm},
                        OriginalDeliveryFee = {order.OriginalDeliveryFee},
                        CaptainCompensationType = {compTypeVal},
                        CaptainRate = {order.CaptainRate},
                        CaptainEarning = {order.CaptainEarning},
                        MoneySnapshotJson = {order.MoneySnapshotJson},
                        RowVersion = RowVersion + 1,
                        UpdatedDate = {now}
                    WHERE o.Id = {id}
                      AND (DeliveryId IS NULL OR DeliveryId = '00000000-0000-0000-0000-000000000000')
                      AND OrderStatus = {(int)OrderStatus.Success}
                      AND (
                          (
                              o.CourierMatchingStartedAtUtc IS NOT NULL
                              AND o.CourierMatchingCompletedAtUtc IS NULL
                              AND o.CourierMatchingDeadlineAtUtc > {now}
                              AND EXISTS (
                                  SELECT 1 FROM Orders_OrderDispatchOffers AS offer
                                  WHERE offer.OrderId = o.Id AND offer.DriverId = {uid.Value}
                                    AND offer.MatchingRound = o.CourierMatchingRound
                                    AND offer.Status IN ({(byte)OrderDispatchOfferStatus.Offered}, {(byte)OrderDispatchOfferStatus.TimedOut})
                              )
                          )
                          OR (
                              (o.CourierMatchingStartedAtUtc IS NULL
                               OR o.CourierMatchingCompletedAtUtc IS NOT NULL
                               OR o.CourierMatchingDeadlineAtUtc IS NULL
                               OR o.CourierMatchingDeadlineAtUtc <= {now})
                              AND EXISTS (
                                  SELECT 1 FROM Orders_OrderDetails AS d
                                  WHERE d.OrderId = o.Id
                                    AND d.OrderDetailStatus = {(int)OrderDetailStatus.ReadyForPickup}
                              )
                          )
                      )");

                claimWon = affected > 0;
                if (claimWon)
                {
                    order.DeliveryId = uid.Value;
                    order.DeliveryUser = courierName;
                    order.RowVersion++;
                    _ouow.Context.Entry(order).Property(x => x.RowVersion).OriginalValue = order.RowVersion;
                    _ouow.Context.Entry(order).OriginalValues.SetValues(order);
                }
            }
            else
            {
                // In-memory test provider thread-safe conditional check
                lock (_claimLock)
                {
                    var freshOrder = _ouow.Context.Orders.FirstOrDefault(x => x.Id == id);
                    var freshNow = DateTime.UtcNow;
                    var freshIsInCourierMatching = freshOrder != null &&
                                                   freshOrder.CourierMatchingStartedAtUtc.HasValue &&
                                                   !freshOrder.CourierMatchingCompletedAtUtc.HasValue &&
                                                   freshOrder.CourierMatchingDeadlineAtUtc > freshNow;
                    var freshHasClaimableOffer = freshIsInCourierMatching &&
                                                 _ouow.Context.OrderDispatchOffers.Any(o =>
                                                     o.OrderId == id && o.DriverId == uid.Value &&
                                                     o.MatchingRound == freshOrder.CourierMatchingRound &&
                                                     (o.Status == OrderDispatchOfferStatus.Offered ||
                                                      o.Status == OrderDispatchOfferStatus.TimedOut));
                    var freshHasLegacyReadyDetails = freshOrder != null &&
                                                     freshOrder.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
                    if (freshOrder != null &&
                        (!freshOrder.DeliveryId.HasValue || freshOrder.DeliveryId.Value == Guid.Empty) &&
                        freshOrder.OrderStatus == OrderStatus.Success &&
                        (freshIsInCourierMatching ? freshHasClaimableOffer : freshHasLegacyReadyDetails))
                    {
                        freshOrder.DeliveryId = uid.Value;
                        freshOrder.DeliveryUser = courierName;
                        freshOrder.RowVersion++;
                        DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(freshOrder, courier);
                        _ouow.Context.SaveChanges();
                        claimWon = true;
                        order.DeliveryId = uid.Value;
                        order.DeliveryUser = courierName;
                        order.DistanceInKm = freshOrder.DistanceInKm;
                        order.CustomerRatePerKm = freshOrder.CustomerRatePerKm;
                        order.OriginalDeliveryFee = freshOrder.OriginalDeliveryFee;
                        order.CaptainCompensationType = freshOrder.CaptainCompensationType;
                        order.CaptainRate = freshOrder.CaptainRate;
                        order.CaptainEarning = freshOrder.CaptainEarning;
                        order.MoneySnapshotJson = freshOrder.MoneySnapshotJson;
                    }
                }
            }

            if (!claimWon)
            {
                var assignedDriverId = await _ouow.Context.Orders.AsNoTracking()
                    .Where(x => x.Id == id)
                    .Select(x => x.DeliveryId)
                    .FirstOrDefaultAsync();
                if (assignedDriverId.HasValue && assignedDriverId.Value != Guid.Empty && assignedDriverId.Value != uid.Value)
                    return BadRequest(ApiErr.Create("تم استلام هذا الطلب بالفعل من قبل كابتن آخر."));

                return BadRequest(ApiErr.Create("تغيرت حالة الطلب ولم يعد متاحاً للاستلام. حدّث قائمة الطلبات وحاول مجدداً."));
            }

            // Create shipping route idempotently
            var customerSO = new ShippingOrderDto
            {
                OrderId = order.Id,
                DriverId = uid.Value,
                MerchantId = 0,
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

            try
            {
                await _deliveryService.AddOrder(uid.Value, id, merchantsSOs.ToArray(), customerSO);
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Failed to create shipping route for claimed order {OrderId}", id);
                await _deliveryService.CompensateOrderStops(uid.Value, id);
                if (_ouow.Context.Database.IsRelational())
                {
                    await _ouow.Context.Database.ExecuteSqlInterpolatedAsync($@"
                        UPDATE Orders_Orders
                        SET DeliveryId = NULL,
                            DeliveryUser = NULL,
                            CaptainCompensationType = NULL,
                            CaptainRate = NULL,
                            CaptainEarning = 0,
                            RowVersion = RowVersion + 1
                        WHERE Id = {id} AND DeliveryId = {uid.Value}");
                }
                else
                {
                    order.DeliveryId = null;
                    order.DeliveryUser = null;
                    order.CaptainCompensationType = null;
                    order.CaptainRate = null;
                    order.CaptainEarning = 0;
                    _service.Update(order);
                    await _ouow.SaveChangesAsync();
                }
                return StatusCode(StatusCodes.Status503ServiceUnavailable,
                    ApiErr.Create("تعذر إنشاء مسار التوصيل. لم يتم حجز الطلب لك، يرجى المحاولة مجدداً."));
            }

            if (isInCourierMatching)
            {
                var acceptedAt = DateTime.UtcNow;
                await _ouow.Context.OrderDispatchOffers
                    .Where(x => x.OrderId == id && x.MatchingRound == order.CourierMatchingRound &&
                                x.DriverId == uid.Value &&
                                (x.Status == OrderDispatchOfferStatus.Offered ||
                                 x.Status == OrderDispatchOfferStatus.TimedOut))
                    .ExecuteUpdateAsync(update => update
                        .SetProperty(x => x.Status, OrderDispatchOfferStatus.Accepted)
                        .SetProperty(x => x.RespondedAtUtc, (DateTime?)acceptedAt));
                await _ouow.Context.OrderDispatchOffers
                    .Where(x => x.OrderId == id && x.MatchingRound == order.CourierMatchingRound &&
                                x.DriverId != uid.Value && x.Status == OrderDispatchOfferStatus.Offered)
                    .ExecuteUpdateAsync(update => update
                        .SetProperty(x => x.Status, OrderDispatchOfferStatus.Superseded)
                        .SetProperty(x => x.RespondedAtUtc, (DateTime?)acceptedAt));
                order.CourierMatchingCompletedAtUtc = acceptedAt;
                await _ouow.SaveChangesAsync();
                var merchantOwnerIds = new List<Guid>();
                foreach (var merchantId in orderMerchantIds.Distinct())
                {
                    var ownerId = await _merchantService.GetOwnerId(merchantId);
                    if (ownerId != Guid.Empty) merchantOwnerIds.Add(ownerId);
                }
                if (merchantOwnerIds.Count > 0)
                    await _notificationService.SendMerchantCourierAssigned(merchantOwnerIds.Distinct().ToArray(), id, courierName);
                if (_trackingHub != null)
                    await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnCourierAssigned", new { orderId = id, courierId = uid.Value });
            }
            else
            {
                await _ouow.SaveChangesAsync();
            }

            // Decoupled notifications & SignalR broadcast
            try
            {
                await _notificationService.SendDeliveryNewOrderRecived(new[] { uid.Value }, id, order.OrderDetails?.ToArray() ?? Array.Empty<OrderDetail>());
                await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnDriverAssigned", new { orderId = id, driverId = uid.Value, driverName = order.DeliveryUser });
                await _trackingHub.Clients.Group(TrackingHub.FleetDispatchGroup).SendAsync("OnOrderClaimed", new { orderId = id, driverId = uid.Value, driverName = order.DeliveryUser });
            }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Failed to broadcast driver claim events for order {OrderId}", id);
            }

            return true;
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
                PaymentMethod = order.PaymentMethod,
                OrderStatus = order.OrderStatus,
                PurchaseDate = order.PurchaseDate,
                CreatedDate = order.CreatedDate,
                User = order.User,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                DeliveryFee = order.DeliveryFee,
                MoneySnapshotVersion = order.MoneySnapshotVersion,
                MoneySnapshotJson = order.MoneySnapshotJson,
                CaptainEarning = order.CaptainEarning,
                DistanceInKm = order.DistanceInKm,
                CustomerRatePerKm = order.CustomerRatePerKm,
                OriginalDeliveryFee = order.OriginalDeliveryFee,
                CaptainCompensationType = order.CaptainCompensationType,
                CaptainRate = order.CaptainRate,
                OrderDetails = order.OrderDetails != null
                    ? order.OrderDetails.Select(d => d.ToDto()).ToArray()
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
            var commissionRate = !string.IsNullOrWhiteSpace(order.MoneySnapshotJson)
                ? merchantShippingStartedOrderDetails.FirstOrDefault()?.CommissionRatePercent ?? 0m
                : merchant?.ProfitOutOfMerchantPricePercent ?? 0m;

            var billCalc = _moneyCalculationService != null
                ? _moneyCalculationService.CalculateMerchantBill(merchantShippingStartedOrderDetails, commissionRate,
                    order.PaymentMethod, commissionIsMarkup: order.MoneySnapshotVersion == 2,
                    commissionIsPercentageOfGross: order.MoneySnapshotVersion >= 3)
                : new MerchantSplitCalculation
                {
                    GrossAmount = merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity),
                    PlatformCommission = order.MoneySnapshotVersion >= 3
                        ? Math.Min(merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity),
                            Math.Round(merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) * Math.Max(0m, commissionRate) / 100m, 2, MidpointRounding.AwayFromZero))
                        : order.MoneySnapshotVersion == 2
                        ? (merchantShippingStartedOrderDetails.All(d => d.IsPlatformOwnedSnapshot)
                            ? merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity)
                            : merchantShippingStartedOrderDetails.Sum(d => (d.SingleFinalPrice - d.SingleMerchantProfit) * d.Quantity))
                        : (commissionRate > 0 ? Math.Round(merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) * (commissionRate / 100m), 2) : 0m),
                    MerchantPayable = order.MoneySnapshotVersion >= 3
                        ? merchantShippingStartedOrderDetails.All(d => d.IsPlatformOwnedSnapshot) ? 0m
                            : merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) - Math.Min(
                                merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity),
                                Math.Round(merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) * Math.Max(0m, commissionRate) / 100m, 2, MidpointRounding.AwayFromZero))
                        : order.MoneySnapshotVersion == 2
                        ? (merchantShippingStartedOrderDetails.All(d => d.IsPlatformOwnedSnapshot) ? 0m : merchantShippingStartedOrderDetails.Sum(d => d.SingleMerchantProfit * d.Quantity))
                        : merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) - (commissionRate > 0 ? Math.Round(merchantShippingStartedOrderDetails.Sum(d => d.SingleFinalPrice * d.Quantity) * (commissionRate / 100m), 2) : 0m)
                };
            var totalAmount = billCalc.GrossAmount;
            var jtakAmount = billCalc.PlatformCommission;
            var merchantAmount = billCalc.MerchantPayable;

            // Create or update bill idempotently with concurrency unique constraint handling
            var existingBill = await _billService.Queryable().FirstOrDefaultAsync(x => x.OrderId == id && x.MerchantId == mid);
            if (existingBill == null)
            {
                var bill = new Bill
                {
                    MerchantId = mid,
                    OrderId = id,
                    TotalAmount = totalAmount,
                    MerchantAmount = merchantAmount,
                    JTakAmount = jtakAmount,
                    JTakAdditionalAmount = 0m,
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
                        existingBill.TotalAmount = totalAmount;
                        existingBill.MerchantAmount = merchantAmount;
                        existingBill.JTakAmount = jtakAmount;
                        existingBill.JTakAdditionalAmount = 0m;
                        existingBill.PaymentMethod = (int)order.PaymentMethod;
                        _billService.Update(existingBill);
                        await _auow.SaveChangesAsync();
                    }
                }
            }
            else
            {
                existingBill.TotalAmount = totalAmount;
                existingBill.MerchantAmount = merchantAmount;
                existingBill.JTakAmount = jtakAmount;
                existingBill.JTakAdditionalAmount = 0m;
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

            if (!LiveTrackingPolicy.AcceptGpsUpdate(location, DateTime.UtcNow))
                return BadRequest(ApiErr.Create("تعذر تحديث الموقع: يرجى تفعيل الموقع الدقيق وانتظار إشارة GPS حديثة."));
            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng), location.Heading, location.Speed, location.CapturedAtUtc);
            var acceptedFix = await _deliveryService.GetDeliveryStatus(uid.Value);
            var courierPayload = new
            {
                driverId = uid.Value,
                lat = acceptedFix.Loc.Lat,
                lng = acceptedFix.Loc.Lng,
                heading = acceptedFix.Heading,
                speed = acceptedFix.Speed,
                updatedAt = acceptedFix.LastLocationUpdatedAt
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

            if (!LiveTrackingPolicy.AcceptGpsUpdate(location, DateTime.UtcNow))
                return BadRequest(ApiErr.Create("تعذر تحديث الموقع: يرجى تفعيل الموقع الدقيق وانتظار إشارة GPS حديثة."));
            await _deliveryService.UpdateDeliveryLocation(uid.Value, (location.Lat, location.Lng), location.Heading, location.Speed, location.CapturedAtUtc);
            var updatedOrder = await _service.UpdateDeliveryLocation(id, uid.Value, location.Lat, location.Lng, location.CapturedAtUtc);

            // Broadcast real-time location via SignalR (resilient)
            try
            {
                var livePayload = new
                {
                    orderId = id,
                    driverId = uid.Value,
                    lat = updatedOrder.DeliveryLat,
                    lng = updatedOrder.DeliveryLng,
                    heading = location.Heading,
                    speed = location.Speed,
                    updatedAt = updatedOrder.DeliveryLocationUpdatedAt
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
        [Route("{id}/ProofPhoto")]
        public async Task<ActionResult<object>> UploadProofPhoto(int id, IFormFile file)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            if (currentOrder.DeliveryId != uid.Value)
                return Forbid();

            if (file == null || file.Length == 0)
                return BadRequest(ApiErr.Create("يرجى اختيار ملف صورة صالح لإثبات التسليم."));

            var ext = System.IO.Path.GetExtension(file.FileName)?.ToLowerInvariant();
            var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            if (string.IsNullOrEmpty(ext) || !allowedExts.Contains(ext))
                return BadRequest(ApiErr.Create("صيغة الملف غير مدعومة. الصيغ المسموح بها: jpg, jpeg, png, webp."));

            if (file.Length > 10 * 1024 * 1024)
                return BadRequest(ApiErr.Create("حجم الصورة يتجاوز الحد الأقصى المسموح به (10 ميجابايت)."));

            string token = null;
            if (_env != null)
            {
                token = await _env.SaveFile(file, FileHelper.FileTypesAllowed.Image);
            }
            else
            {
                token = $"proof_{id}_{Guid.NewGuid():N}{ext}";
            }

            if (string.IsNullOrEmpty(token))
                return BadRequest(ApiErr.Create("فشل في حفظ ملف صورة إثبات التسليم."));

            var photoUrl = $"/api/v1/Services/Download/{token}";
            currentOrder.ProofOfDeliveryPhotoUrl = photoUrl;
            currentOrder.ProofPhotoUploadedBy = uid.Value;
            currentOrder.ProofPhotoUploadedAt = DateTime.UtcNow;

            _service.Update(currentOrder);
            await _ouow.SaveChangesAsync();

            return Ok(new { photoUrl, token });
        }

        [HttpPost]
        [Route("DeliverOrder/{id}")]
        public async Task<ActionResult<bool>> DeliverOrder(int id, [FromBody] DeliverOrderRequest request = null, [FromQuery] string otp = null)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var driver = await _userManager.FindByIdAsync(uid.Value.ToString());
            var dUser = driver?.FullName;

            var currentOrder = await _service.FindAsync(id);
            if (currentOrder == null)
                return NotFound();

            if (currentOrder.DeliveryId != uid.Value)
                return Forbid();

            var activeDetails = currentOrder.OrderDetails.Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                                     x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                                     x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                                                         .ToArray();

            var isAlreadyDelivered = activeDetails.Length > 0 && activeDetails.All(x => x.OrderDetailStatus == OrderDetailStatus.Delivered);

            // Phase 5 Idempotency Guard: if already delivered and ledger transaction has been posted, return immediately.
            if (isAlreadyDelivered && currentOrder.AccountingStatus == OrderAccountingStatus.Posted)
            {
                return Ok(true);
            }

            // Stop Validation: Validate that all merchant stops have been collected (in transit) before delivery
            if (!isAlreadyDelivered)
            {
                if (activeDetails.Length == 0 || activeDetails.Any(x => x.OrderDetailStatus != OrderDetailStatus.ShippingStarted))
                {
                    return BadRequest(ApiErr.Create("لا يمكن تأكيد تسليم هذا الطلب. يجب استلام جميع المحطات من المتاجر وبدء التوصيل أولاً قبل تسليم العميل."));
                }

                if (!await _service.CanDeliverOrder(id, uid.Value))
                {
                    return BadRequest(ApiErr.Create("لا يمكن تأكيد تسليم هذا الطلب. يرجى التأكد من استلام الطلب وتعيينه لك."));
                }
            }

            // The customer PIN remains valid for the active order. Legacy two-hour
            // expiry timestamps must not reject the code still shown to the customer.
            // Photos cannot bypass PIN verification or the attempt limit.
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

            var cleanSubmitted = NormalizeOtp(request?.Otp ?? otp);
            var cleanDb = NormalizeOtp(currentOrder.DeliveryOtp);
            if (cleanDb.Length != 4)
            {
                return BadRequest(ApiErr.Create("رمز تأكيد التسليم غير متوفر لهذا الطلب. يرجى التواصل مع الإدارة.", "DELIVERY_PIN_UNAVAILABLE"));
            }

            if (currentOrder.DeliveryOtpFailedAttempts >= 5)
            {
                return BadRequest(ApiErr.Create("تم استنفاد محاولات رمز التحقق (5 محاولات). يرجى التواصل مع الإدارة لإتمام التسليم.", "DELIVERY_PIN_LOCKED"));
            }

            if (cleanSubmitted.Length != 4)
            {
                return BadRequest(ApiErr.Create("يرجى إدخال رمز تأكيد التسليم المكون من 4 أرقام.", "DELIVERY_PIN_REQUIRED"));
            }

            if (cleanSubmitted != cleanDb)
            {
                currentOrder.DeliveryOtpFailedAttempts++;
                _service.Update(currentOrder);
                await _ouow.SaveChangesAsync();

                if (currentOrder.DeliveryOtpFailedAttempts >= 5)
                {
                    return BadRequest(ApiErr.Create("رمز تأكيد التسليم غير صحيح. تم استنفاد المحاولات (5 محاولات). يرجى التواصل مع الإدارة لإتمام التسليم.", "DELIVERY_PIN_LOCKED"));
                }

                return BadRequest(ApiErr.Create($"رمز تأكيد التسليم غير صحيح (المحاولة {currentOrder.DeliveryOtpFailedAttempts}/5). يرجى إدخال الرمز الصحيح.", "DELIVERY_PIN_INCORRECT"));
            }

            currentOrder.DeliveryOtpFailedAttempts = 0;

            // Cash-to-Collect Validation & Custody Verification
            var isCod = currentOrder.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
            var priorMoney = OrderMoneySnapshot.Deserialize(currentOrder.MoneySnapshotJson);
            var money = CalculateCanonicalMoney(activeDetails.Select(d => d.ToDto()), currentOrder.DeliveryFee,
                currentOrder.PaymentMethod, currentOrder.CaptainEarning, currentOrder.MoneySnapshotVersion == 2,
                currentOrder.MoneySnapshotVersion >= 3, priorMoney?.PromotionDiscount ?? 0m);

            decimal canonicalCashToCollect = isCod
                ? (money?.CashToCollect ?? (activeDetails.Sum(x => x.Quantity * x.SingleFinalPrice) + currentOrder.DeliveryFee))
                : 0m;

            decimal actualCashCollected;
            if (isCod)
            {
                if (request?.CollectedCashAmount.HasValue == true)
                {
                    var submittedCash = request.CollectedCashAmount.Value;
                    if (submittedCash != canonicalCashToCollect && !request.ConfirmDifferentCashAmount)
                    {
                        return BadRequest(ApiErr.Create(
                            $"المبلغ المستلم ({submittedCash:N0} ل.س) يختلف عن المبلغ المطلوب تحصيله ({canonicalCashToCollect:N0} ل.س). يرجى تأكيد المبلغ المختلف للمتابعة.",
                            "CONFIRM_CASH_DIFFERENCE"));
                    }
                    actualCashCollected = submittedCash;
                }
                else
                {
                    actualCashCollected = canonicalCashToCollect;
                }
            }
            else
            {
                actualCashCollected = 0m;
            }

            currentOrder.ActualCashCollected = actualCashCollected;

            // Commit order status delivery transition
            var finalPhotoUrl = currentOrder.ProofOfDeliveryPhotoUrl ?? request?.PhotoUrl;
            var order = isAlreadyDelivered
                ? currentOrder
                : await _service.DeliverOrder(id, uid.Value, finalPhotoUrl, request?.Signature, request?.Notes);

            // Double-Entry Ledger Posting with Fallback to PendingAccounting
            try
            {
                var bills = await _billService.Queryable().Where(x => x.OrderId == id).ToArrayAsync();
                foreach (var b in bills)
                {
                    b.IsAddedToDues = true;
                    _billService.Update(b);
                }
                await _auow.SaveChangesAsync();

                if (bills.Length > 0 && order.AccountingStatus != OrderAccountingStatus.Posted)
                {
                    var merchantSplits = new List<MerchantSplitItem>();
                    foreach (var detailGroup in activeDetails.GroupBy(x => x.MerchantId))
                    {
                        var merchantId = detailGroup.Key;
                        var merchantBills = bills.Where(x => x.MerchantId == merchantId).ToArray();
                        var productGross = detailGroup.Sum(x => x.Quantity * x.SingleFinalPrice);
                        var snapshottedCommission = detailGroup.Sum(x =>
                            x.Quantity * x.SingleFinalPrice * Math.Max(0m, x.CommissionRatePercent) / 100m);
                        var legacyMerchantNet = merchantBills.Sum(x => x.MerchantAmount);
                        var isPlatformOwned = detailGroup.All(x => x.IsPlatformOwnedSnapshot);
                        var canonicalSplit = currentOrder.MoneySnapshotVersion >= 3
                            ? money?.MerchantSplits?.FirstOrDefault(x => x.MerchantId == merchantId)
                            : null;
                        var commission = canonicalSplit != null
                            ? canonicalSplit.MerchantCommission
                            : currentOrder.MoneySnapshotVersion == 2
                            ? (isPlatformOwned ? productGross : Math.Max(0m, productGross - Math.Min(productGross, detailGroup.Sum(x => x.Quantity * x.SingleMerchantProfit))))
                            : detailGroup.Any(x => x.CommissionRatePercent > 0m)
                                ? Math.Min(productGross, snapshottedCommission)
                                : Math.Max(0m, productGross - Math.Min(productGross, legacyMerchantNet));
                        var merchantNet = canonicalSplit?.MerchantPayable ?? Math.Max(0m, productGross - commission);
                        var m = await _merchantService.FindAsync(merchantId);
                        merchantSplits.Add(new MerchantSplitItem
                        {
                            MerchantId = merchantId,
                            MerchantTitle = m?.Title ?? $"Merchant #{merchantId}",
                            TotalAmount = productGross,
                            MerchantAmount = merchantNet,
                            PlatformCommission = commission,
                            IsPlatformOwned = isPlatformOwned || m?.MerchantKind == MerchantKind.DarkStore,
                            CaptainEarningAmount = 0m
                        });
                    }

                    var captainEarning = currentOrder.CaptainCompensationType == CaptainCompensationType.SalariedEmployee
                        ? 0m
                        : (currentOrder.MoneySnapshotVersion > 0
                            ? currentOrder.CaptainEarning
                            : currentOrder.DeliveryFee);

                    var splitReq = new OrderDeliveredSplitRequest
                    {
                        OrderId = id,
                        CaptainUserId = uid.Value,
                        CaptainName = dUser,
                        DeliveryFee = currentOrder.DeliveryFee,
                        DeliveryFeeIsPlatformRevenue = true,
                        TotalsIncludeDeliveryFee = false,
                        Currency = "SYP",
                        IsCod = isCod,
                        MerchantSplits = merchantSplits,
                        CaptainEarning = captainEarning,
                        ActualCashCollected = actualCashCollected
                    };

                    try
                    {
                        await _ledgerService.PostOrderDeliveredSplitAsync(splitReq);

                        order.AccountingStatus = OrderAccountingStatus.Posted;
                        order.AccountingPostedAt = DateTime.UtcNow;
                        order.AccountingLastError = null;
                        _service.Update(order);
                        await _ouow.SaveChangesAsync();

                        // Maintain legacy balance for backwards compatibility with legacy mobile views
                        if (isCod && actualCashCollected > 0 && !isAlreadyDelivered)
                        {
                            try
                            {
                                await _balanceService.IncreaseAppBalance(uid.Value, actualCashCollected, dUser);
                            }
                            catch (Exception balEx)
                            {
                                _logger?.LogWarning(balEx, "Legacy balance update failed for order {OrderId}", id);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        order.AccountingStatus = OrderAccountingStatus.PendingAccounting;
                        order.AccountingRetryCount++;
                        order.AccountingLastError = ex.Message;
                        _service.Update(order);
                        try
                        {
                            await _ouow.SaveChangesAsync();
                        }
                        catch (Exception saveEx)
                        {
                            _logger?.LogError(saveEx, "Failed to persist PendingAccounting state for order {OrderId}", id);
                        }

                        _logger?.LogError(ex, "OPERATIONAL ALERT: Order {OrderId} delivery committed, but double-entry ledger posting failed. Status set to PendingAccounting (Retry #{RetryCount}).", id, order.AccountingRetryCount);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Financial processing error for delivered order {OrderId}", id);
            }

            // Remove order from delivery task list
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

            return Ok(true);
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

        [HttpPost]
        [Route("DeclineOffer/{id}")]
        public async Task<ActionResult<bool>> DeclineOffer(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var now = DateTime.UtcNow;
            var hasPreparedItems = await _ouow.Context.Orders
                .Where(x => x.Id == id)
                .AnyAsync(x => x.OrderDetails.Any(detail =>
                    detail.OrderDetailStatus == OrderDetailStatus.ReadyForPickup ||
                    detail.OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                    detail.OrderDetailStatus == OrderDetailStatus.Delivered));
            if (hasPreparedItems)
                return Conflict(ApiErr.Create("الطلب جاهز للاستلام من المتجر ولا يمكن رفض عرضه."));

            var currentRound = await _ouow.Context.Orders
                .Where(x => x.Id == id && !x.CourierMatchingCompletedAtUtc.HasValue &&
                            x.CourierMatchingDeadlineAtUtc > now &&
                            (x.DeliveryId == null || x.DeliveryId == Guid.Empty))
                .Select(x => (int?)x.CourierMatchingRound)
                .FirstOrDefaultAsync();
            if (!currentRound.HasValue) return Ok(true);

            var offer = await _ouow.Context.OrderDispatchOffers.FirstOrDefaultAsync(x =>
                x.OrderId == id && x.DriverId == uid.Value &&
                x.MatchingRound == currentRound.Value &&
                (x.Status == OrderDispatchOfferStatus.Offered ||
                 x.Status == OrderDispatchOfferStatus.TimedOut));
            if (offer == null) return Ok(true); // Idempotent for an expired/stale offer.

            offer.Status = OrderDispatchOfferStatus.Declined;
            offer.RespondedAtUtc = now;
            await _ouow.SaveChangesAsync();
            return Ok(true);
        }

        [HttpPost]
        [Route("Decline/{id}")]
        public async Task<ActionResult<bool>> DeliveryDecline(int id)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();

            var existingOrder = await _service.FindAsync(id);
            if (existingOrder == null)
                return NotFound();

            if (existingOrder.DeliveryId != uid.Value)
                return Forbid();

            if (existingOrder.OrderDetails.Any(x =>
                    x.OrderDetailStatus == OrderDetailStatus.ReadyForPickup ||
                    x.OrderDetailStatus == OrderDetailStatus.ShippingStarted ||
                    x.OrderDetailStatus == OrderDetailStatus.Delivered))
                return Conflict(ApiErr.Create("الطلب جاهز للاستلام أو بدأ توصيله، ولا يمكن رفضه. تواصل مع الدعم عند وجود مشكلة."));

            return Conflict(ApiErr.Create("لا يمكن رفض طلب بعد استلامه. تواصل مع الدعم لإعادة التعيين عند الضرورة."));
        }

        private CanonicalOrderMoneyDto CalculateCanonicalMoney(
            IEnumerable<OrderDetailDto> details,
            decimal deliveryFee,
            Modules.Orders.Entities.PaymentMethod paymentMethod,
            decimal captainEarning,
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false,
            decimal promotionDiscount = 0m)
        {
            if (_moneyCalculationService == null) return null;
            var items = (details ?? Enumerable.Empty<OrderDetailDto>()).ToArray();
            var contracts = items.GroupBy(x => x.MerchantId).Select(g => new MerchantCommissionInfo
            {
                MerchantId = g.Key,
                MerchantTitle = g.First().MerchantTitle,
                CommissionRatePercent = g.First().CommissionRatePercent,
                IsDarkStore = g.First().IsPlatformOwnedSnapshot
            }).ToArray();
            return _moneyCalculationService.CalculateOrderMoney(
                items, deliveryFee, paymentMethod,
                merchantCommissionInfos: contracts,
                promotionDiscount: promotionDiscount,
                captainEarning: captainEarning,
                currency: "SYP",
                commissionIsMarkup: commissionIsMarkup,
                commissionIsPercentageOfGross: commissionIsPercentageOfGross);
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
