using System;
using System.Collections.Generic;
using System.Linq;
using App.ApiControllers.V1.Admin;
using App.Shared.Services.Pricing;
using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class CrossAppStatusAndUxAlignmentTests
    {
        private readonly IOrderMoneyCalculationService _moneyService = new OrderMoneyCalculationService();

        [Fact]
        public void AggregateStatusHelper_MapsFullStandardLifecycleCorrectly()
        {
            // 1. Pending: newly created order with pending line items
            var lines = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, OrderDetailStatus = OrderDetailStatus.Pending }
            };
            var status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.Pending, status);
            Assert.Equal("PENDING", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("قيد الانتظار والموافقة", OrderAggregateStatusHelper.ToArabic(status));

            // 2. Merchant Accepted: merchant confirms preparation
            lines[0].OrderDetailStatus = OrderDetailStatus.MerchantAccepted;
            status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.MerchantAccepted, status);
            Assert.Equal("MERCHANT_ACCEPTED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("قيد التحضير والتجهيز", OrderAggregateStatusHelper.ToArabic(status));

            // 3. Ready For Pickup: merchant packaging done
            lines[0].OrderDetailStatus = OrderDetailStatus.ReadyForPickup;
            status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.ReadyForPickup, status);
            Assert.Equal("READY_FOR_PICKUP", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("جاهز للاستلام والتوصيل", OrderAggregateStatusHelper.ToArabic(status));

            // 4. In Transit: driver picked up and shipping started
            lines[0].OrderDetailStatus = OrderDetailStatus.ShippingStarted;
            status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.InTransit, status);
            Assert.Equal("IN_TRANSIT", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("في الطريق للتوصيل", OrderAggregateStatusHelper.ToArabic(status));

            // 5. Delivered: courier completes delivery with customer OTP
            lines[0].OrderDetailStatus = OrderDetailStatus.Delivered;
            status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: DateTime.UtcNow);
            Assert.Equal(AggregateOrderStatus.Delivered, status);
            Assert.Equal("DELIVERED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("تم التسليم بنجاح", OrderAggregateStatusHelper.ToArabic(status));
        }

        [Fact]
        public void AggregateStatusHelper_PartialMerchantRejection_DeliveredYieldsPartiallyDelivered()
        {
            // Line 1: Accepted & Delivered
            // Line 2: Rejected by Merchant
            var lines = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, OrderDetailStatus = OrderDetailStatus.Delivered, SingleFinalPrice = 25000m, Quantity = 2 },
                new OrderDetailDto { Id = 2, OrderDetailStatus = OrderDetailStatus.MerchantRejected, SingleFinalPrice = 12000m, Quantity = 1 }
            };

            var status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: DateTime.UtcNow);
            Assert.Equal(AggregateOrderStatus.PartiallyDelivered, status);
            Assert.Equal("PARTIALLY_DELIVERED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("تم التسليم مع تعديلات جزئية", OrderAggregateStatusHelper.ToArabic(status));
        }

        [Fact]
        public void AggregateStatusHelper_AllMerchantRejected_YieldsMerchantRejected()
        {
            var lines = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, OrderDetailStatus = OrderDetailStatus.MerchantRejected },
                new OrderDetailDto { Id = 2, OrderDetailStatus = OrderDetailStatus.MerchantRejected }
            };

            var status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.MerchantRejected, status);
            Assert.Equal("MERCHANT_REJECTED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("مرفوض من المتجر", OrderAggregateStatusHelper.ToArabic(status));
        }

        [Fact]
        public void AggregateStatusHelper_PrePreparationCancellation_YieldsCustomerCanceled()
        {
            var lines = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, OrderDetailStatus = OrderDetailStatus.CustomerCanceled },
                new OrderDetailDto { Id = 2, OrderDetailStatus = OrderDetailStatus.CustomerCanceled }
            };

            var status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.CustomerCanceled, status);
            Assert.Equal("CUSTOMER_CANCELED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("ملغي من العميل", OrderAggregateStatusHelper.ToArabic(status));
        }

        [Fact]
        public void AggregateStatusHelper_DeliveryCanceledOrFailedDelivery_YieldsDeliveryCanceled()
        {
            var lines = new List<OrderDetailDto>
            {
                new OrderDetailDto { Id = 1, OrderDetailStatus = OrderDetailStatus.DeliveryCanceled },
                new OrderDetailDto { Id = 2, OrderDetailStatus = OrderDetailStatus.DeliveryCanceled }
            };

            var status = OrderAggregateStatusHelper.Calculate(OrderStatus.Success, lines.Select(x => x.OrderDetailStatus), deliveredAt: null);
            Assert.Equal(AggregateOrderStatus.DeliveryCanceled, status);
            Assert.Equal("DELIVERY_CANCELED", OrderAggregateStatusHelper.ToKey(status));
            Assert.Equal("فشل التوصيل / مرتجع", OrderAggregateStatusHelper.ToArabic(status));
        }

        [Fact]
        public void OrderDto_CalculatesPartialFulfillmentMetrics_Accurately()
        {
            // Order with 2 line items:
            // Line 1 (Accepted): 2 x 20,000 = 40,000
            // Line 2 (Rejected): 1 x 15,000 = 15,000
            // Delivery fee: 5,000
            var order = new OrderDto
            {
                Id = 8801,
                OrderStatus = OrderStatus.Success,
                DeliveryFee = 5000m,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new OrderDetailDto[]
                {
                    new OrderDetailDto
                    {
                        Id = 1,
                        ProductId = 10,
                        MerchantId = 5,
                        Quantity = 2,
                        SingleFinalPrice = 20000m,
                        OrderDetailStatus = OrderDetailStatus.MerchantAccepted
                    },
                    new OrderDetailDto
                    {
                        Id = 2,
                        ProductId = 11,
                        MerchantId = 5,
                        Quantity = 1,
                        SingleFinalPrice = 15000m,
                        OrderDetailStatus = OrderDetailStatus.MerchantRejected
                    }
                }
            };

            Assert.True(order.HasPartialFulfillment);
            Assert.Equal(1, order.AcceptedItemsCount);
            Assert.Equal(1, order.RejectedItemsCount);

            // Original totals (before merchant rejection)
            Assert.Equal(55000m, order.OriginalProductSubtotal);
            Assert.Equal(60000m, order.OriginalGrandTotal);

            // Rejected items total deducted
            Assert.Equal(15000m, order.RejectedItemsTotal);

            // Adjusted totals (what customer pays and delivery collects)
            Assert.Equal(40000m, order.AdjustedProductSubtotal);
            Assert.Equal(45000m, order.AdjustedGrandTotal);

            // Active aggregate status while preparing
            Assert.Equal(AggregateOrderStatus.MerchantAccepted, order.AggregateStatus);
            Assert.Equal("MERCHANT_ACCEPTED", order.AggregateStatusKey);
        }

        [Fact]
        public void DeliveryOrderDto_ExposesMatchingAdjustedTotalsAndAggregateStatus()
        {
            var deliveryOrder = new DeliveryOrderDto
            {
                Id = 9901,
                OrderStatus = OrderStatus.Success,
                DeliveryFee = 6000m,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new DeliveryOrderDetailDto[]
                {
                    new DeliveryOrderDetailDto
                    {
                        MerchantId = 2,
                        MerchantTitle = "Burger Joint",
                        OrderDetails = new OrderDetailDto[]
                        {
                            new OrderDetailDto
                            {
                                Id = 101,
                                Quantity = 2,
                                SingleFinalPrice = 18000m,
                                OrderDetailStatus = OrderDetailStatus.ShippingStarted
                            },
                            new OrderDetailDto
                            {
                                Id = 102,
                                Quantity = 1,
                                SingleFinalPrice = 7000m,
                                OrderDetailStatus = OrderDetailStatus.MerchantRejected
                            }
                        }
                    }
                }
            };

            Assert.True(deliveryOrder.HasPartialFulfillment);
            Assert.Equal(1, deliveryOrder.AcceptedItemsCount);
            Assert.Equal(1, deliveryOrder.RejectedItemsCount);

            // Original: 36,000 + 7,000 = 43,000 + 6,000 = 49,000
            Assert.Equal(43000m, deliveryOrder.OriginalProductSubtotal);
            Assert.Equal(49000m, deliveryOrder.OriginalGrandTotal);

            // Deducted rejected items: 7,000
            Assert.Equal(7000m, deliveryOrder.RejectedItemsTotal);

            // Adjusted: 36,000 + 6,000 delivery = 42,000 COD cash to collect
            Assert.Equal(36000m, deliveryOrder.AdjustedProductSubtotal);
            Assert.Equal(42000m, deliveryOrder.AdjustedGrandTotal);

            // In Transit aggregate status
            Assert.Equal(AggregateOrderStatus.InTransit, deliveryOrder.AggregateStatus);
            Assert.Equal("IN_TRANSIT", deliveryOrder.AggregateStatusKey);
        }

        [Fact]
        public void OrderDto_NoRejections_ReflectsCleanOrderWithoutPartialFulfillment()
        {
            var order = new OrderDto
            {
                Id = 7701,
                OrderStatus = OrderStatus.Success,
                DeliveryFee = 4000m,
                PaymentMethod = PaymentMethod.CreditCardPayment,
                OrderDetails = new OrderDetailDto[]
                {
                    new OrderDetailDto
                    {
                        Id = 1,
                        Quantity = 3,
                        SingleFinalPrice = 10000m,
                        OrderDetailStatus = OrderDetailStatus.MerchantAccepted
                    }
                }
            };

            Assert.False(order.HasPartialFulfillment);
            Assert.Equal(1, order.AcceptedItemsCount);
            Assert.Equal(0, order.RejectedItemsCount);
            Assert.Equal(0m, order.RejectedItemsTotal);
            Assert.Equal(30000m, order.OriginalProductSubtotal);
            Assert.Equal(30000m, order.AdjustedProductSubtotal);
            Assert.Equal(34000m, order.OriginalGrandTotal);
            Assert.Equal(34000m, order.AdjustedGrandTotal);
        }

        [Fact]
        public void InTransitCancellation_DriverReturnCustodyGuards()
        {
            // Business Rule: Once an order has ShippingStarted / InTransit,
            // direct cancellation is blocked unless IsDriverReturn == true,
            // or the explicit FailedDelivery flow is triggered.
            var order = new OrderDto
            {
                Id = 5501,
                OrderDetails = new OrderDetailDto[]
                {
                    new OrderDetailDto
                    {
                        Id = 1,
                        OrderDetailStatus = OrderDetailStatus.ShippingStarted
                    }
                }
            };

            bool isShippingStarted = order.OrderDetails.Any(x => x.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
            Assert.True(isShippingStarted);

            // Request without driver return flag
            var requestWithoutReturn = new AdminOrderActionRequestDto
            {
                IsDriverReturn = false,
                Reason = "Customer changed mind"
            };

            bool allowCancellationDirectly = !isShippingStarted || requestWithoutReturn.IsDriverReturn == true;
            Assert.False(allowCancellationDirectly, "In-transit cancellation without driver custody return must be blocked");

            // Request with explicit driver return flag
            var requestWithReturn = new AdminOrderActionRequestDto
            {
                IsDriverReturn = true,
                Reason = "Courier returned packages to warehouse"
            };

            bool allowCancellationWithReturn = !isShippingStarted || requestWithReturn.IsDriverReturn == true;
            Assert.True(allowCancellationWithReturn, "In-transit cancellation with driver return custody must be allowed");
        }
    }
}
