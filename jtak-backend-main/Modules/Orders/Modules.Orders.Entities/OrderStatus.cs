using System.ComponentModel.DataAnnotations;
using System.Linq;
using App.Shared.Entities.Resources;

namespace Modules.Orders.Entities
{
    public enum OrderStatus
    {
        /// <summary>
        /// Cart order
        /// </summary>
        [Display(Name = "Pending", ResourceType = typeof(_OrderStatus))]
        Pending = 0,

        /// <summary>
        /// Confirmed / Paid
        /// </summary>
        [Display(Name = "Success", ResourceType = typeof(_OrderStatus))]
        Success = 1
    }
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum OrderDetailStatus
    {
        Pending = 0,

        //[Display(Name = "Accepted", ResourceType = typeof(_OrderStatus))]
        MerchantAccepted = 1,

        //[Display(Name = "Shipping", ResourceType = typeof(_OrderStatus))]
        ShippingStarted = 2,

        //[Display(Name = "Delivered", ResourceType = typeof(_OrderStatus))]
        Delivered = 3,

        //[Display(Name = "Rejected", ResourceType = typeof(_OrderStatus))]
        MerchantRejected = 4,

        //[Display(Name = "CustomerPending", ResourceType = typeof(_OrderStatus))]
        CustomerPending = 5,

        //[Display(Name = "Canceled", ResourceType = typeof(_OrderStatus))]
        CustomerCanceled = 6,

        //[Display(Name = "Canceled", ResourceType = typeof(_OrderStatus))]
        DeliveryCanceled = 7,

        /// <summary>
        /// Merchant finished preparation; admin may now assign a courier.
        /// </summary>
        ReadyForPickup = 8
    }

    public enum AggregateOrderStatus
    {
        Draft = 0,
        Pending = 1,
        MerchantAccepted = 2,
        ReadyForPickup = 3,
        InTransit = 4,
        Delivered = 5,
        PartiallyDelivered = 6,
        CustomerCanceled = 7,
        DeliveryCanceled = 8,
        MerchantRejected = 9
    }

    public static class OrderAggregateStatusHelper
    {
        public static AggregateOrderStatus Calculate(OrderStatus orderStatus, System.Collections.Generic.IEnumerable<OrderDetailStatus> detailStatuses, System.DateTime? deliveredAt)
        {
            if (orderStatus == OrderStatus.Pending)
                return AggregateOrderStatus.Draft;

            var statuses = detailStatuses?.ToList() ?? new System.Collections.Generic.List<OrderDetailStatus>();
            if (statuses.Count == 0)
                return AggregateOrderStatus.Pending;

            bool allTerminal = statuses.All(s =>
                s == OrderDetailStatus.MerchantRejected ||
                s == OrderDetailStatus.CustomerCanceled ||
                s == OrderDetailStatus.DeliveryCanceled);

            if (allTerminal)
            {
                if (statuses.All(s => s == OrderDetailStatus.CustomerCanceled))
                    return AggregateOrderStatus.CustomerCanceled;
                if (statuses.All(s => s == OrderDetailStatus.DeliveryCanceled))
                    return AggregateOrderStatus.DeliveryCanceled;
                if (statuses.All(s => s == OrderDetailStatus.MerchantRejected))
                    return AggregateOrderStatus.MerchantRejected;

                if (statuses.Any(s => s == OrderDetailStatus.MerchantRejected))
                    return AggregateOrderStatus.MerchantRejected;
                if (statuses.Any(s => s == OrderDetailStatus.DeliveryCanceled))
                    return AggregateOrderStatus.DeliveryCanceled;
                return AggregateOrderStatus.CustomerCanceled;
            }

            var active = statuses.Where(s =>
                s != OrderDetailStatus.MerchantRejected &&
                s != OrderDetailStatus.CustomerCanceled &&
                s != OrderDetailStatus.DeliveryCanceled).ToList();

            if (active.Count > 0 && (deliveredAt.HasValue || active.All(s => s == OrderDetailStatus.Delivered)))
            {
                bool hasTerminalExceptions = statuses.Any(s =>
                    s == OrderDetailStatus.MerchantRejected ||
                    s == OrderDetailStatus.CustomerCanceled ||
                    s == OrderDetailStatus.DeliveryCanceled);

                return hasTerminalExceptions
                    ? AggregateOrderStatus.PartiallyDelivered
                    : AggregateOrderStatus.Delivered;
            }

            if (active.Any(s => s == OrderDetailStatus.ShippingStarted))
                return AggregateOrderStatus.InTransit;

            if (active.Count > 0 && active.All(s => s == OrderDetailStatus.ReadyForPickup))
                return AggregateOrderStatus.ReadyForPickup;

            if (active.Any(s => s == OrderDetailStatus.MerchantAccepted))
                return AggregateOrderStatus.MerchantAccepted;

            return AggregateOrderStatus.Pending;
        }

        public static string ToKey(AggregateOrderStatus status) => status switch
        {
            AggregateOrderStatus.Draft => "DRAFT",
            AggregateOrderStatus.Pending => "PENDING",
            AggregateOrderStatus.MerchantAccepted => "MERCHANT_ACCEPTED",
            AggregateOrderStatus.ReadyForPickup => "READY_FOR_PICKUP",
            AggregateOrderStatus.InTransit => "IN_TRANSIT",
            AggregateOrderStatus.Delivered => "DELIVERED",
            AggregateOrderStatus.PartiallyDelivered => "PARTIALLY_DELIVERED",
            AggregateOrderStatus.CustomerCanceled => "CUSTOMER_CANCELED",
            AggregateOrderStatus.DeliveryCanceled => "DELIVERY_CANCELED",
            AggregateOrderStatus.MerchantRejected => "MERCHANT_REJECTED",
            _ => "UNKNOWN"
        };

        public static string ToArabic(AggregateOrderStatus status) => status switch
        {
            AggregateOrderStatus.Draft => "مسودة",
            AggregateOrderStatus.Pending => "قيد الانتظار والموافقة",
            AggregateOrderStatus.MerchantAccepted => "قيد التحضير والتجهيز",
            AggregateOrderStatus.ReadyForPickup => "جاهز للاستلام والتوصيل",
            AggregateOrderStatus.InTransit => "في الطريق للتوصيل",
            AggregateOrderStatus.Delivered => "تم التسليم بنجاح",
            AggregateOrderStatus.PartiallyDelivered => "تم التسليم مع تعديلات جزئية",
            AggregateOrderStatus.CustomerCanceled => "ملغي من العميل",
            AggregateOrderStatus.DeliveryCanceled => "فشل التوصيل / مرتجع",
            AggregateOrderStatus.MerchantRejected => "مرفوض من المتجر",
            _ => "غير معروف"
        };

        public static string ToEnglish(AggregateOrderStatus status) => status switch
        {
            AggregateOrderStatus.Draft => "Draft",
            AggregateOrderStatus.Pending => "Pending Approval",
            AggregateOrderStatus.MerchantAccepted => "Preparing",
            AggregateOrderStatus.ReadyForPickup => "Ready for Pickup",
            AggregateOrderStatus.InTransit => "In Transit",
            AggregateOrderStatus.Delivered => "Delivered",
            AggregateOrderStatus.PartiallyDelivered => "Partially Delivered",
            AggregateOrderStatus.CustomerCanceled => "Canceled by Customer",
            AggregateOrderStatus.DeliveryCanceled => "Delivery Failed / Returned",
            AggregateOrderStatus.MerchantRejected => "Rejected by Merchant",
            _ => "Unknown"
        };
    }
}

