using System;
using System.Collections.Generic;
using System.Linq;
using Solf.Base;

namespace Modules.Shipping.Entities
{
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
    }

    public class ShippingOrderDto
    {
        public int Id { get; set; }
        public int OrderId { get; set; }
        public Guid DriverId { get; set; }
        public int? MerchantId { get; set; }
        public Guid? CustomerId { get; set; }
        public DateTime? CompletedDate { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }

        public (decimal Lat, decimal Lng) Loc => (Lat, Lng);
    }
    //public class StopLocation
    //{
    //    public int? MerchantId { get; set; }
    //    public (decimal Lat, decimal Lng) Loc { get; set; }
    //}
    public class DeliveryStatus
    {
        public (decimal Lat, decimal Lng) Loc { get; set; } = (37.05637741088867m, 37.33407211303711m);
        public DateTime? LastLocationUpdatedAt { get; set; }
        // List of pending orders, starting from the oldest
        public List<ShippingOrderDto> PendingOrders { get; set; } = new List<ShippingOrderDto>();

        public ShippingOrderDto FreeOnStop => PendingOrders?.LastOrDefault() ??
            new ShippingOrderDto { MerchantId = 0, Lat = Loc.Lat, Lng = Loc.Lng };
    }
}
