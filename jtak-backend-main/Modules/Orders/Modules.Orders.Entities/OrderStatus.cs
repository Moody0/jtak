using System.ComponentModel.DataAnnotations;
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
}
