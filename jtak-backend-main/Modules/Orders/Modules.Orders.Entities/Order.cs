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

        public virtual ICollection<OrderDetail> OrderDetails { get; set; }
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
        public decimal? DeliveryLat { get; set; }
        public decimal? DeliveryLng { get; set; }
        public DateTime? DeliveryLocationUpdatedAt { get; set; }

        [Display(Name = "PurchaseDate", ResourceType = typeof(_Order))]
        public DateTime? PurchaseDate { get; set; }

        [Display(Name = "Description", ResourceType = typeof(_Entities))]
        public string Description { get; set; }

        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string Phonenumber { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Address { get; set; }

        public PaymentMethod PaymentMethod { get; set; }

        [Display(Name = "OrderStatus", ResourceType = typeof(_Order))]
        public OrderStatus OrderStatus { get; set; }

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
                // TODO: Update this to use delivery service instead
                const string googleMapsBaseUrl = "https://www.google.com/maps/dir/";
                var nextMerchant = OrderDetails.FirstOrDefault(dd => dd.OrderDetailStatus != OrderDetailStatus.ShippingStarted);
                var nextPoint = nextMerchant != null ? (nextMerchant.Lat, nextMerchant.Lng) : (Lat, Lng);
                var locationList = new List<(decimal lat, decimal lng)>();

                locationList.AddRange(OrderDetails.Select(d => (d.Lat, d.Lng)));
                locationList.Add((Lat, Lng));

                return googleMapsBaseUrl +
                        string.Join("/", locationList.Select(d => $"{d.lat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{d.lng.ToString(System.Globalization.CultureInfo.InvariantCulture)}")) +
                        $"/@{nextPoint.Lat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{nextPoint.Lng.ToString(System.Globalization.CultureInfo.InvariantCulture)},15z";
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
