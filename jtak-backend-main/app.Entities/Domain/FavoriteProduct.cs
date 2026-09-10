using Solf.Base;
using System;

namespace App.Shared.Entities.Domain
{
    public class FavoriteProduct : AuditableEntity
    {
        public Guid UserId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductImage { get; set; }
    }

    public class FavoriteProductDto
    {
        public Guid UserId { get; set; }
        public int ProductId { get; set; }
        public string ProductTitle { get; set; }
        public string ProductImage { get; set; }
    }
}
