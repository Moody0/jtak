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
        /// Merchant asking price for selling products (including contracted profit percent)
        /// </summary>
        public decimal MerchantPrice { get; set; }

        /// <summary>
        /// Additional Percent of profite for the app administration
        /// </summary>
        public decimal AdditionalProfitPercent { get; set; }

        /// <summary>
        /// Discount amount calculated as merketing intencive
        /// </summary>
        public decimal Discount { get; set; }

        /// <summary>
        /// Original price before discount in USD
        /// </summary>
        public decimal? OriginalPrice { get; set; }
    }
    public class MerchantProductDto
    {
        public int MerchantId { get; set; }
        public int ProductId { get; set; }
        public string Product { get; set; }
        public string ProductPhotos { get; set; }
        public string ProductCat1 { get; set; }
        public string ProductCat2 { get; set; }
        public string ProductDescription { get; set; }
        public string ProductUnit { get; set; }
        public int? ProductCategoryId { get; set; }
        public bool ProductActive { get; set; }
        public bool ProductIsFeatured { get; set; }
        public int? CategoryParentId { get; set; }
        public bool CategoryActive { get; set; }
        public string CategoryIcon { get; set; }

        /// <summary>
        /// Contracted profit percent
        /// </summary>
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal ProfitOutOfMerchantPrice => (MerchantPrice * ProfitOutOfMerchantPricePercent / 100);
        public decimal MerchantProfit => MerchantPrice - ProfitOutOfMerchantPrice;

        /// <summary>
        /// Normal asking price specified by the merchant
        /// </summary>
        public decimal MerchantPrice { get; set; }

        /// <summary>
        /// Original price before discount in USD
        /// </summary>
        public decimal? OriginalPrice { get; set; }

        /// <summary>
        /// Additional Profit Percent specified by the admins, to be added to merchant prices
        /// </summary>
        public decimal AdditionalProfitPercent { get; set; }
        public decimal AdditionalProfit => (MerchantPrice * AdditionalProfitPercent / 100);

        /// <summary>
        /// Fake discount, added to the sale price not subtracted
        /// </summary>
        public decimal Discount { get; set; }

        /// <summary>
        /// Selling Price Before discount
        /// </summary>
        public decimal Price => Discount + MerchantPrice + AdditionalProfit;

        /// <summary>
        /// Final Selling Price After discount
        /// </summary>
        public decimal FinalPrice => MerchantPrice + AdditionalProfit;
    }
    public class MerchantProductAssignDto
    {
        public int ProductId { get; set; }
        public decimal ProfitOutOfMerchantPricePercent { get; set; }
        public decimal MerchantPrice { get; set; }
        public decimal AdditionalProfitPercent { get; set; }
        public decimal Discount { get; set; }
        public decimal? OriginalPrice { get; set; }
    }
    public class MerchantProductPriceDto
    {
        public int ProductId { get; set; }
        public decimal MerchantPrice { get; set; }
    }
}
