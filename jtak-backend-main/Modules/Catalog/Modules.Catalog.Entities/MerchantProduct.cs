using System;
using Solf.Base;

namespace Modules.Catalog.Entities
{
    public class MerchantProduct : AuditableEntity
    {
        public int MerchantId { get; set; }
        public Merchant Merchant { get; set; }
        public int ProductId { get; set; }
        public Product Product { get; set; }
        /// <summary>
        /// Contracted profit percent
        /// </summary>
        public decimal ProfitOutOfMerchantPricePercent { get; set; }

        /// <summary>
        /// Merchant's quoted base price before the platform markup.
        /// </summary>
        public decimal MerchantPrice { get; set; }

        /// <summary>
        /// Retained for compatibility with existing databases. Product-level
        /// additional profit is retired and this value is no longer read or written.
        /// </summary>
        public decimal AdditionalProfitPercent { get; set; }

        /// <summary>
        /// Discount amount calculated as merketing intencive
        /// </summary>
        public decimal Discount { get; set; }

        /// <summary>Requested customer discount, funded only from platform markup.</summary>
        public decimal? DiscountPercent { get; set; }

        /// <summary>
        /// Original price before discount in USD
        /// </summary>
        public decimal? OriginalPrice { get; set; }

        /// <summary>
        /// Base price in USD for merchants that quote in dollars. When this is
        /// set, <see cref="MerchantPrice"/> is a derived local-currency value
        /// recalculated from this figure every time the administrator changes
        /// the exchange rate. Merchants that price directly in the local
        /// currency leave it null and are never repriced.
        /// </summary>
        public decimal? PriceUsd { get; set; }

        /// <summary>
        /// Maximum quantity of this menu item a customer may order in one order.
        /// Used by restaurants; null uses the platform default.
        /// </summary>
        public int? MaxOrderQuantity { get; set; }
    }
    public class MerchantProductDto
    {
        public int MerchantId { get; set; }
        public int MerchantKind { get; set; }
        public int ProductId { get; set; }
        public string Product { get; set; }
        public string ProductBarcode { get; set; }
        public string ProductBrand { get; set; }
        public string ProductPhotos { get; set; }
        public string ProductCat1 { get; set; }
        public string ProductCat2 { get; set; }
        public string ProductDescription { get; set; }
        public string ProductUnit { get; set; }
        public int? ProductCategoryId { get; set; }
        public bool ProductActive { get; set; }
        public bool ProductIsFeatured { get; set; }
        public bool HasRestaurantAssignment { get; set; }
        public bool HasJtakMarketAssignment { get; set; }
        public int? CategoryParentId { get; set; }
        public bool CategoryActive { get; set; }
        public string CategoryIcon { get; set; }

        /// <summary>
        /// Contracted profit percent
        /// </summary>
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal ProfitOutOfMerchantPrice => DiscountPercent.HasValue
            ? FinalPrice - MerchantProfit
            : Math.Round(MerchantPrice * ProfitOutOfMerchantPricePercent / 100m, 0, MidpointRounding.AwayFromZero);
        public decimal MerchantProfit => DiscountPercent.HasValue ? Quote.MerchantPrice : MerchantPrice;

        /// <summary>
        /// Normal asking price specified by the merchant
        /// </summary>
        public decimal MerchantPrice { get; set; }

        /// <summary>
        /// Original price before discount in USD
        /// </summary>
        public decimal? OriginalPrice { get; set; }

        /// <summary>
        /// Base price in USD when the merchant quotes in dollars, otherwise null.
        /// </summary>
        public decimal? PriceUsd { get; set; }

        /// <summary>
        /// Savings amount used to calculate the compare-at price. The merchant
        /// price and additional profit remain the amount charged after discount.
        /// </summary>
        private decimal _legacyDiscount;
        public decimal Discount { get => DiscountPercent.HasValue ? Quote.Discount : _legacyDiscount; set => _legacyDiscount = value; }
        public decimal? DiscountPercent { get; set; }
        [System.Text.Json.Serialization.JsonIgnore]
        public decimal UsdExchangeRate { get; set; }

        private (decimal MerchantPrice, decimal Price, decimal FinalPrice, decimal Discount) Quote =>
            MerchantProductPricing.Calculate(PriceUsd > 0m && UsdExchangeRate > 0m
                ? PriceUsd.Value * UsdExchangeRate : MerchantPrice,
                ProfitOutOfMerchantPricePercent, DiscountPercent ?? 0m);

        public void NormalizePricing(decimal usdRate)
        {
            // Recover the supplier quote from older discounted USD rows without
            // modifying historical orders or unrelated compare-at promotions.
            if (!DiscountPercent.HasValue && ProfitOutOfMerchantPricePercent > 0m &&
                _legacyDiscount > 0m && OriginalPrice > PriceUsd && PriceUsd > 0m)
            {
                DiscountPercent = Math.Clamp(Math.Round((1m - PriceUsd.Value / OriginalPrice.Value) * 100m, 2), 0m, 99.99m);
                PriceUsd = OriginalPrice;
            }
            UsdExchangeRate = usdRate;
            if (PriceUsd > 0m && usdRate > 0m)
                MerchantPrice = Math.Round(PriceUsd.Value * usdRate, 0, MidpointRounding.AwayFromZero);
        }

        public static MerchantProductDto FromStored(MerchantProduct row, decimal usdRate)
        {
            var quote = new MerchantProductDto
            {
                MerchantId = row.MerchantId, ProductId = row.ProductId,
                MerchantPrice = row.MerchantPrice, PriceUsd = row.PriceUsd,
                OriginalPrice = row.OriginalPrice, Discount = row.Discount,
                DiscountPercent = row.DiscountPercent,
                ProfitOutOfMerchantPricePercent = row.ProfitOutOfMerchantPricePercent,
                MaxOrderQuantity = row.MaxOrderQuantity
            };
            quote.NormalizePricing(usdRate);
            return quote;
        }

        /// <summary>Restaurant per-order quantity limit; null uses the platform default.</summary>
        public int? MaxOrderQuantity { get; set; }

        /// <summary>
        /// Compare-at price before discount
        /// </summary>
        public decimal Price => DiscountPercent.HasValue ? Quote.Price : Discount + FinalPrice;

        /// <summary>
        /// Selling price charged after discount
        /// </summary>
        public decimal FinalPrice => DiscountPercent.HasValue ? Quote.FinalPrice : MerchantPrice + ProfitOutOfMerchantPrice;
    }
    public class MerchantProductAssignDto
    {
        public int ProductId { get; set; }
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal MerchantPrice { get; set; }
        public decimal Discount { get; set; }
        public decimal? DiscountPercent { get; set; }
        public decimal? OriginalPrice { get; set; }
        public decimal? PriceUsd { get; set; }
        public int? MaxOrderQuantity { get; set; }
    }
    public class MerchantProductPriceDto
    {
        public int ProductId { get; set; }
        public decimal MerchantPrice { get; set; }
        public int? MaxOrderQuantity { get; set; }
    }
}
