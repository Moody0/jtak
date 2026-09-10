using Solf.Base;
using System;

namespace Modules.Accounting.Entities
{
    public class Balance : AuditableEntity
    {
        public Guid Id { get; set; }
        public string Name { get; set; }
        public decimal Amount { get; set; }
        public decimal PendingAmount { get; set; }
    }
    public class BalanceDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; }
        public decimal Amount { get; set; }
        public decimal PendingAmount { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
