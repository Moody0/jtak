using System;

namespace Modules.Orders.Entities
{
    /// <summary>A customer's review of a merchant from a delivered order.</summary>
    public class MerchantReview
    {
        public int Id { get; set; }
        public int OrderId { get; set; }
        public int MerchantId { get; set; }
        public Guid ReviewerId { get; set; }
        public int Rate { get; set; }
        public string TextReview { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime UpdatedDate { get; set; }
    }
}
