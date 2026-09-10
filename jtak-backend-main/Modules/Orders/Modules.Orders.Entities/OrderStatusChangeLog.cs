using System;
using Solf.Base;

namespace Modules.Orders.Entities
{
    public class OrderStatusChangeLog : AuditableEntity
    {
        public Guid Id { get; set; }
        public int OrderId { get; set; }
        public Order Order { get; set; }
        public string OrdreDetails { get; set; }
        public Guid? DriverId { get; set; }
        public OrderDetailStatus OrderDetailStatus { get; set; }
    }
}