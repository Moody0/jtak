using System.Collections.Generic;

namespace App.ApiModels
{
    public class MarketBestSellingItemConfig
    {
        public int ProductId { get; set; }
        public int Order { get; set; } = 0;
        public bool Active { get; set; } = true;
        public string CustomBadge { get; set; } = "الأكثر مبيعًا";
        public string CustomTitle { get; set; }
    }

    public class MarketBestSellingSectionConfig
    {
        /// <summary>
        /// Mode: "Manual" (Strict admin list), "Hybrid" (Admin list first, then top sold), "Auto" (Sales volume)
        /// </summary>
        public string Mode { get; set; } = "Hybrid";
        public string SectionTitle { get; set; } = "الأكثر مبيعًا";
        public string SectionTitleEn { get; set; } = "Best Selling";
        public int MaxItems { get; set; } = 10;
        public bool Enabled { get; set; } = true;
        public List<MarketBestSellingItemConfig> Items { get; set; } = new List<MarketBestSellingItemConfig>();
    }

    public class AdminMarketBestSellingSectionResponse
    {
        public string Mode { get; set; } = "Hybrid";
        public string SectionTitle { get; set; } = "الأكثر مبيعًا";
        public string SectionTitleEn { get; set; } = "Best Selling";
        public int MaxItems { get; set; } = 10;
        public bool Enabled { get; set; } = true;
        public List<AdminPopularProductItemDto> Items { get; set; } = new List<AdminPopularProductItemDto>();
    }
}
