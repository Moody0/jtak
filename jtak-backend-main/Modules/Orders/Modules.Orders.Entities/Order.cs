using App.Shared.Entities.Resources;
using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace Modules.Orders.Entities
{
    public class Order : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [UIHint("RemoteDropDownList")]
        public Guid UserId { get; set; }
        public string User { get; set; }
        public Guid? DeliveryId { get; set; }
        public string DeliveryUser { get; set; }
        public decimal? DeliveryLat { get; set; }
        public decimal? DeliveryLng { get; set; }
        public DateTime? DeliveryLocationUpdatedAt { get; set; }

        public DateTime? PurchaseDate { get; set; }

        public string Description { get; set; }

        public string PaymentDescription { get; set; }
        public string Notes { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Address { get; set; }
        public string Phonenumber { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        //public Point Location { get; set; }
        public OrderStatus OrderStatus { get; set; }

        [StringLength(16)]
        public string DeliveryOtp { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public string ProofOfDeliverySignature { get; set; }
        public string ProofOfDeliveryPhotoUrl { get; set; }
        public string DeliveryNotes { get; set; }

        public virtual ICollection<OrderDetail> OrderDetails { get; set; }
    }

    public class DeliverOrderRequest
    {
        public int OrderId { get; set; }
        public string Otp { get; set; }
        public string Signature { get; set; }
        public string PhotoUrl { get; set; }
        public string Notes { get; set; }
    }

    public class OrderDto
    {
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "AppUser", ResourceType = typeof(_Order))]
        public string User { get; set; }

        [Display(Name = "AppUser", ResourceType = typeof(_Order))]
        public Guid UserId { get; set; }
        public Guid? DeliveryId { get; set; }
        public string DeliveryUser { get; set; }
        public string DeliveryUserPhone { get; set; }
        public decimal? DeliveryLat { get; set; }
        public decimal? DeliveryLng { get; set; }
        public DateTime? DeliveryLocationUpdatedAt { get; set; }

        [Display(Name = "PurchaseDate", ResourceType = typeof(_Order))]
        public DateTime? PurchaseDate { get; set; }

        [Display(Name = "Description", ResourceType = typeof(_Entities))]
        public string Description { get; set; }
        public string Notes { get; set; }

        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string Phonenumber { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Address { get; set; }

        public PaymentMethod PaymentMethod { get; set; }

        [Display(Name = "OrderStatus", ResourceType = typeof(_Order))]
        public OrderStatus OrderStatus { get; set; }

        public string DeliveryOtp { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public bool IsJtakMarketOrder { get; set; }
        public bool RequiresMerchantDecision { get; set; }
        public bool CanAdminApprove { get; set; }
        public bool CanAdminMarkReady { get; set; }
        public string AdminFlowMessage { get; set; }
        public string ProofOfDeliverySignature { get; set; }
        public string ProofOfDeliveryPhotoUrl { get; set; }
        public string DeliveryNotes { get; set; }

        [Display(Name = "OrderDetails", ResourceType = typeof(_Order))]
        public OrderDetailDto[] OrderDetails { get; set; } = Array.Empty<OrderDetailDto>();

        [Display(Name = "Price", ResourceType = typeof(_Order))]
        public decimal? Price => OrderDetails?.Where(x=> x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                         x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                         x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                         x.OrderDetailStatus != OrderDetailStatus.CustomerPending)
                                              .Sum(x => x.TotalPrice);

        [Display(Name = "CreatedDate", ResourceType = typeof(_Entities))]
        public DateTime CreatedDate { get; set; }

        public string Warning
        {
            get
            {
                if (MinCart() > Price)
                    return $"الحد الأدنى للطلبات هو {MinCart()} ليرة، لا يمكن إتمام الطلب";

                if (!IsDeliveryOpen())
                    return "سيتم توصيل المنتج في أوقات الدوام: 9:00 صباحا حتى 11 ليلاً";

                if (OrderDetails.Any(x => x.Warning != null))
                    return "يرجى مراجعة المواد";

                return null;
            }
        }

        public bool CanSubmit =>
            MinCart() <= Price && OrderDetails.All(x => x.Warning == null);

        private int MinCart() => 349;
        private bool IsDeliveryOpen()
        {
            var timeTurkey = TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time"));

            var start0 = new TimeSpan(10, 0, 0); //10:00
            var end0 = new TimeSpan(23, 0, 0);  //11:00

            //var start1 = new TimeSpan(10, 00, 0); //10:30
            //var end1 = new TimeSpan(24, 00, 0);  //12:00

            //var start2 = new TimeSpan(21, 0, 0); //9:00
            //var end2 = new TimeSpan(24, 00, 0);  //12:30

            var now = timeTurkey.TimeOfDay;

            return (now > start0 && now < end0) /*|| (now > start1 && now < end1) || (now > start2 && now < end2)*/;
            //return timeTurkey.Hour > 10 && timeTurkey.Hour <= 22;
        }
    }
    public class DeliveryLocationUpdate
    {
        [Range(-90, 90)]
        public decimal Lat { get; set; }

        [Range(-180, 180)]
        public decimal Lng { get; set; }

        public double? Heading { get; set; }
        public double? Speed { get; set; }
    }

    public class ShippingStopProgressDto
    {
        public int Index { get; set; }
        public string Title { get; set; }
        public bool IsDarkStore { get; set; }
        public bool IsCompleted { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public int StopType { get; set; }
    }

    public class OrderLiveTrackDto
    {
        public int OrderId { get; set; }
        public int OrderStatus { get; set; }
        public Guid? DriverId { get; set; }
        public string DriverName { get; set; }
        public string DriverPhoneNumber { get; set; }
        public decimal? DriverLat { get; set; }
        public decimal? DriverLng { get; set; }
        public double? Heading { get; set; }
        public double? Speed { get; set; }
        public DateTime? LocationUpdatedAt { get; set; }
        public bool IsLive { get; set; }
        public int EtaMinutes { get; set; }
        public int RemainingDistanceMeters { get; set; }
        public decimal DestinationLat { get; set; }
        public decimal DestinationLng { get; set; }
        public string DestinationAddress { get; set; }
        public int CurrentStopIndex { get; set; }
        public string CurrentStopTitle { get; set; }
        public bool CurrentStopIsDarkStore { get; set; }
        public string DeliveryOtp { get; set; }
        public List<ShippingStopProgressDto> Stops { get; set; } = new List<ShippingStopProgressDto>();
    }
    public class DeliveryOrderDto
    {
        public int Id { get; set; }
        public string User { get; set; }
        public Guid UserId { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public string Description { get; set; }
        public string Phonenumber { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Address { get; set; }

        public PaymentMethod PaymentMethod { get; set; }
        public OrderStatus OrderStatus { get; set; }
        public DeliveryOrderDetailDto[] OrderDetails { get; set; } = Array.Empty<DeliveryOrderDetailDto>();
        public string MapsUrl
        {
            get
            {
                if (Lat != 0 && Lng != 0)
                {
                    return $"https://www.google.com/maps/dir/?api=1&destination={Lat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{Lng.ToString(System.Globalization.CultureInfo.InvariantCulture)}";
                }
                if (!string.IsNullOrWhiteSpace(Address))
                {
                    return $"https://www.google.com/maps/dir/?api=1&destination={Uri.EscapeDataString(Address)}";
                }
                return null;
            }
        }
        public decimal Price => PaymentMethod == PaymentMethod.PayOnDelivery ? OrderDetails.Sum(x => x.Price) : 0;
        public DateTime CreatedDate { get; set; }
    }

    public class CartItem
    {
        public int ProductId { get; set; }
        public int MerchantId { get; set; }
        public int Quantity { get; set; }
        public decimal? SingleFinalPrice { get; set; }
    }

    public class CartSubmit
    {
        public CartItem[] CartItems { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [RegularExpression(@"^\+?[1-9]\d{1,14}$", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "InvalidNumber")]
        public string Phonenumber { get; set; }

        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Name { get; set; }
        public string Address { get; set; }
        public PaymentMethod PaymentMethod { get; set; }

        //public string User { get; set; }
        //public Guid UserId { get; set; }
        //public DateTime? PurchaseDate { get; set; }
        //public string Description { get; set; }
        //public OrderStatus OrderStatus { get; set; }
        //public OrderDetailDto[] OrderDetails { get; set; } = Array.Empty<OrderDetailDto>();
        //public decimal? Price => OrderDetails?.Sum(x => x.TotalPrice);
    }

    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum PaymentMethod
    {
        [Display(Name = "PayOnDelivery", ResourceType = typeof(_PaymentMethod))]
        PayOnDelivery = 0,

        [Display(Name = "CreditCardPayment", ResourceType = typeof(_PaymentMethod))]
        CreditCardPayment = 1,

        [Display(Name = "BankTransfer", ResourceType = typeof(_PaymentMethod))]
        BankTransfer = 2
    }
}
