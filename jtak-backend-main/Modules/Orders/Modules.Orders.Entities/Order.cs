using App.Shared.Entities.Resources;
using App.Shared.Entities.Enums;
using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text.Json.Serialization;

namespace Modules.Orders.Entities
{
    public class Order : SoftDeleteEntity
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

        /// <summary>Server-owned courier matching window started after merchant acceptance.</summary>
        public DateTime? CourierMatchingStartedAtUtc { get; set; }
        public DateTime? CourierMatchingDeadlineAtUtc { get; set; }
        public DateTime? CourierMatchingCompletedAtUtc { get; set; }
        public int CourierMatchingRound { get; set; }

        public string Description { get; set; }

        public string PaymentDescription { get; set; }
        public string Notes { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Address { get; set; }
        public string Phonenumber { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        [StringLength(128)]
        public string IdempotencyKey { get; set; }
        /// <summary>
        /// The delivery fee quoted by the server at checkout. It is persisted so
        /// later order views and accounting use the same amount configured by
        /// the admin, even if the merchant changes their fee afterwards.
        /// </summary>
        public decimal DeliveryFee { get; set; }
        /// <summary>
        /// Immutable versioned checkout quote.  This is the server-authoritative
        /// amount contract returned for retries and retained for audit/reconciliation.
        /// </summary>
        public int MoneySnapshotVersion { get; set; } = 1;
        public string MoneySnapshotJson { get; set; }
        /// <summary>
        /// Courier compensation agreed at checkout. It is intentionally distinct
        /// from the customer delivery fee and from platform delivery revenue.
        /// </summary>
        public decimal CaptainEarning { get; set; }

        /// <summary>
        /// Delivery distance calculated in kilometers between merchant(s) and customer.
        /// </summary>
        public decimal? DistanceInKm { get; set; }

        /// <summary>
        /// Rate per kilometer charged to customer at checkout.
        /// </summary>
        public decimal? CustomerRatePerKm { get; set; }

        /// <summary>
        /// Original delivery fee before promotions or discounts.
        /// </summary>
        public decimal? OriginalDeliveryFee { get; set; }

        /// <summary>
        /// Courier compensation calculation model locked upon order claim/assignment.
        /// </summary>
        public CaptainCompensationType? CaptainCompensationType { get; set; }

        /// <summary>
        /// Courier rate (price per km or percentage %) locked upon order claim/assignment.
        /// </summary>
        public decimal? CaptainRate { get; set; }
        //public Point Location { get; set; }
        public OrderStatus OrderStatus { get; set; }
        [ConcurrencyCheck]
        public int RowVersion { get; set; }

        public bool IsSettled { get; set; } = false;
        public DateTime? SettledAt { get; set; }
        [StringLength(64)]
        public string SettlementBatchId { get; set; }

        [StringLength(16)]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string DeliveryOtp { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public string ProofOfDeliverySignature { get; set; }
        public string ProofOfDeliveryPhotoUrl { get; set; }
        public string DeliveryNotes { get; set; }

        public OrderAccountingStatus AccountingStatus { get; set; } = OrderAccountingStatus.NotApplicable;
        public DateTime? AccountingPostedAt { get; set; }
        public string AccountingLastError { get; set; }
        public int AccountingRetryCount { get; set; }

        public int DeliveryOtpFailedAttempts { get; set; }
        public DateTime? DeliveryOtpExpiresAt { get; set; }
        public Guid? ProofPhotoUploadedBy { get; set; }
        public DateTime? ProofPhotoUploadedAt { get; set; }
        public decimal? ActualCashCollected { get; set; }

        [StringLength(500)]
        public string DeleteReason { get; set; }

        public virtual ICollection<OrderDetail> OrderDetails { get; set; }
    }

    public enum OrderAccountingStatus
    {
        NotApplicable = 0,
        PendingAccounting = 1,
        Posted = 2,
        Failed = 3
    }

    public enum OrderDispatchOfferStatus : byte
    {
        Offered = 0,
        Declined = 1,
        TimedOut = 2,
        Accepted = 3,
        Superseded = 4
    }

    /// <summary>Durable record of a courier offer so matching survives app/server restarts.</summary>
    public class OrderDispatchOffer
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }
        public int OrderId { get; set; }
        public Guid DriverId { get; set; }
        public int MatchingRound { get; set; }
        public int WaveNumber { get; set; }
        public DateTime OfferedAtUtc { get; set; }
        public DateTime ExpiresAtUtc { get; set; }
        public DateTime? RespondedAtUtc { get; set; }
        public OrderDispatchOfferStatus Status { get; set; }
    }

    public class ArchiveOrderRequest
    {
        [Required(ErrorMessage = "سبب الأرشفة إلزامي.")]
        public string Reason { get; set; }
    }

    public class DeliverOrderRequest
    {
        public int OrderId { get; set; }
        public string Otp { get; set; }
        public string Signature { get; set; }
        public string PhotoUrl { get; set; }
        public string Notes { get; set; }
        public decimal? CollectedCashAmount { get; set; }
        public bool ConfirmDifferentCashAmount { get; set; }
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
        public DateTime? CourierMatchingStartedAtUtc { get; set; }
        public DateTime? CourierMatchingDeadlineAtUtc { get; set; }
        public DateTime? CourierMatchingCompletedAtUtc { get; set; }
        public int CourierMatchingRound { get; set; }
        public bool IsCourierMatchingStarted => CourierMatchingStartedAtUtc.HasValue;
        public bool IsAwaitingCourierAssignment =>
            CourierMatchingStartedAtUtc.HasValue &&
            !CourierMatchingCompletedAtUtc.HasValue &&
            (!DeliveryId.HasValue || DeliveryId.Value == Guid.Empty);
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
        public decimal DeliveryFee { get; set; }
        public int MoneySnapshotVersion { get; set; }
        public decimal CaptainEarning { get; set; }
        public decimal? DistanceInKm { get; set; }
        public decimal? CustomerRatePerKm { get; set; }
        public decimal? OriginalDeliveryFee { get; set; }
        public CaptainCompensationType? CaptainCompensationType { get; set; }
        public decimal? CaptainRate { get; set; }
        [JsonIgnore]
        public string MoneySnapshotJson { get; set; }

        [Display(Name = "OrderStatus", ResourceType = typeof(_Order))]
        public OrderStatus OrderStatus { get; set; }

        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
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
        public string IdempotencyKey { get; set; }
        public OrderAccountingStatus AccountingStatus { get; set; }
        public decimal? ActualCashCollected { get; set; }
        public bool IsSettled { get; set; }
        public DateTime? SettledAt { get; set; }
        public string SettlementBatchId { get; set; }

        public bool IsDeliveryAssigned => DeliveryId.HasValue && DeliveryId.Value != Guid.Empty;
        public bool IsDeliveryAccepted => IsDeliveryAssigned && OrderDetails != null && OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted || d.OrderDetailStatus == OrderDetailStatus.Delivered);

        [Display(Name = "OrderDetails", ResourceType = typeof(_Order))]
        public OrderDetailDto[] OrderDetails { get; set; } = Array.Empty<OrderDetailDto>();

        public CanonicalOrderMoneyDto Money { get; set; }

        public List<OrderDto> SiblingOrders { get; set; }
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public int? MerchantKind { get; set; }
        public int[] RelatedOrderIds => SiblingOrders?.Select(x => x.Id).ToArray();

        public AggregateOrderStatus AggregateStatus => OrderAggregateStatusHelper.Calculate(OrderStatus, OrderDetails?.Select(d => d.OrderDetailStatus), DeliveredAt);
        public string AggregateStatusKey => OrderAggregateStatusHelper.ToKey(AggregateStatus);
        public string AggregateStatusArabic => OrderAggregateStatusHelper.ToArabic(AggregateStatus);
        public string AggregateStatusEnglish => OrderAggregateStatusHelper.ToEnglish(AggregateStatus);

        public decimal OriginalProductSubtotal => OrderDetails?.Sum(x => x.Quantity * (x.SingleFinalPrice > 0 ? x.SingleFinalPrice : x.SinglePrice)) ?? 0m;
        public decimal OriginalGrandTotal => OriginalProductSubtotal + DeliveryFee;
        public decimal AdjustedProductSubtotal => Price ?? 0m;
        public decimal AdjustedGrandTotal => GrandTotal;
        public decimal RejectedItemsTotal => Math.Max(0m, OriginalProductSubtotal - AdjustedProductSubtotal);
        public int AcceptedItemsCount => OrderDetails?.Count(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected && x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled) ?? 0;
        public int RejectedItemsCount => OrderDetails?.Count(x => x.OrderDetailStatus == OrderDetailStatus.MerchantRejected || x.OrderDetailStatus == OrderDetailStatus.CustomerCanceled || x.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled) ?? 0;
        public bool HasPartialFulfillment => RejectedItemsCount > 0 && AcceptedItemsCount > 0;

        [Display(Name = "Price", ResourceType = typeof(_Order))]
        public decimal? Price => Money?.ProductSubtotal ?? OrderDetails?.Where(x=> x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                                         x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                                         x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                                                         x.OrderDetailStatus != OrderDetailStatus.CustomerPending)
                                              .Sum(x => x.TotalPrice);

        public decimal GrandTotal => Money?.GrandTotal ?? ((Price ?? 0m) + DeliveryFee);

        public decimal CashToCollect => Money?.CashToCollect ?? (PaymentMethod == PaymentMethod.PayOnDelivery ? GrandTotal : 0m);

        [Display(Name = "CreatedDate", ResourceType = typeof(_Entities))]
        public DateTime CreatedDate { get; set; }

        public string DeleteReason { get; set; }
        public string DeletedBy { get; set; }
        public DateTime? DeletionDate { get; set; }
        public bool IsArchived => DeletionDate.HasValue;

        public static bool IsOperatingDeliveryHours(DateTime? utcNow = null)
            => IsOperatingDeliveryHours(utcNow, null);

        public static bool IsOperatingDeliveryHours(DateTime? utcNow, string workingHours)
        {
            if (string.Equals(workingHours?.Trim(), "24 ساعة", StringComparison.OrdinalIgnoreCase))
                return true;

            var nowUtc = utcNow ?? DateTime.UtcNow;
            TimeZoneInfo tz;
            try
            {
                tz = TimeZoneInfo.FindSystemTimeZoneById("Syria Standard Time");
            }
            catch
            {
                try
                {
                    tz = TimeZoneInfo.FindSystemTimeZoneById("Turkey Standard Time");
                }
                catch
                {
                    try
                    {
                        tz = TimeZoneInfo.FindSystemTimeZoneById("Asia/Damascus");
                    }
                    catch
                    {
                        tz = TimeZoneInfo.CreateCustomTimeZone("JTAK_TZ", TimeSpan.FromHours(3), "JTAK Local Time", "JTAK Local Time");
                    }
                }
            }

            var localTime = TimeZoneInfo.ConvertTimeFromUtc(nowUtc, tz);
            var nowTime = localTime.TimeOfDay;
            var start = new TimeSpan(9, 0, 0); // 09:00 AM
            var end = new TimeSpan(23, 0, 0);   // Legacy fallback: 11:00 PM

            // Dashboard presets store the daily closing time as e.g. "حتى 2 ص".
            // Those early-morning closing times belong to the following day.
            var normalizedHours = workingHours?.Trim();
            if (!string.IsNullOrWhiteSpace(normalizedHours) && normalizedHours.StartsWith("حتى ", StringComparison.Ordinal))
            {
                var closingHourText = normalizedHours.Substring("حتى ".Length).Split(' ')[0];
                if (int.TryParse(closingHourText, out var closingHour) && closingHour >= 0 && closingHour <= 12)
                {
                    var closesAfterMidnight = normalizedHours.EndsWith(" ص", StringComparison.Ordinal) && closingHour <= 3;
                    var hour24 = closingHour == 12 && normalizedHours.EndsWith(" ص", StringComparison.Ordinal)
                        ? 0
                        : closingHour;
                    end = TimeSpan.FromHours(hour24);

                    if (closesAfterMidnight || (hour24 == 0 && closingHour == 12))
                        return nowTime >= start || nowTime < end;
                }
            }

            return nowTime >= start && nowTime < end;
        }

        public string Warning
        {
            get
            {
                if (OrderDetails != null && OrderDetails.Any(x => !string.IsNullOrEmpty(x.Warning)))
                    return "يرجى مراجعة المواد";

                return null;
            }
        }

        public bool CanSubmit =>
            (Price ?? 0m) > 0 && (OrderDetails == null || OrderDetails.Length == 0 || OrderDetails.All(x => string.IsNullOrEmpty(x.Warning)));
    }
    public class DeliveryLocationUpdate
    {
        [Range(-90, 90)]
        public decimal Lat { get; set; }

        [Range(-180, 180)]
        public decimal Lng { get; set; }

        public double? Heading { get; set; }
        public double? Speed { get; set; }
        public double? Accuracy { get; set; }
        public DateTime? CapturedAtUtc { get; set; }
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
        public bool EtaIsEstimate { get; set; } = true;
        public int RemainingDistanceMeters { get; set; }
        public decimal DestinationLat { get; set; }
        public decimal DestinationLng { get; set; }
        public string DestinationAddress { get; set; }
        public int CurrentStopIndex { get; set; }
        public string CurrentStopTitle { get; set; }
        public bool CurrentStopIsDarkStore { get; set; }
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
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
        public decimal DeliveryFee { get; set; }
        public int MoneySnapshotVersion { get; set; }
        public decimal CaptainEarning { get; set; }
        public decimal? DistanceInKm => Money?.DistanceInKm;
        public decimal? CustomerRatePerKm => Money?.CustomerRatePerKm;
        public decimal? OriginalDeliveryFee => Money?.OriginalDeliveryFee;
        public CaptainCompensationType? CaptainCompensationType => Money?.CaptainCompensationType;
        public decimal? CaptainRate => Money?.CaptainRate;
        public DateTime? OfferExpiresAtUtc { get; set; }
        public DateTime? CourierMatchingDeadlineAtUtc { get; set; }
        public OrderStatus OrderStatus { get; set; }
        public DeliveryOrderDetailDto[] OrderDetails { get; set; } = Array.Empty<DeliveryOrderDetailDto>();
        // True only when this courier previously declined this assignment.
        // The order may already be assigned to another courier, so this is
        // separate from DeliveryId and is used only for the courier history.
        public bool WasDeclinedByCurrentDriver { get; set; }
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
        public CanonicalOrderMoneyDto Money { get; set; }
        public DateTime? DeliveredAt { get; set; }
        private System.Collections.Generic.IEnumerable<OrderDetailDto> AllItems => OrderDetails?.SelectMany(m => m.OrderDetails ?? System.Array.Empty<OrderDetailDto>()) ?? System.Array.Empty<OrderDetailDto>();
        public AggregateOrderStatus AggregateStatus => OrderAggregateStatusHelper.Calculate(OrderStatus, AllItems.Select(d => d.OrderDetailStatus), DeliveredAt);
        public string AggregateStatusKey => OrderAggregateStatusHelper.ToKey(AggregateStatus);
        public string AggregateStatusArabic => OrderAggregateStatusHelper.ToArabic(AggregateStatus);
        public string AggregateStatusEnglish => OrderAggregateStatusHelper.ToEnglish(AggregateStatus);

        public decimal OriginalProductSubtotal => AllItems.Sum(x => x.Quantity * (x.SingleFinalPrice > 0 ? x.SingleFinalPrice : x.SinglePrice));
        public decimal OriginalGrandTotal => OriginalProductSubtotal + DeliveryFee;
        public decimal AdjustedProductSubtotal => Price;
        public decimal AdjustedGrandTotal => GrandTotal;
        public decimal RejectedItemsTotal => System.Math.Max(0m, OriginalProductSubtotal - AdjustedProductSubtotal);
        public int AcceptedItemsCount => AllItems.Count(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected && x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled && x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled);
        public int RejectedItemsCount => AllItems.Count(x => x.OrderDetailStatus == OrderDetailStatus.MerchantRejected || x.OrderDetailStatus == OrderDetailStatus.CustomerCanceled || x.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled);
        public bool HasPartialFulfillment => RejectedItemsCount > 0 && AcceptedItemsCount > 0;

        public decimal ProductSubtotal => Money?.ProductSubtotal ?? OrderDetails.Sum(x => x.Price);
        public decimal Price => Money?.ProductSubtotal ?? OrderDetails.Sum(x => x.Price);
        public decimal GrandTotal => Money?.GrandTotal ?? (Price + DeliveryFee);
        public decimal CashToCollect => Money?.CashToCollect ?? (PaymentMethod == PaymentMethod.PayOnDelivery ? GrandTotal : 0m);
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
        public CustomerDeviceLocation DeviceLocation { get; set; }
        public CartItem[] CartItems { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [RegularExpression(@"^\+?[1-9]\d{1,14}$", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "InvalidNumber")]
        public string Phonenumber { get; set; }

        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public string Name { get; set; }
        public string Address { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        [StringLength(128)]
        public string IdempotencyKey { get; set; }

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
