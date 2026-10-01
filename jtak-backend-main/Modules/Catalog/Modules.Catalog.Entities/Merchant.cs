using System.Text.Json;
using System.Text.Json.Serialization;
using App.Shared.Entities.Enums;
using Solf.Base;
using Solf.Extensions;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Catalog.Entities
{
    public class Merchant : SoftDeleteEntity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [StringLength(128)]
        public string Title { get; set; }

        [StringLength(128)]
        public string ShortDescription { get; set; }

        public string Description { get; set; }
        [StringLength(128)]
        public string OwnerName { get; set; }
        //public string Facebook { get; set; }
        //public string Instagram { get; set; }
        //public string Twitter { get; set; }
        //public string Website { get; set; }
        public string IBAN1Title { get; set; }
        public string IBAN1 { get; set; }
        //public string IBAN2Title { get; set; }
        //public string IBAN2 { get; set; }
        //public string Paypal { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public int ShippingCoverageInMeters { get; set; }
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal Lat { get; set; } = 37.064258m;
        public decimal Lng { get; set; } = 37.378656m;
        public bool Active { get; set; } = true;
        public MerchantKind MerchantKind { get; set; } = MerchantKind.Restaurant;
        public string DeliveryTime { get; set; } = "20-30 دقيقة";
        // Delivery fees are configured per merchant from the admin dashboard.
        // Zero is the safe default until an administrator sets a value.
        public decimal DeliveryFee { get; set; } = 0m;
        public decimal MinOrderAmount { get; set; } = 150m;
        public string WorkingHours { get; set; } = "حتى 3 ص";
        public Currency DefaultCurrency { set; get; } = Currency.TRY;
        public string DefaultCurrencyString => DefaultCurrency.ToLocalizedName();

        [ForeignKey("Owner")]
        [JsonConverter(typeof(SafeGuidConverter))]
        public Guid OwnerId { get; set; }

        public string Photo { get; set; }
        public virtual ICollection<MerchantProduct> MerchantProducts { get; set; }
    }


    public class MerchantDto
    {
        public bool IsJtakMarket { get; set; }
        public int Id { get; set; }

        [Required]
        [StringLength(128)]
        public string Title { get; set; }

        [Required]
        [StringLength(128)]
        public string ShortDescription { get; set; }

        public string Description { get; set; }
        //public string Facebook { get; set; }
        //public string Instagram { get; set; }
        //public string Twitter { get; set; }
        //public string Website { get; set; }
        public string IBAN1Title { get; set; }
        public string IBAN1 { get; set; }
        //public string IBAN2Title { get; set; }
        //public string IBAN2 { get; set; }
        //public string Paypal { get; set; }
        public string Phone1 { get; set; }
        public string Phone2 { get; set; }
        public string Address { get; set; }
        public int ShippingCoverageInMeters { get; set; }
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal Lng { get; set; }
        public decimal Lat { get; set; }
        public bool Active { get; set; }
        public MerchantKind MerchantKind { get; set; }
        public string DeliveryTime { get; set; }
        public decimal DeliveryFee { get; set; }
        public decimal MinOrderAmount { get; set; }
        public string WorkingHours { get; set; }
        //public Currency DefaultCurrency { set; get; }
        //public string DefaultCurrencyString => DefaultCurrency.ToLocalizedName();

        [ForeignKey("Owner")]
        [JsonConverter(typeof(SafeGuidConverter))]
        public Guid OwnerId { get; set; }
        [StringLength(128)]
        public string OwnerName { get; set; }
        public string Owner { get => OwnerName; set => OwnerName = value; }

        public string Photo { get; set; }
        //public ProductCategoryDto[] ProductCategories { get; set; }
        //public ProductDto[] FeaturedProducts { get; set; }
    }

    
    public class SafeGuidConverter : JsonConverter<Guid>
    {
        public override Guid Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.String)
            {
                var str = reader.GetString();
                if (!string.IsNullOrWhiteSpace(str) && Guid.TryParse(str, out var guid))
                {
                    return guid;
                }
                return Guid.Empty;
            }

            if (reader.TokenType == JsonTokenType.Null)
            {
                return Guid.Empty;
            }

            return Guid.Empty;
        }

        public override void Write(Utf8JsonWriter writer, Guid value, JsonSerializerOptions options)
        {
            writer.WriteStringValue(value.ToString());
        }
    }

    public class MerchantSummaryDto
    {
        public int Total { get; set; }
        public int Active { get; set; }
        public int Grocery { get; set; }
        public int Restaurants { get; set; }
    }
}
