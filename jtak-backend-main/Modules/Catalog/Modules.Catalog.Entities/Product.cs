using Modules.Catalog.Entities.EAV;
using Solf.Base;
using Solf.Extensions;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Enums;
using System.ComponentModel.DataAnnotations.Schema;
using App.Shared.Entities.Domain;

namespace Modules.Catalog.Entities
{
    public class Product : SoftDeleteEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [StringLength(256)]
        public string Title { get; set; }

        [StringLength(256)]
        public string TitleEn { get; set; }

        [StringLength(64)]
        public string Barcode { get; set; }

        [StringLength(128)]
        public string Brand { get; set; }

        public string Description { get; set; }

        public string DescriptionEn { get; set; }

        public string Photos { get; set; }
        //public int TotalCount { get; set; }
        //public int SoldCount { get; set; }
        //public int AvailableCount => TotalCount - SoldCount;
        public string Unit { get; set; }
        public Currency Currency { get; set; }
        public bool Active { get; set; } = true;
        public DateTime? ExpiryDate { get; set; }
        public bool IsFeatured { get; set; } = true;
        public double Rate { get; set; }
        public int RateCount { get; set; }

        [UIHint("EnumDropDownList")]
        public int? ProductCategoryId { get; set; }
        public ProductCategory ProductCategory { get; set; }
        //public virtual ICollection<OrderDetail> OrderDetails { get; set; }
        //public virtual ICollection<ProductReview> ProductReviews { get; set; }
        public virtual ICollection<MerchantProduct> MerchantProducts { get; set; }
        public virtual ICollection<ProductTag> Tags { get; set; }
    }



    public class ProductDto
    {
        //[Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        //[Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        public string Title { get; set; }

        public string TitleEn { get; set; }

        public string Barcode { get; set; }

        public string Brand { get; set; }

        public string Description { get; set; }

        public string DescriptionEn { get; set; }

        public string Photos { get; set; }

        //[Range(0, 100000, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "OurOfRange")]
        //[Display(Name = "TotalCount", ResourceType = typeof(_Product))]
        public int TotalCount { get; set; }

        //[Display(Name = "SoldCount", ResourceType = typeof(_Product))]
        public int SoldCount { get; set; }
        public int AvailableCount => TotalCount - SoldCount;
        public string Unit { get; set; }
        public decimal Price { get; set; }
        public decimal FinalPrice { get; set; }
        public decimal? OriginalPrice { get; set; }
        public decimal Discount { get; set; }
        public decimal? PriceUsd { get; set; }
        public int? MerchantId { get; set; }
        public Currency Currency { get; set; }
        public string CurrencyString => Currency.ToLocalizedName();
        public bool Active { get; set; } = true;
        public DateTime? ExpiryDate { get; set; }
        public bool IsFeatured { get; set; } = true;
        public double Rate { get; set; }
        public int RateCount { get; set; }

        public ProductReviewDto MyReview { get; set; }
        public bool CanReview { get; set; } = false;

        //public int MerchantId { get; set; }
        //public string Merchant { get; set; }
        //public Guid MerchantOwnerId { get; set; }
        public decimal ShippingCost { get; set; }
        public decimal ShopMinOrder { get; set; }

        public int? ProductCategoryId { get; set; }
        public string ProductCategory { get; set; }

        public DateTime CreatedDate { get; set; }
        public TagDto[] Tags { get; set; }
        public DynamicFieldValueLiteDto[] DynamicFieldValues { get; set; }
    }


    public class ProductCategoryLiteDto
    {
        public string Category { get; set; }
        public ProductLiteDto[] Products { get; set; }
    }

    public class ProductLiteDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public int CategoryId { get; set; }
        public string Category { get; set; }
        public string Photos { get; set; }
        public string Unit { get; set; }
        public decimal Price { get; set; }
        public decimal FinalPrice { get; set; }
        //public Currency Currency { get; set; }
        //public double Rate { get; set; }
        //public int RateCount { get; set; }
        public int MerchantId { get; set; }
        public decimal? PriceUsd { get; set; }
        public decimal? OriginalPrice { get; set; }
        public decimal Discount { get; set; }
    }

    public class PopularProductDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public int CategoryId { get; set; }
        public string Category { get; set; }
        public string Photos { get; set; }
        public string Unit { get; set; }
        public decimal Price { get; set; }
        public decimal FinalPrice { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string MerchantLogo { get; set; }
        public int MerchantKind { get; set; }
        public string Eta { get; set; }
        public string Distance { get; set; }
        public int OrdersCount { get; set; }
    }

}
