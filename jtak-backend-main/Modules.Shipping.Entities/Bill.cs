using Solf.Base;
using System;

namespace Modules.Accounting.Entities
{
    // People Asking the Company this amount of money
    public class Bill : AuditableEntity
    {
        public int Id { get; set; }
        public int MerchantId { get; set; }
        public decimal MerchantAmount { get; set; }
        public decimal TotalAmount { get; set; }
        public decimal JTakAmount { get; set; }
        public decimal JTakAdditionalAmount { get; set; }
        public int PaymentMethod { get; set; }
        public DateTime DueDate { get; set; }
        //// TODO: remove redundunt property (DueDate < DateTime.UtcNow) is enough
        public bool IsAddedToDues { get; set; } = false;
        public int OrderId { get; set; }
    }
    public class BillDto
    {
        public int Id { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public decimal MerchantAmount { get; set; }
        public decimal TotalAmount { get; set; }
        public decimal JTakAmount { get; set; }
        public decimal JTakAdditionalAmount { get; set; }
        public int PaymentMethod { get; set; }
        public int OrderId { get; set; }
        public DateTime DueDate { get; set; }
        public bool IsAddedToDues { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
