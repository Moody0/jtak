using App.Shared.Entities.Enums;
using Solf.Base;
using Solf.Extensions;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Orders.Entities
{
    public class Merchant : SoftDeleteEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [StringLength(128)]
        public string Title { get; set; }

        [Required]
        [StringLength(128)]
        public string ShortDescription { get; set; }

        public string Description { get; set; }
        public string Facebook { get; set; }
        public string Instagram { get; set; }
        public string Twitter { get; set; }
        public string Website { get; set; }
        public string IBAN1Title { get; set; }
        public string IBAN1 { get; set; }
        public string IBAN2Title { get; set; }
        public string IBAN2 { get; set; }
        public string Paypal { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public decimal ShippingCost { get; set; }
        public decimal MinOrder { get; set; }
        public bool Active { get; set; } = true;
        public Currency DefaultCurrency { set; get; }
        public string DefaultCurrencyString => DefaultCurrency.ToLocalizedName();
        //public Point Location { get; set; }

        [ForeignKey("Owner")]
        public Guid OwnerId { get; set; }
        //public virtual AppUser Owner { get; set; }

        public string Photo { get; set; }
        //public virtual ICollection<ProductCategory> ProductCategories { get; set; }
        //public virtual ICollection<Product> Products { get; set; }
    }


    public class MerchantDto
    {
        public int Id { get; set; }

        [Required]
        [StringLength(128)]
        public string Title { get; set; }

        [Required]
        [StringLength(128)]
        public string ShortDescription { get; set; }

        public string Description { get; set; }
        public string Facebook { get; set; }
        public string Instagram { get; set; }
        public string Twitter { get; set; }
        public string Website { get; set; }
        public string IBAN1Title { get; set; }
        public string IBAN1 { get; set; }
        public string IBAN2Title { get; set; }
        public string IBAN2 { get; set; }
        public string Paypal { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public decimal ShippingCost { get; set; }
        public decimal MinOrder { get; set; }
        public bool Active { get; set; }
        public Currency DefaultCurrency { set; get; }
        public string DefaultCurrencyString => DefaultCurrency.ToLocalizedName();
        public double? Lat { get; set; }
        public double? Lng { get; set; }

        [ForeignKey("Owner")]
        public Guid OwnerId { get; set; }
        public string Owner { get; set; }

        public string Photo { get; set; }
        //public ProductCategoryDto[] ProductCategories { get; set; }
        //public ProductDto[] FeaturedProducts { get; set; }
    }
}
