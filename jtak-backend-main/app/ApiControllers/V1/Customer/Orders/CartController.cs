using App.ApiModels;
using App.Extensions;
using App.Shared.Services;
using App.Shared.Services.eCommerce;
using App.Shared.Services.Extentions;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using Modules.Orders.Entities;
using Modules.Catalog.Services;
using App.Shared.Services.Pricing;
using App.Orders.Data;
using System;
using System.Security.Cryptography;
using Modules.Orders.Services;
using Modules.Catalog.Entities;
using App.Shared.Entities.Enums;

namespace App.ApiControllers.V1.Customer.Orders
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class CartController : SolApiController
    {
        private readonly IOrdersUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IProductService _service;
        private readonly IOrderService _orderService;
        private readonly IOrderDetailService _orderDetailService;
        private readonly IMerchantService _merchantService;
        private readonly IInventoryBatchService _batchService;
        private readonly IOrderMoneyCalculationService _moneyCalculationService;
        private readonly IDriverPricingService _driverPricingService;
        private readonly TimeProvider _timeProvider;

        public CartController(IOrdersUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IProductService service,
            IOrderService orderService,
            IOrderDetailService orderDetailService,
            IMerchantService merchantService,
            IInventoryBatchService batchService,
            ILogger<CartController> logger,
            IMapper mapper,
            IOrderMoneyCalculationService moneyCalculationService = null,
            TimeProvider timeProvider = null,
            IDriverPricingService driverPricingService = null)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _service = service;
            _orderService = orderService;
            _orderDetailService = orderDetailService;
            _merchantService = merchantService;
            _batchService = batchService;
            _moneyCalculationService = moneyCalculationService;
            _timeProvider = timeProvider ?? TimeProvider.System;
            _driverPricingService = driverPricingService;
        }

        /// <summary>
        /// Post Current Cart with Details
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Calc/{lat}/{lng}")]
        public async Task<ActionResult<OrderDto>> GetCalc(decimal lat, decimal lng, CartItem[] items)
        {
            var merchantValidation = await ValidateCartMerchants(items);
            if (!merchantValidation.IsValid)
                return BadRequest(ApiErr.Create(merchantValidation.ErrorMessage));

            var uid = User.GetUserId();
            var orderDetails = await GetOrderDetails(items);
            var driverPricing = _driverPricingService == null
                ? null
                : await _driverPricingService.GetSettingAsync();
            var deliveryQuote = CalculateCustomerDeliveryFeeForDetails(
                driverPricing, orderDetails, lat, lng, merchantValidation.Merchants);
            var deliveryFee = deliveryQuote.CustomerDeliveryFee;
            var captainEarning = CalculateCaptainEarningForDetails(
                driverPricing, orderDetails, lat, lng, merchantValidation.Merchants);
            var dtos = orderDetails.Select(x => x.ToDto()).ToArray();
            var money = CalculateCanonicalMoney(dtos, deliveryFee, Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                captainEarning: captainEarning,
                commissionIsPercentageOfGross: true);
            if (money != null)
            {
                money.OriginalDeliveryFee = deliveryQuote.OriginalDeliveryFee;
                money.DistanceInKm = deliveryQuote.DistanceInKm;
                money.CustomerRatePerKm = deliveryQuote.CustomerRatePerKm;
                money.IsFreeDeliveryPromo = deliveryQuote.IsFreeDelivery;
            }
            var order = new OrderDto
            {
                OrderDetails = dtos,
                DeliveryFee = deliveryFee,
                Money = money
            };
            return order;
        }

        /// <summary>
        /// Submit Current Cart Order
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("SubmitOrder")]
        public async Task<ActionResult<OrderDto>> SubmitOrder(CartSubmit m)
        {
            // Cash on delivery is the only payment method currently supported.
            if (m == null || m.PaymentMethod != Modules.Orders.Entities.PaymentMethod.PayOnDelivery)
                return BadRequest(ApiErr.Create("الدفع عند الاستلام هو طريقة الدفع المتاحة حالياً."));

            if (string.IsNullOrWhiteSpace(m.IdempotencyKey))
                return BadRequest(ApiErr.Create("تعذر تأكيد معرّف محاولة الطلب. يرجى تحديث التطبيق والمحاولة مرة أخرى."));

            m.IdempotencyKey = m.IdempotencyKey.Trim();
            if (m.Lat < -90m || m.Lat > 90m || m.Lng < -180m || m.Lng > 180m ||
                (m.Lat == 0m && m.Lng == 0m) || string.IsNullOrWhiteSpace(m.Address))
                return BadRequest(ApiErr.Create("يرجى تحديد عنوان توصيل صالح على الخريطة."));

            var user = await _userManager.GetUserAsync(User)
                ?? (User.GetUserId() != null ? await _userManager.FindByIdAsync(User.GetUserId().ToString()) : null);

            if (user == null && !string.IsNullOrWhiteSpace(m.Phonenumber))
            {
                var cleanPhone = m.Phonenumber.Trim().Replace(" ", "");
                user = await _userManager.FindByPhoneNumberAsync(cleanPhone)
                    ?? await _userManager.FindByNameAsync(cleanPhone);
            }

            if (user == null)
                return Unauthorized();

            // 1. Idempotency Check: if key provided and order exists, return existing order immediately
            if (!string.IsNullOrWhiteSpace(m.IdempotencyKey))
            {
                var existingOrders = await _orderService.Queryable()
                    .Include(x => x.OrderDetails)
                    .Where(x => x.UserId == user.Id &&
                               (x.IdempotencyKey == m.IdempotencyKey ||
                                x.IdempotencyKey == m.IdempotencyKey + "_rest" ||
                                x.IdempotencyKey == m.IdempotencyKey + "_mkt"))
                    .OrderBy(x => x.Id)
                    .ToListAsync();

                if (existingOrders.Any())
                {
                    _logger.LogInformation("Idempotent retry detected for user {UserId} with key {Key}. Returning existing order(s) ({Count}).",
                        user.Id, m.IdempotencyKey, existingOrders.Count);

                    var orderDtos = new List<OrderDto>();
                    foreach (var ord in existingOrders)
                    {
                        var ordDetails = ord.OrderDetails?.Select(d => d.ToDto()).ToArray() ?? Array.Empty<OrderDetailDto>();
                        var merchant = ordDetails.Length > 0
                            ? await _merchantService.FindAsync(ordDetails[0].MerchantId)
                            : null;
                        var ordMoney = OrderMoneySnapshot.Deserialize(ord.MoneySnapshotJson)
                            ?? CalculateCanonicalMoney(ordDetails, ord.DeliveryFee, ord.PaymentMethod, ord.CaptainEarning,
                                ord.MoneySnapshotVersion == 2, ord.MoneySnapshotVersion >= 3);

                        orderDtos.Add(new OrderDto
                        {
                            Id = ord.Id,
                            MerchantKind = merchant == null ? null : (int)merchant.MerchantKind,
                            PaymentMethod = ord.PaymentMethod,
                            UserId = ord.UserId,
                            User = ord.User,
                            Phonenumber = ord.Phonenumber,
                            Lat = ord.Lat,
                            Lng = ord.Lng,
                            Address = ord.Address,
                            DeliveryFee = ord.DeliveryFee,
                            MoneySnapshotVersion = ord.MoneySnapshotVersion,
                            OrderStatus = ord.OrderStatus,
                            PurchaseDate = ord.PurchaseDate,
                            DeliveryOtp = ord.DeliveryOtp,
                            IdempotencyKey = ord.IdempotencyKey,
                            OrderDetails = ordDetails,
                            Money = ordMoney
                        });
                    }

                    var primaryDto = orderDtos.First();
                    if (orderDtos.Count > 1)
                    {
                        primaryDto.SiblingOrders = orderDtos.Select(o => new OrderDto
                        {
                            Id = o.Id,
                            MerchantKind = o.MerchantKind,
                            PaymentMethod = o.PaymentMethod,
                            UserId = o.UserId,
                            User = o.User,
                            Phonenumber = o.Phonenumber,
                            Lat = o.Lat,
                            Lng = o.Lng,
                            Address = o.Address,
                            DeliveryFee = o.DeliveryFee,
                            MoneySnapshotVersion = o.MoneySnapshotVersion,
                            OrderStatus = o.OrderStatus,
                            PurchaseDate = o.PurchaseDate,
                            DeliveryOtp = o.DeliveryOtp,
                            IdempotencyKey = o.IdempotencyKey,
                            OrderDetails = o.OrderDetails,
                            Money = o.Money,
                            SiblingOrders = null
                        }).ToList();
                    }
                    return Ok(primaryDto);
                }
            }

            // Existing orders must be replayable even after operating hours; only a new checkout is gated.
            if (!HomsDeliveryArea.Contains(m.Lat, m.Lng))
                return BadRequest(ApiErr.Create("عنوان التوصيل خارج منطقة التغطية في حمص. يرجى اختيار موقع على الخريطة ضمن منطقة التوصيل لإتمام الطلب."));

            // Normalize PhoneNumber
            m.Phonenumber = m.Phonenumber?.Trim().Replace(" ", "");

            if (m.CartItems == null || m.CartItems.Length == 0)
            {
                return BadRequest(ApiErr.Create("سلة المشتريات فارغة."));
            }

            var merchantValidation = await ValidateCartMerchants(m.CartItems);
            if (!merchantValidation.IsValid)
                return BadRequest(ApiErr.Create(merchantValidation.ErrorMessage));

            var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
            var closedMerchant = merchantValidation.Merchants.FirstOrDefault(merchant =>
                !OrderDto.IsOperatingDeliveryHours(nowUtc, merchant.WorkingHours));
            if (closedMerchant != null)
                return BadRequest(ApiErr.Create(
                    $"المتجر '{closedMerchant.Title}' يستقبل الطلبات يومياً {closedMerchant.WorkingHours ?? "من 9:00 صباحاً حتى 11:00 ليلاً"}."));

            var orderDetails = await GetOrderDetails(m.CartItems);
            if (orderDetails.Count == 0)
            {
                return BadRequest(ApiErr.Create("لم يتم العثور على أية منتجات صالحة في السلة."));
            }

            // 2. Reject if any product has a warning (e.g. merchant inactive or product unavailable)
            var firstItemWarning = orderDetails.FirstOrDefault(x => !string.IsNullOrEmpty(x.Warning));
            if (firstItemWarning != null)
            {
                return BadRequest(ApiErr.Create(firstItemWarning.Warning.Trim()));
            }

            // 4. Server-Side Minimum Order Validation per Merchant
            foreach (var merchantGroup in orderDetails.GroupBy(x => x.MerchantId))
            {
                var merchant = await _merchantService.FindAsync(merchantGroup.Key);
                if (merchant != null && merchant.MinOrderAmount > 0)
                {
                    var merchantSubtotal = merchantGroup.Sum(x => x.TotalFinalPrice);
                    if (merchantSubtotal < merchant.MinOrderAmount)
                    {
                        return BadRequest(ApiErr.Create(
                            $"قيمة الطلب من متجر '{merchant.Title}' ({merchantSubtotal:N0} ل.س) أقل من الحد الأدنى للطلب ({merchant.MinOrderAmount:N0} ل.س)."));
                    }
                }
            }

            // 5. Anti-Spam / Rate-limiting guard
            var lastPurchase = await _orderService.Queryable()
                                           .Where(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Success)
                                           .OrderByDescending(x => x.PurchaseDate)
                                           .Select(x => x.PurchaseDate)
                                           .FirstOrDefaultAsync();
            if (lastPurchase != null && DateTime.UtcNow.AddSeconds(-3) < lastPurchase)
            {
                return BadRequest(ApiErr.Create("يرجى الانتظار بضع ثوانٍ قبل إرسال طلب جديد."));
            }

            // Calculate canonical money snapshot and delivery fee
            var driverPricing = _driverPricingService == null
                ? null
                : await _driverPricingService.GetSettingAsync();
            var deliveryQuote = CalculateCustomerDeliveryFeeForDetails(
                driverPricing, orderDetails, m.Lat, m.Lng, merchantValidation.Merchants);
            var deliveryFee = deliveryQuote.CustomerDeliveryFee;
            var captainEarning = CalculateCaptainEarningForDetails(
                driverPricing, orderDetails, m.Lat, m.Lng, merchantValidation.Merchants);
            var detailDtos = orderDetails.Select(x => x.ToDto()).ToArray();
            var money = CalculateCanonicalMoney(detailDtos, deliveryFee, m.PaymentMethod,
                captainEarning: captainEarning,
                commissionIsPercentageOfGross: true);
            if (money != null)
            {
                money.OriginalDeliveryFee = deliveryQuote.OriginalDeliveryFee;
                money.DistanceInKm = deliveryQuote.DistanceInKm;
                money.CustomerRatePerKm = deliveryQuote.CustomerRatePerKm;
                money.IsFreeDeliveryPromo = deliveryQuote.IsFreeDelivery;
            }

            // 6. Order Creation: Dual-Merchant Checkout (1 Restaurant + 1 Market)
            if (merchantValidation.Merchants.Count == 2)
            {
                var restMerchant = merchantValidation.Merchants.First(x => x.MerchantKind == MerchantKind.Restaurant);
                var marketMerchant = merchantValidation.Merchants.First(x => x.MerchantKind != MerchantKind.Restaurant);

                var restDetails = orderDetails.Where(x => x.MerchantId == restMerchant.Id).ToList();
                var marketDetails = orderDetails.Where(x => x.MerchantId == marketMerchant.Id).ToList();

                var restDeliveryQuote = CalculateCustomerDeliveryFeeForDetails(
                    driverPricing, restDetails, m.Lat, m.Lng, new[] { restMerchant });
                var restDeliveryFee = restDeliveryQuote.CustomerDeliveryFee;
                var restCaptainEarning = CalculateCaptainEarningForDetails(
                    driverPricing, restDetails, m.Lat, m.Lng, new[] { restMerchant });
                var restDetailDtos = restDetails.Select(x => x.ToDto()).ToArray();
                var restMoney = CalculateCanonicalMoney(restDetailDtos, restDeliveryFee, m.PaymentMethod,
                    captainEarning: restCaptainEarning,
                    commissionIsPercentageOfGross: true);
                if (restMoney != null)
                {
                    restMoney.OriginalDeliveryFee = restDeliveryQuote.OriginalDeliveryFee;
                    restMoney.DistanceInKm = restDeliveryQuote.DistanceInKm;
                    restMoney.CustomerRatePerKm = restDeliveryQuote.CustomerRatePerKm;
                    restMoney.IsFreeDeliveryPromo = restDeliveryQuote.IsFreeDelivery;
                }

                var marketDeliveryQuote = CalculateCustomerDeliveryFeeForDetails(
                    driverPricing, marketDetails, m.Lat, m.Lng, new[] { marketMerchant });
                var marketDeliveryFee = marketDeliveryQuote.CustomerDeliveryFee;
                var marketCaptainEarning = CalculateCaptainEarningForDetails(
                    driverPricing, marketDetails, m.Lat, m.Lng, new[] { marketMerchant });
                var marketDetailDtos = marketDetails.Select(x => x.ToDto()).ToArray();
                var marketMoney = CalculateCanonicalMoney(marketDetailDtos, marketDeliveryFee, m.PaymentMethod,
                    captainEarning: marketCaptainEarning,
                    commissionIsPercentageOfGross: true);
                if (marketMoney != null)
                {
                    marketMoney.OriginalDeliveryFee = marketDeliveryQuote.OriginalDeliveryFee;
                    marketMoney.DistanceInKm = marketDeliveryQuote.DistanceInKm;
                    marketMoney.CustomerRatePerKm = marketDeliveryQuote.CustomerRatePerKm;
                    marketMoney.IsFreeDeliveryPromo = marketDeliveryQuote.IsFreeDelivery;
                }

                var cartRest = new Order
                {
                    UserId = user.Id,
                    User = user.FullName,
                    Phonenumber = m.Phonenumber,
                    Lat = m.Lat,
                    Lng = m.Lng,
                    Address = m.Address,
                    PaymentMethod = m.PaymentMethod,
                    DeliveryFee = restDeliveryFee,
                    DistanceInKm = restDeliveryQuote.DistanceInKm,
                    CustomerRatePerKm = restDeliveryQuote.CustomerRatePerKm,
                    OriginalDeliveryFee = restDeliveryQuote.OriginalDeliveryFee,
                    CaptainEarning = restMoney?.CaptainEarning ?? restCaptainEarning,
                    MoneySnapshotVersion = restMoney?.Version ?? 3,
                    MoneySnapshotJson = OrderMoneySnapshot.Serialize(restMoney),
                    OrderStatus = OrderStatus.Success,
                    PurchaseDate = DateTime.UtcNow,
                    DeliveryOtp = RandomNumberGenerator.GetInt32(1000, 10000).ToString(),
                    DeliveryOtpExpiresAt = null,
                    IdempotencyKey = $"{m.IdempotencyKey}_rest"
                };

                var cartMarket = new Order
                {
                    UserId = user.Id,
                    User = user.FullName,
                    Phonenumber = m.Phonenumber,
                    Lat = m.Lat,
                    Lng = m.Lng,
                    Address = m.Address,
                    PaymentMethod = m.PaymentMethod,
                    DeliveryFee = marketDeliveryFee,
                    DistanceInKm = marketDeliveryQuote.DistanceInKm,
                    CustomerRatePerKm = marketDeliveryQuote.CustomerRatePerKm,
                    OriginalDeliveryFee = marketDeliveryQuote.OriginalDeliveryFee,
                    CaptainEarning = marketMoney?.CaptainEarning ?? marketCaptainEarning,
                    MoneySnapshotVersion = marketMoney?.Version ?? 3,
                    MoneySnapshotJson = OrderMoneySnapshot.Serialize(marketMoney),
                    OrderStatus = OrderStatus.Success,
                    PurchaseDate = DateTime.UtcNow,
                    DeliveryOtp = RandomNumberGenerator.GetInt32(1000, 10000).ToString(),
                    DeliveryOtpExpiresAt = null,
                    IdempotencyKey = $"{m.IdempotencyKey}_mkt"
                };

                var isInMemoryDual = _uow.Context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory";
                var transactionDual = isInMemoryDual ? null : await _uow.Context.Database.BeginTransactionAsync();
                try
                {
                    var stalePendingCarts = await _orderService.Queryable()
                        .Where(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Pending)
                        .ToListAsync();
                    foreach (var stale in stalePendingCarts)
                    {
                        _orderService.Delete(stale);
                    }

                    // 1. Insert Restaurant Order
                    _orderService.Insert(cartRest);
                    await _uow.SaveChangesAsync();

                    SetOrderId(restDetails, cartRest.Id);
                    _orderDetailService.Insert(restDetails);

                    _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                    {
                        BusinessKey = $"OrderCreated:{cartRest.Id}:Merchant:{restMerchant.Id}",
                        EventType = OrderOutboxMessage.MerchantNewOrder,
                        OrderId = cartRest.Id,
                        Payload = restMerchant.Id.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        OccurredAtUtc = DateTime.UtcNow
                    });
                    _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                    {
                        BusinessKey = $"OrderCreated:{cartRest.Id}:Admin",
                        EventType = OrderOutboxMessage.AdminNewOrder,
                        OrderId = cartRest.Id,
                        OccurredAtUtc = DateTime.UtcNow
                    });

                    // 2. Insert Market Order
                    _orderService.Insert(cartMarket);
                    await _uow.SaveChangesAsync();

                    SetOrderId(marketDetails, cartMarket.Id);
                    _orderDetailService.Insert(marketDetails);

                    _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                    {
                        BusinessKey = $"OrderCreated:{cartMarket.Id}:Merchant:{marketMerchant.Id}",
                        EventType = OrderOutboxMessage.MerchantNewOrder,
                        OrderId = cartMarket.Id,
                        Payload = marketMerchant.Id.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        OccurredAtUtc = DateTime.UtcNow
                    });
                    _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                    {
                        BusinessKey = $"OrderCreated:{cartMarket.Id}:Admin",
                        EventType = OrderOutboxMessage.AdminNewOrder,
                        OrderId = cartMarket.Id,
                        OccurredAtUtc = DateTime.UtcNow
                    });

                    await _uow.SaveChangesAsync();

                    // 3. Stock reservations
                    foreach (var detail in restDetails)
                    {
                        await _batchService.ReserveStockFEFOAsync(cartRest.Id, detail.Id, detail.ProductId, detail.MerchantId, detail.Quantity);
                    }
                    foreach (var detail in marketDetails)
                    {
                        await _batchService.ReserveStockFEFOAsync(cartMarket.Id, detail.Id, detail.ProductId, detail.MerchantId, detail.Quantity);
                    }

                    if (transactionDual != null)
                    {
                        await transactionDual.CommitAsync();
                    }
                }
                catch (Exception ex)
                {
                    if (transactionDual != null)
                    {
                        await transactionDual.RollbackAsync();
                    }
                    else
                    {
                        try
                        {
                            var failedIds = new[] { cartRest.Id, cartMarket.Id };
                            // InMemory has no transaction rollback. Do not leave
                            // sendable creation events for failed checkout drafts.
                            var localMessages = _uow.Context.Set<OrderOutboxMessage>().Local
                                .Where(x => failedIds.Contains(x.OrderId)).ToList();
                            _uow.Context.Set<OrderOutboxMessage>().RemoveRange(localMessages);
                            if (cartRest.Id > 0)
                            {
                                cartRest.OrderStatus = OrderStatus.Pending;
                                var localDetails = _uow.Context.Set<OrderDetail>().Local.Where(x => x.OrderId == cartRest.Id).ToList();
                                if (localDetails.Any()) _uow.Context.Set<OrderDetail>().RemoveRange(localDetails);
                                var localOrder = _uow.Context.Set<Order>().Local.FirstOrDefault(x => x.Id == cartRest.Id) ?? cartRest;
                                _uow.Context.Set<Order>().Remove(localOrder);
                            }
                            if (cartMarket.Id > 0)
                            {
                                cartMarket.OrderStatus = OrderStatus.Pending;
                                var localDetails = _uow.Context.Set<OrderDetail>().Local.Where(x => x.OrderId == cartMarket.Id).ToList();
                                if (localDetails.Any()) _uow.Context.Set<OrderDetail>().RemoveRange(localDetails);
                                var localOrder = _uow.Context.Set<Order>().Local.FirstOrDefault(x => x.Id == cartMarket.Id) ?? cartMarket;
                                _uow.Context.Set<Order>().Remove(localOrder);
                            }
                            await _uow.SaveChangesAsync();
                        }
                        catch (Exception cleanEx)
                        {
                            _logger.LogWarning(cleanEx, "Fallback cleanup failed for dual orders");
                        }
                    }

                    if (cartRest.Id > 0)
                    {
                        try { await _batchService.ReleaseReservationAsync(cartRest.Id, reason: "Checkout transaction failed or rolled back"); } catch { }
                    }
                    if (cartMarket.Id > 0)
                    {
                        try { await _batchService.ReleaseReservationAsync(cartMarket.Id, reason: "Checkout transaction failed or rolled back"); } catch { }
                    }

                    if (ex is InvalidOperationException || ex is ArgumentException)
                    {
                        return BadRequest(ApiErr.Create(ex.Message));
                    }

                    throw;
                }
                finally
                {
                    transactionDual?.Dispose();
                }

                var restSummary = BuildOrderDto(cartRest, restDetails, restMoney, (int)restMerchant.MerchantKind);
                var marketSummary = BuildOrderDto(cartMarket, marketDetails, marketMoney, (int)marketMerchant.MerchantKind);
                restSummary.SiblingOrders = null;
                marketSummary.SiblingOrders = null;

                var restDto = BuildOrderDto(cartRest, restDetails, restMoney, (int)restMerchant.MerchantKind);
                restDto.SiblingOrders = new List<OrderDto> { restSummary, marketSummary };

                return Ok(restDto);
            }

            // 6. Atomic Transaction: Persist Single Order, Insert Details, and Reserve FEFO Stock
            var cart = new Order
            {
                UserId = user.Id,
                User = user.FullName,
                Phonenumber = m.Phonenumber,
                Lat = m.Lat,
                Lng = m.Lng,
                Address = m.Address,
                PaymentMethod = m.PaymentMethod,
                DeliveryFee = deliveryFee,
                DistanceInKm = deliveryQuote.DistanceInKm,
                CustomerRatePerKm = deliveryQuote.CustomerRatePerKm,
                OriginalDeliveryFee = deliveryQuote.OriginalDeliveryFee,
                CaptainEarning = money?.CaptainEarning ?? captainEarning,
                MoneySnapshotVersion = money?.Version ?? 3,
                MoneySnapshotJson = OrderMoneySnapshot.Serialize(money),
                OrderStatus = OrderStatus.Success,
                PurchaseDate = DateTime.UtcNow,
                DeliveryOtp = RandomNumberGenerator.GetInt32(1000, 10000).ToString(),
                DeliveryOtpExpiresAt = null,
                IdempotencyKey = m.IdempotencyKey
            };

            var isInMemory = _uow.Context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory";
            var transaction = isInMemory ? null : await _uow.Context.Database.BeginTransactionAsync();
            try
            {
                // Clean up any stale pending cart for this user
                var stalePendingCarts = await _orderService.Queryable()
                    .Where(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Pending)
                    .ToListAsync();
                foreach (var stale in stalePendingCarts)
                {
                    _orderService.Delete(stale);
                }

                _orderService.Insert(cart);
                await _uow.SaveChangesAsync();

                SetOrderId(orderDetails, cart.Id);
                _orderDetailService.Insert(orderDetails);

                foreach (var merchantId in orderDetails.Select(x => x.MerchantId).Distinct())
                {
                    _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                    {
                        BusinessKey = $"OrderCreated:{cart.Id}:Merchant:{merchantId}",
                        EventType = OrderOutboxMessage.MerchantNewOrder,
                        OrderId = cart.Id,
                        Payload = merchantId.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        OccurredAtUtc = DateTime.UtcNow
                    });
                }

                _uow.Context.Set<OrderOutboxMessage>().Add(new OrderOutboxMessage
                {
                    BusinessKey = $"OrderCreated:{cart.Id}:Admin",
                    EventType = OrderOutboxMessage.AdminNewOrder,
                    OrderId = cart.Id,
                    OccurredAtUtc = DateTime.UtcNow
                });
                await _uow.SaveChangesAsync();

                // Reserve stock via FEFO for any dark store / batch-managed items
                foreach (var detail in orderDetails)
                {
                    await _batchService.ReserveStockFEFOAsync(cart.Id, detail.Id, detail.ProductId, detail.MerchantId, detail.Quantity);
                }

                if (transaction != null)
                {
                    await transaction.CommitAsync();
                }
            }
            catch (Exception ex)
            {
                if (transaction != null)
                {
                    await transaction.RollbackAsync();
                }
                else if (cart.Id > 0)
                {
                    // Fallback for providers without transaction support (e.g. EF Core InMemory in unit tests)
                    try
                    {
                        cart.OrderStatus = OrderStatus.Pending;
                        var localDetails = _uow.Context.Set<OrderDetail>().Local.Where(x => x.OrderId == cart.Id).ToList();
                        if (localDetails.Any())
                        {
                            _uow.Context.Set<OrderDetail>().RemoveRange(localDetails);
                        }

                        var localOrder = _uow.Context.Set<Order>().Local.FirstOrDefault(x => x.Id == cart.Id) ?? cart;
                        _uow.Context.Set<Order>().Remove(localOrder);
                        await _uow.SaveChangesAsync();
                    }
                    catch (Exception cleanEx)
                    {
                        _logger.LogWarning(cleanEx, "Fallback cleanup failed for order {OrderId}", cart.Id);
                    }
                }

                // Compensating release for batch reservations
                if (cart.Id > 0)
                {
                    try
                    {
                        await _batchService.ReleaseReservationAsync(cart.Id, reason: "Checkout transaction failed or rolled back");
                    }
                    catch (Exception releaseEx)
                    {
                        _logger.LogWarning(releaseEx, "Failed to release reservations after rollback for order {OrderId}", cart.Id);
                    }
                }

                // Concurrent idempotency race condition: if duplicate key database error occurred, return the existing order
                if (ex is DbUpdateException && !string.IsNullOrWhiteSpace(m.IdempotencyKey))
                {
                    var existingOrder = await _orderService.Queryable()
                        .Include(x => x.OrderDetails)
                        .FirstOrDefaultAsync(x => x.UserId == user.Id && x.IdempotencyKey == m.IdempotencyKey);

                    if (existingOrder != null)
                    {
                        _logger.LogInformation("Concurrent duplicate order caught by constraint for key {Key}. Returning existing order #{OrderId}.", m.IdempotencyKey, existingOrder.Id);
                        var existingDetails = existingOrder.OrderDetails?.Select(d => d.ToDto()).ToArray() ?? Array.Empty<OrderDetailDto>();
                        var existingMoney = OrderMoneySnapshot.Deserialize(existingOrder.MoneySnapshotJson)
                            ?? CalculateCanonicalMoney(existingDetails, existingOrder.DeliveryFee, existingOrder.PaymentMethod,
                                existingOrder.CaptainEarning, existingOrder.MoneySnapshotVersion == 2,
                                existingOrder.MoneySnapshotVersion >= 3);

                        return Ok(new OrderDto
                        {
                            Id = existingOrder.Id,
                            UserId = existingOrder.UserId,
                            User = existingOrder.User,
                            Phonenumber = existingOrder.Phonenumber,
                            Lat = existingOrder.Lat,
                            Lng = existingOrder.Lng,
                            Address = existingOrder.Address,
                            DeliveryFee = existingOrder.DeliveryFee,
                            MoneySnapshotVersion = existingOrder.MoneySnapshotVersion,
                            OrderStatus = existingOrder.OrderStatus,
                            PurchaseDate = existingOrder.PurchaseDate,
                            DeliveryOtp = existingOrder.DeliveryOtp,
                            IdempotencyKey = existingOrder.IdempotencyKey,
                            OrderDetails = existingDetails,
                            Money = existingMoney
                        });
                    }
                }

                if (ex is InvalidOperationException || ex is ArgumentException)
                {
                    return BadRequest(ApiErr.Create(ex.Message));
                }

                throw;
            }
            finally
            {
                transaction?.Dispose();
            }

            var responseDto = new OrderDto
            {
                Id = cart.Id,
                UserId = cart.UserId,
                User = cart.User,
                Phonenumber = cart.Phonenumber,
                Lat = cart.Lat,
                Lng = cart.Lng,
                Address = cart.Address,
                PaymentMethod = cart.PaymentMethod,
                DeliveryFee = cart.DeliveryFee,
                MoneySnapshotVersion = cart.MoneySnapshotVersion,
                OrderStatus = cart.OrderStatus,
                PurchaseDate = cart.PurchaseDate,
                DeliveryOtp = cart.DeliveryOtp,
                IdempotencyKey = cart.IdempotencyKey,
                DistanceInKm = cart.DistanceInKm,
                CustomerRatePerKm = cart.CustomerRatePerKm,
                OriginalDeliveryFee = cart.OriginalDeliveryFee,
                CaptainCompensationType = cart.CaptainCompensationType,
                CaptainRate = cart.CaptainRate,
                OrderDetails = orderDetails.Select(x => x.ToDto()).ToArray(),
                Money = money
            };

            return Ok(responseDto);
        }

        private static OrderDto BuildOrderDto(Order order, IEnumerable<OrderDetail> details, CanonicalOrderMoneyDto money, int? merchantKind = null)
        {
            var detailDtos = (details ?? Enumerable.Empty<OrderDetail>()).Select(x => x.ToDto()).ToArray();
            return new OrderDto
            {
                Id = order.Id,
                MerchantKind = merchantKind,
                UserId = order.UserId,
                User = order.User,
                Phonenumber = order.Phonenumber,
                Lat = order.Lat,
                Lng = order.Lng,
                Address = order.Address,
                PaymentMethod = order.PaymentMethod,
                DeliveryFee = order.DeliveryFee,
                MoneySnapshotVersion = order.MoneySnapshotVersion,
                CaptainEarning = order.CaptainEarning,
                DistanceInKm = order.DistanceInKm,
                CustomerRatePerKm = order.CustomerRatePerKm,
                OriginalDeliveryFee = order.OriginalDeliveryFee,
                CaptainCompensationType = order.CaptainCompensationType,
                CaptainRate = order.CaptainRate,
                OrderStatus = order.OrderStatus,
                PurchaseDate = order.PurchaseDate,
                DeliveryOtp = order.DeliveryOtp,
                IdempotencyKey = order.IdempotencyKey,
                OrderDetails = detailDtos,
                Money = money
            };
        }

        private async Task<(bool IsValid, string ErrorMessage, List<Modules.Catalog.Entities.Merchant> Merchants)> ValidateCartMerchants(CartItem[] items)
        {
            var mIds = (items ?? Array.Empty<CartItem>())
                .Select(x => x.MerchantId)
                .Where(id => id > 0)
                .Distinct()
                .ToList();

            if (mIds.Count == 0)
                return (false, "سلة المشتريات فارغة.", null);

            if (mIds.Count == 1)
            {
                var single = await _merchantService.FindAsync(mIds[0]);
                if (single == null)
                    return (false, "تعذر العثور على بيانات المتجر.", null);

                return (true, null, new List<Modules.Catalog.Entities.Merchant> { single });
            }

            if (mIds.Count == 2)
            {
                var merchants = await _merchantService.Queryable()
                    .Where(x => mIds.Contains(x.Id))
                    .ToListAsync();

                if (merchants.Count < 2)
                {
                    foreach (var id in mIds)
                    {
                        if (!merchants.Any(x => x.Id == id))
                        {
                            var m = await _merchantService.FindAsync(id);
                            if (m != null) merchants.Add(m);
                        }
                    }
                }

                if (merchants.Count < 2)
                    return (false, "تعذر العثور على بيانات أحد المتاجر المحددة.", null);

                var restCount = merchants.Count(x => x.MerchantKind == MerchantKind.Restaurant);
                var marketCount = merchants.Count(x => x.MerchantKind != MerchantKind.Restaurant);

                if (restCount > 1)
                    return (false, "يمكن إتمام الطلب من مطعم واحد فقط في كل طلب. يرجى تعديل السلة والمحاولة مرة أخرى.", null);

                if (marketCount > 1)
                    return (false, "يمكن إتمام الطلب من متجر/ماركت واحد فقط في كل طلب. يرجى تعديل السلة والمحاولة مرة أخرى.", null);

                return (true, null, merchants);
            }

            return (false, "يمكن إتمام الطلب من مطعم واحد ومتجر واحد فقط كحد أقصى.", null);
        }

        private async Task<List<OrderDetail>> GetOrderDetails(CartItem[] items)
        {
            var orderDetails = new List<OrderDetail>();
            var usdRate = await _merchantService.GetUsdRate();

            foreach (var item in items ?? Array.Empty<CartItem>())
            {
                string warning = null;

                if (item.Quantity <= 0)
                {
                    warning = "الكمية المطلوبة للمنتج غير صالحة." + Environment.NewLine;
                }

                if (item.MerchantId <= 0)
                {
                    warning = (warning ?? "") + "يجب تحديد المتجر المطلوب للمنتج." + Environment.NewLine;
                }

                var p = await _service.GetProduct(item.ProductId);
                if (p == null)
                {
                    warning = (warning ?? "") + "!للأسف، هذا المنتج لم يعد متوفراً" + Environment.NewLine;
                }

                Modules.Catalog.Entities.Merchant merchant = null;
                if (item.MerchantId > 0)
                {
                    merchant = await _merchantService.FindAsync(item.MerchantId);
                    if (merchant == null || !merchant.Active || merchant.DeletionDate != null)
                    {
                        warning = (warning ?? "") + "!للأسف، هذا المتجر غير متاح حالياً لاستقبال الطلبات" + Environment.NewLine;
                    }
                }

                // Strict merchant pricing check: NEVER silently substitute another merchant
                MerchantProductDto mp = null;
                if (item.MerchantId > 0 && merchant != null && merchant.Active)
                {
                    try
                    {
                        mp = await _merchantService.GetMerchantProductPrice(item.MerchantId, item.ProductId);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "GetMerchantProductPrice failed for product {ProductId}, merchant {MerchantId}", item.ProductId, item.MerchantId);
                    }
                }

                decimal singlePrice = 0m;
                decimal singleFinalPrice = 0m;
                decimal merchantProfit = 0m;
                decimal additionalProfit = 0m;

                if (mp != null && mp.FinalPrice > 0)
                {
                    singlePrice = mp.Price;
                    singleFinalPrice = mp.FinalPrice;
                    merchantProfit = mp.MerchantProfit;
                    // Preserve the contracted merchant commission in the order
                    // accounting snapshot. FinalPrice no longer contains any
                    // product-level extra profit.
                    additionalProfit = mp.FinalPrice - mp.MerchantPrice;
                    if (merchant?.MerchantKind == MerchantKind.Restaurant)
                    {
                        var maxOrderQuantity = mp.MaxOrderQuantity ?? 20;
                        if (item.Quantity > maxOrderQuantity)
                            warning = (warning ?? "") + $"الحد الأقصى لطلب هذا الصنف هو {maxOrderQuantity}." + Environment.NewLine;
                    }
                }
                else
                {
                    warning = (warning ?? "") + "!للأسف، المتجر لم يعد يوفر هذا المنتج أو سعره غير محدد" + Environment.NewLine;
                }

                var prevCartItem = orderDetails.FirstOrDefault(x => x.ProductId == item.ProductId && x.MerchantId == item.MerchantId);
                if (prevCartItem != null)
                {
                    prevCartItem.Quantity += item.Quantity;
                    if (merchant?.MerchantKind == MerchantKind.Restaurant && mp != null)
                    {
                        var maxOrderQuantity = mp.MaxOrderQuantity ?? 20;
                        if (prevCartItem.Quantity > maxOrderQuantity)
                            prevCartItem.Warning = $"الحد الأقصى لطلب هذا الصنف هو {maxOrderQuantity}.";
                    }
                }
                else
                {
                    orderDetails.Add(new OrderDetail
                    {
                        Quantity = item.Quantity,
                        ProductId = p?.Id ?? item.ProductId,
                        ProductTitle = p?.Title,
                        ProductUnit = p?.Unit,
                        ProductImage = p?.Photos,
                        MerchantId = item.MerchantId,
                        MerchantTitle = merchant?.Title,
                        CommissionRatePercent = merchant?.ProfitOutOfMerchantPricePercent ?? 0m,
                        IsPlatformOwnedSnapshot = merchant?.MerchantKind == MerchantKind.DarkStore,
                        SingleMerchantProfit = merchantProfit,
                        SinglePrice = singlePrice,
                        SingleFinalPrice = singleFinalPrice,
                        SingleAdditionalProfit = additionalProfit,
                        Warning = warning
                    });
                }
            }
            return orderDetails;
        }

        private async Task<decimal> GetDeliveryFee(IEnumerable<OrderDetail> orderDetails)
        {
            var merchantIds = (orderDetails ?? Enumerable.Empty<OrderDetail>())
                .Where(x => x.MerchantId > 0)
                .Select(x => x.MerchantId)
                .Distinct()
                .ToArray();

            if (merchantIds.Length == 0)
                return 0m;

            var dbMerchants = await _merchantService.Queryable()
                .Where(x => merchantIds.Contains(x.Id))
                .ToListAsync();

            decimal fee = 0m;
            foreach (var id in merchantIds)
            {
                var m = dbMerchants.FirstOrDefault(x => x.Id == id) ?? await _merchantService.FindAsync(id);
                if (m != null)
                {
                    fee += m.DeliveryFee;
                }
            }
            return fee;
        }

        private CanonicalOrderMoneyDto CalculateCanonicalMoney(
            IEnumerable<OrderDetailDto> details,
            decimal deliveryFee,
            Modules.Orders.Entities.PaymentMethod paymentMethod,
            decimal? captainEarning = null,
            bool? commissionIsMarkup = null,
            bool commissionIsPercentageOfGross = false)
        {
            var materialized = (details ?? Enumerable.Empty<OrderDetailDto>()).ToArray();
            var merchantContracts = materialized
                .GroupBy(x => x.MerchantId)
                .Select(g => new MerchantCommissionInfo
                {
                    MerchantId = g.Key,
                    MerchantTitle = g.First().MerchantTitle,
                    CommissionRatePercent = g.First().CommissionRatePercent,
                    IsDarkStore = g.First().IsPlatformOwnedSnapshot
                })
                .ToArray();

            return _moneyCalculationService?.CalculateOrderMoney(
                materialized,
                deliveryFee,
                paymentMethod,
                merchantCommissionInfos: merchantContracts,
                captainEarning: captainEarning ?? deliveryFee,
                currency: "SYP",
                commissionIsMarkup: commissionIsMarkup ?? true,
                commissionIsPercentageOfGross: commissionIsPercentageOfGross);
        }

        private decimal CalculateCaptainEarningForDetails(
            DriverPricingSetting setting,
            IEnumerable<OrderDetail> details,
            decimal customerLat,
            decimal customerLng,
            IEnumerable<Modules.Catalog.Entities.Merchant> merchants)
        {
            var merchantLookup = (merchants ?? Enumerable.Empty<Modules.Catalog.Entities.Merchant>())
                .GroupBy(x => x.Id)
                .ToDictionary(g => g.Key, g => g.First());
            return (details ?? Enumerable.Empty<OrderDetail>())
                .GroupBy(x => x.MerchantId)
                .Sum(group =>
                {
                    merchantLookup.TryGetValue(group.Key, out var merchant);
                    var fallbackFee = merchant?.DeliveryFee ?? 0m;
                    if (_driverPricingService == null)
                        return fallbackFee;

                    return _driverPricingService.CalculateCaptainEarning(
                        setting,
                        customerLat,
                        customerLng,
                        merchant?.Lat ?? 0m,
                        merchant?.Lng ?? 0m,
                        fallbackFee);
                });
        }

        private CustomerDeliveryFeeQuote CalculateCustomerDeliveryFeeForDetails(
            DriverPricingSetting setting,
            IEnumerable<OrderDetail> details,
            decimal customerLat,
            decimal customerLng,
            IEnumerable<Modules.Catalog.Entities.Merchant> merchants)
        {
            var merchantLookup = (merchants ?? Enumerable.Empty<Modules.Catalog.Entities.Merchant>())
                .GroupBy(x => x.Id)
                .ToDictionary(g => g.Key, g => g.First());
            var distinctMerchantIds = (details ?? Enumerable.Empty<OrderDetail>())
                .Select(x => x.MerchantId)
                .Where(x => x > 0)
                .Distinct()
                .ToArray();

            if (distinctMerchantIds.Length == 0)
            {
                return new CustomerDeliveryFeeQuote();
            }

            decimal totalOriginalFee = 0m;
            decimal totalActualFee = 0m;
            decimal maxDistance = 0m;
            decimal rate = setting?.CustomerRatePerKm > 0m ? setting.CustomerRatePerKm : 45m;
            bool isFree = setting?.IsFreeDeliveryEnabled == true;

            foreach (var mId in distinctMerchantIds)
            {
                merchantLookup.TryGetValue(mId, out var merchant);
                var quote = _driverPricingService?.CalculateCustomerDeliveryFee(
                    setting, customerLat, customerLng, merchant?.Lat ?? 0m, merchant?.Lng ?? 0m, merchant?.DeliveryFee ?? 0m);

                if (quote == null)
                {
                    decimal fallback = merchant?.DeliveryFee ?? 0m;
                    quote = new CustomerDeliveryFeeQuote
                    {
                        CustomerDeliveryFee = isFree ? 0m : fallback,
                        OriginalDeliveryFee = fallback,
                        DistanceInKm = 0m,
                        CustomerRatePerKm = rate,
                        IsFreeDelivery = isFree
                    };
                }

                totalOriginalFee += quote.OriginalDeliveryFee;
                totalActualFee += quote.CustomerDeliveryFee;
                if (quote.DistanceInKm > maxDistance)
                {
                    maxDistance = quote.DistanceInKm;
                }
            }

            return new CustomerDeliveryFeeQuote
            {
                DistanceInKm = maxDistance,
                CustomerRatePerKm = rate,
                OriginalDeliveryFee = totalOriginalFee,
                CustomerDeliveryFee = totalActualFee,
                IsFreeDelivery = isFree
            };
        }

        private List<OrderDetail> SetOrderId(List<OrderDetail> input, int orderId = 0)
        {
            foreach (var item in input)
            {
                item.OrderId = orderId;
            }
            return input;
        }


        // <summary>
        // Verify Cart Order
        // </summary>
        // <returns></returns>
        //[HttpPost]
        //[Route("VerifyOrder")]
        //public async Task<ActionResult<bool>> VerifyOrder(VerifyPhoneNumber m)
        //{
        //    var phoneNumber = m.PhoneNumber?.Trim().Replace(" ", "").Replace("+", "");
        //    var user = await _userManager.Users.FirstOrDefaultAsync(x => x.PhoneNumber == phoneNumber);
        //
        //    if (user == null)
        //        return BadRequest("Invalid User!");
        //
        //    var result = await _userManager.ChangePhoneNumberAsync(user, phoneNumber, m.Code);
        //    if (!result.Succeeded)
        //    {
        //        return BadRequest("Couln't verify code");
        //    }
        //
        //    var currentCart = await _orderService.GetCurrentUserCart(user.Id);
        //
        //    currentCart.OrderStatus = OrderStatus.Success;
        //
        //    await _uow.SaveChangesAsync();
        //    return true;
        //}


        //public enum PaymentMethod
        //{
        //    [Display(Name = "Other", ResourceType = typeof(_PaymentMethod))]
        //    Other = 0,
        //    [Display(Name = "UnofficialTranfer", ResourceType = typeof(_PaymentMethod))]
        //    UnofficialTranfer = 1,
        //    [Display(Name = "CreditCardPayment", ResourceType = typeof(_PaymentMethod))]
        //    CreditCardPayment = 2,
        //    [Display(Name = "BankTransfer", ResourceType = typeof(_PaymentMethod))]
        //    BankTransfer = 3
        //}
    }
}
