#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using Solf.Base;

namespace Modules.Shipping.Entities
{
    public enum ShippingStopType : byte
    {
        Pickup = 0,
        Dropoff = 1
    }

    public class ShippingOrder : AuditableEntity
    {
        public int Id { get; set; }
        public int Index { get; set; }
        public int OrderId { get; set; }
        public Guid DriverId { get; set; }
        public int? MerchantId { get; set; }
        public Guid? CustomerId { get; set; }
        public DateTime? CompletedDate { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }

        public ShippingStopType StopType { get; set; } = ShippingStopType.Pickup;
        public string? StopTitle { get; set; }
        public bool IsDarkStore { get; set; }
        public string? VerificationCode { get; set; }
        public string? Notes { get; set; }
    }

    public class ShippingOrderDto
    {
        public int Id { get; set; }
        public int Index { get; set; }
        public int OrderId { get; set; }
        public Guid DriverId { get; set; }
        public int? MerchantId { get; set; }
        public Guid? CustomerId { get; set; }
        public DateTime? CompletedDate { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }

        public ShippingStopType StopType { get; set; } = ShippingStopType.Pickup;
        public string? StopTitle { get; set; }
        public bool IsDarkStore { get; set; }
        public string? VerificationCode { get; set; }
        public string? Notes { get; set; }

        public (decimal Lat, decimal Lng) Loc => (Lat, Lng);
    }
    //public class StopLocation
    //{
    //    public int? MerchantId { get; set; }
    //    public (decimal Lat, decimal Lng) Loc { get; set; }
    //}
    public class DeliveryStatus
    {
        public bool IsOnline { get; set; } = true;
        public DateTime? ShiftStartedAt { get; set; }
        public (decimal Lat, decimal Lng) Loc { get; set; } = (37.05637741088867m, 37.33407211303711m);
        public double? Heading { get; set; }
        public double? Speed { get; set; }
        public DateTime? LastLocationUpdatedAt { get; set; }
        // List of pending orders, starting from the oldest
        public List<ShippingOrderDto> PendingOrders { get; set; } = new List<ShippingOrderDto>();

        public ShippingOrderDto FreeOnStop => PendingOrders?.LastOrDefault() ??
            new ShippingOrderDto { MerchantId = 0, Lat = Loc.Lat, Lng = Loc.Lng };
    }
}
