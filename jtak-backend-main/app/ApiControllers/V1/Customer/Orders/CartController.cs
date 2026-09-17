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
using App.Orders.Data;
using System;
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

        public CartController(IOrdersUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IProductService service,
            IOrderService orderService,
            IOrderDetailService orderDetailService,
            IMerchantService merchantService,
            IInventoryBatchService batchService,
            ILogger<CartController> logger,
            IMapper mapper)
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
        }

        /// <summary>
        /// Post Current Cart with Details
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Calc/{lat}/{lng}")]
        public async Task<ActionResult<OrderDto>> GetCalc(decimal lat, decimal lng, CartItem[] items)
        {
            var uid = User.GetUserId();
            var orderDetails = await GetOrderDetails(items, lat, lng);
            var order = new OrderDto
            {
                OrderDetails = orderDetails.Select(x => x.ToDto()).ToArray()
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
            // Keep the legacy enum values for compatibility, but never allow an
            // unsupported method to create a pending/fulfillable order through
            // a direct API call.
            if (m == null || m.PaymentMethod != Modules.Orders.Entities.PaymentMethod.PayOnDelivery)
                return BadRequest(ApiErr.Create("الدفع عند الاستلام هو طريقة الدفع المتاحة حالياً."));

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
            // Normalize PhoneNumber
            m.Phonenumber = m.Phonenumber?.Trim().Replace(" ", "");

            var orderDetails = await GetOrderDetails(m.CartItems, m.Lat, m.Lng);
            var isPayOnDelivery = m.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
            var isEmptyDetails = orderDetails.Count == 0;

            // Business rule: An order can have at most 1 Restaurant and at most 1 Market
            var distinctMerchantIds = orderDetails.Select(x => x.MerchantId).Distinct().ToList();
            if (distinctMerchantIds.Count > 1)
            {
                var merchantsInOrder = await _merchantService.Queryable()
                    .Where(m => distinctMerchantIds.Contains(m.Id))
                    .Select(m => new { m.Id, m.MerchantKind })
                    .ToListAsync();

                int restaurantCount = merchantsInOrder.Count(m => m.MerchantKind == MerchantKind.Restaurant);
                int marketCount = merchantsInOrder.Count(m => m.MerchantKind != MerchantKind.Restaurant);

                if (restaurantCount > 1 || marketCount > 1)
                {
                    return BadRequest("لا يمكن الطلب من أكثر من مطعم واحد وماركت واحد في نفس الطلب");
                }
            }

            var lastPurchase = await _orderService.Queryable()
                                           .Where(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Success)
                                           .OrderByDescending(x => x.PurchaseDate)
                                           .Select(x => x.PurchaseDate)
                                           .FirstOrDefaultAsync();
            if (lastPurchase != null && DateTime.UtcNow.AddSeconds(-10) < lastPurchase)
            {
                return BadRequest("Too many Cart Submits");
            }
            var order = new OrderDto
            {
                Phonenumber = m.Phonenumber,
                Lat = m.Lat,
                Lng = m.Lng,
                Address = m.Address,
                UserId = user.Id,
                User = user.FullName,
                PurchaseDate = null,
                OrderStatus = !isPayOnDelivery || isEmptyDetails ? OrderStatus.Pending : OrderStatus.Success,
                OrderDetails = orderDetails.Select(x => x.ToDto()).ToArray()
            };

            if (!order.CanSubmit)
            {
                return BadRequest(order);
            }

            // A submitted order must be server-authoritative. Reuse an unpaid cart if
            // present, but always promote it and attach the new details correctly.
            var cart = await _orderService.Queryable().FirstOrDefaultAsync(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Pending);
            if (cart == null)
            {
                cart = new Order { UserId = user.Id };
                _orderService.Insert(cart);
                await _uow.SaveChangesAsync();
            }
            else
            {
                // Remove existing order details from the previous pending session to prevent item accumulation
                var existingDetails = await _orderDetailService.Queryable()
                                                              .Where(x => x.OrderId == cart.Id)
                                                              .ToListAsync();
                foreach (var item in existingDetails)
                {
                    _orderDetailService.Delete(item);
                }
                if (existingDetails.Count > 0)
                {
                    await _uow.SaveChangesAsync();
                }
            }

            cart.User = user.FullName;
            cart.Phonenumber = m.Phonenumber;
            cart.Lat = m.Lat;
            cart.Lng = m.Lng;
            cart.Address = m.Address;
            cart.PaymentMethod = m.PaymentMethod;
            cart.OrderStatus = order.OrderStatus;
            cart.PurchaseDate = order.OrderStatus == OrderStatus.Success ? DateTime.UtcNow : null;
            if (string.IsNullOrEmpty(cart.DeliveryOtp))
            {
                cart.DeliveryOtp = new System.Random().Next(1000, 9999).ToString();
            }
            SetOrderId(orderDetails, cart.Id);
            _orderDetailService.Insert(orderDetails);
            await _uow.SaveChangesAsync();

            // Reserve stock via FEFO for any dark store / batch-managed items
            if (cart.OrderStatus == OrderStatus.Success)
            {
                foreach (var detail in orderDetails)
                {
                    try
                    {
                        await _batchService.ReserveStockFEFOAsync(cart.Id, detail.Id, detail.ProductId, detail.MerchantId, detail.Quantity);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to reserve batch stock for order {OrderId}, detail {DetailId}", cart.Id, detail.Id);

                        // Compensate: release any reservations made so far for this cart
                        await _batchService.ReleaseReservationAsync(cart.Id, reason: "Insufficient stock during checkout");

                        // Rollback inserted details and reset cart state
                        _uow.Context.OrderDetails.RemoveRange(orderDetails);
                        cart.OrderStatus = OrderStatus.Pending;
                        cart.PurchaseDate = null;
                        await _uow.SaveChangesAsync();

                        return BadRequest(ApiErr.Create($"الكمية المطلوبة من المنتج '{detail.ProductTitle}' غير متوفرة حالياً في المخزون."));
                    }
                }
            }

            // Notify merchants
            var merchantOrders = orderDetails.GroupBy(x => x.MerchantId).ToArray();
            foreach (var merchantOrder in merchantOrders)
            {
                var ownerId = await _merchantService.GetOwnerId(merchantOrder.Key);
                var details = merchantOrder.ToArray();
                await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, cart.Id, details);
            }

            var orderedMerchantIds = merchantOrders.Select(x => x.Key).ToArray();
            var hasExternalMerchant = await _merchantService.Queryable()
                .AnyAsync(x => orderedMerchantIds.Contains(x.Id) && x.MerchantKind != MerchantKind.DarkStore);
            var adminIds = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString()))
                .Where(x => x.IsActive).Select(x => x.Id).ToArray();
            if (adminIds.Length > 0)
                await _notificationService.SendAdminNewOrder(adminIds, cart.Id, hasExternalMerchant);

            order.Id = cart.Id;
            order.PurchaseDate = cart.PurchaseDate;
            order.DeliveryOtp = cart.DeliveryOtp;
            order.OrderDetails = orderDetails.Select(x => x.ToDto()).ToArray();

            //_logger.LogError(JsonSerializer.Serialize(order));

            return order;
        }

        private async Task<List<OrderDetail>> GetOrderDetails(CartItem[] items, decimal lat, decimal lng)
        {
            var orderDetails = new List<OrderDetail>();
            var usdRate = await _merchantService.GetUsdRate();

            foreach (var item in items ?? Array.Empty<CartItem>())
            {
                string warning = null;

                if (item.Quantity <= 0)
                {
                    warning = "Invalid product quantity." + Environment.NewLine;
                }

                var p = await _service.GetProduct(item.ProductId);
                if (p == null)
                {
                    warning += "!للأسف، هذا المنتج لم يعد متوفراً" + Environment.NewLine;
                }

                MerchantProductDto mp = null;

                // 1. Try exact merchant with delivery range check
                if (item.MerchantId > 0 && lat != 0 && lng != 0)
                {
                    try
                    {
                        mp = await _merchantService.GetBestProductPrice(item.ProductId, new[] { item.MerchantId }, lat, lng);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "GetBestProductPrice with lat/lng failed for product {ProductId}, merchant {MerchantId}", item.ProductId, item.MerchantId);
                    }
                }

                // 2. If range check excluded the merchant (e.g. customer ordering from outside radius or radius not set),
                // query merchant directly without geographic restriction
                if (mp == null && item.MerchantId > 0)
                {
                    try
                    {
                        mp = await _merchantService.GetBestProductPrice(item.ProductId, new[] { item.MerchantId });
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "GetBestProductPrice without lat/lng failed for product {ProductId}, merchant {MerchantId}", item.ProductId, item.MerchantId);
                    }
                }

                // 3. If still null (or item.MerchantId was 0 / mismatched), check any active merchant globally
                if (mp == null)
                {
                    try
                    {
                        mp = await _merchantService.GetBestProductPrice(item.ProductId, null);
                        if (mp != null && mp.MerchantId > 0)
                        {
                            item.MerchantId = mp.MerchantId;
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "GetBestProductPrice global failed for product {ProductId}", item.ProductId);
                    }
                }

                // Ensure a positive valid merchant ID
                if (item.MerchantId <= 0)
                {
                    item.MerchantId = mp?.MerchantId ?? 1;
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
                    additionalProfit = mp.AdditionalProfit;
                }
                else if (item.SingleFinalPrice.HasValue && item.SingleFinalPrice.Value > 0)
                {
                    singlePrice = item.SingleFinalPrice.Value;
                    singleFinalPrice = item.SingleFinalPrice.Value;
                }

                // Only emit warning if product doesn't exist in DB at all or has 0 price
                if (p == null)
                {
                    if (warning == null) warning = "!للأسف، هذا المنتج لم يعد متوفراً" + Environment.NewLine;
                }
                else if (singleFinalPrice <= 0)
                {
                    warning += "!للأسف، المتجر لم يعد يوفر هذا المنتج" + Environment.NewLine;
                }

                var prevCartItem = orderDetails.FirstOrDefault(x => x.ProductId == item.ProductId && x.MerchantId == item.MerchantId);
                if (prevCartItem != null)
                {
                    prevCartItem.Quantity += item.Quantity;
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
