using Solf.Base;
using System;

namespace App.Shared.Entities.Domain
{
    public class ProductReview : AuditableEntity
    {
        public int Id { get; set; }
        public Guid ReviewerId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductImage { get; set; }
        public int Rate { get; set; }
        public string TextReview { get; set; }
        public string ImageReview { get; set; }
        public bool IsApproved { get; set; } = true;
    }

    public class ProductReviewDto
    {
        public int Id { get; set; }
        public Guid ReviewerId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductImage { get; set; }
        public int Rate { get; set; }
        public string TextReview { get; set; }
        public string ImageReview { get; set; }
        public bool IsApproved { get; set; } = true;
    }

    public class CreateOrderReview
    {
        public int OrderId { get; set; }
        public int Rate { get; set; }
        public string TextReview { get; set; }
    }
}
