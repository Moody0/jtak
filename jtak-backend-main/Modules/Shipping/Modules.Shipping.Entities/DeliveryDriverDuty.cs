using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;

namespace Modules.Shipping.Entities
{
    public class DeliveryDriverDuty : AuditableEntity
    {
        [Key]
        public Guid DriverId { get; set; }
        public bool IsOnline { get; set; }
        public DateTime? ShiftStartedAt { get; set; }
        public decimal Lat { get; set; }
        public decimal Lng { get; set; }
        public double? Heading { get; set; }
        public double? Speed { get; set; }
        public DateTime? LastLocationUpdatedAt { get; set; }
    }
}
