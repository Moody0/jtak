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

        public CartController(IOrdersUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IProductService service,
            IOrderService orderService,
            IOrderDetailService orderDetailService,
            IMerchantService merchantService,
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
            //_logger.LogError(JsonSerializer.Serialize(m));
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
                return Unauthorized();
            // Normalize PhoneNumber
            m.Phonenumber = m.Phonenumber?.Trim().Replace(" ", "");

            var orderDetails = await GetOrderDetails(m.CartItems, m.Lat, m.Lng);
            var isPayOnDelivery = m.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
            var isEmptyDetails = orderDetails.Count == 0;

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

            cart.User = user.FullName;
            cart.Phonenumber = m.Phonenumber;
            cart.Lat = m.Lat;
            cart.Lng = m.Lng;
            cart.Address = m.Address;
            cart.PaymentMethod = m.PaymentMethod;
            cart.OrderStatus = order.OrderStatus;
            cart.PurchaseDate = order.OrderStatus == OrderStatus.Success ? DateTime.UtcNow : null;
            SetOrderId(orderDetails, cart.Id);
            _orderDetailService.Insert(orderDetails);
            await _uow.SaveChangesAsync();

            // Notify merchants
            var merchantOrders = orderDetails.GroupBy(x => x.MerchantId).ToArray();
            foreach (var merchantOrder in merchantOrders)
            {
                var ownerId = await _merchantService.GetOwnerId(merchantOrder.Key);
                var details = merchantOrder.ToArray();
                await _notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, cart.Id, details);
            }

            order.Id = cart.Id;
            order.PurchaseDate = cart.PurchaseDate;
            order.OrderDetails = orderDetails.Select(x => x.ToDto()).ToArray();

            //_logger.LogError(JsonSerializer.Serialize(order));

            return order;
        }

        private async Task<List<OrderDetail>> GetOrderDetails(CartItem[] items, decimal lat, decimal lng)
        {
            var orderDetails = new List<OrderDetail>();

            foreach (var item in items ?? Array.Empty<CartItem>())
            {
                string warning = null;

                if (item.Quantity <= 0)
                    warning = "Invalid product quantity." + Environment.NewLine;

                if (item.MerchantId <= 0)
                    warning += "Invalid merchant." + Environment.NewLine;

                var p = await _service.GetProduct(item.ProductId);
                if (p == null)
                    warning = $"!للأسف، هذا المنتج لم يعد متوفرا" + Environment.NewLine;

                // Price and validate the exact merchant selected by the customer.
                // Using the global best price while storing a different merchant causes
                // incorrect balances and sends the order to the wrong owner.
                var mp = await _merchantService.GetBestProductPrice(item.ProductId, new[] { item.MerchantId }, lat, lng);

                if (mp == null || mp.FinalPrice <= 0)
                {
                    warning += $"!للأسف، المتجر لم يعد يوفر هذا المنتج" + Environment.NewLine;
                }
                //else if (item.SingleFinalPrice.HasValue && item.SingleFinalPrice > 0 && mp != null && mp.FinalPrice != item.SingleFinalPrice)
                //{
                //    warning += $"لقد تغير سعر هذا المنتج من {item.SingleFinalPrice:0.00} إلى {mp?.FinalPrice ?? 0:0.00}";
                //}

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
                        //MerchantId = mp?.MerchantId ?? item.MerchantId,
                        MerchantId = item.MerchantId,
                        SingleMerchantProfit = mp?.MerchantProfit ?? 0m,
                        SinglePrice = mp?.Price ?? item.SingleFinalPrice ?? 0m,
                        SingleFinalPrice = mp?.FinalPrice ?? item.SingleFinalPrice ?? 0m,
                        SingleAdditionalProfit = mp?.AdditionalProfit ?? 0m,
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
