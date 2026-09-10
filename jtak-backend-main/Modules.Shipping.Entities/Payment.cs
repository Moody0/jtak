using Solf.Base;
using System;

namespace Modules.Accounting.Entities
{
    public class Payment : AuditableEntity
    {
        public int Id { get; set; }
        public Guid ToUserId { get; set; }
        public string ToUser { get; set; }
        public Guid ByUserId { get; set; }
        public string ByUser { get; set; }

        public decimal Amount { get; set; }
        public decimal NewBalance { get; set; }
        public DateTime? HandoverDate { get; set; }
    }
    public class PaymentDto
    {
        public int Id { get; set; }
        public Guid ToUserId { get; set; }
        public string ToUser { get; set; }
        public Guid ByUserId { get; set; }
        public string ByUser { get; set; }

        public decimal Amount { get; set; }
        public decimal NewBalance { get; set; }
        public DateTime? CreatedDate { get; set; }
        public DateTime? HandoverDate { get; set; }
    }
}
