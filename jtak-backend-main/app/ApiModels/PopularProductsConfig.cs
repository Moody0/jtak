using System.Collections.Generic;

namespace App.ApiModels
{
    public class PopularProductItemConfig
    {
        public int ProductId { get; set; }
        public int Order { get; set; } = 0;
        public bool Active { get; set; } = true;
        public string CustomBadge { get; set; }
        public string CustomTitle { get; set; }
    }

    public class PopularSectionConfig
    {
        /// <summary>
        /// Mode: "Manual" (Strict admin list), "Hybrid" (Admin list first, then trending), "Auto" (Sales volume)
        /// </summary>
        public string Mode { get; set; } = "Hybrid";
        public string SectionTitle { get; set; } = "الأكثر طلباً";
        public string SectionTitleEn { get; set; } = "Most Popular";
        public int MaxItems { get; set; } = 15;
        public bool Enabled { get; set; } = true;
        public List<PopularProductItemConfig> Items { get; set; } = new List<PopularProductItemConfig>();
    }

    public class AdminPopularProductItemDto
    {
        public int ProductId { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Photos { get; set; }
        public string Unit { get; set; }
        public decimal Price { get; set; }
        public decimal FinalPrice { get; set; }
        public int CategoryId { get; set; }
        public string CategoryTitle { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string MerchantLogo { get; set; }
        public int Order { get; set; }
        public bool Active { get; set; }
        public bool ProductActive { get; set; }
        public string CustomBadge { get; set; }
        public string CustomTitle { get; set; }
        public int RealOrdersCount { get; set; }
    }

    public class AdminPopularSectionResponse
    {
        public string Mode { get; set; } = "Hybrid";
        public string SectionTitle { get; set; } = "الأكثر طلباً";
        public string SectionTitleEn { get; set; } = "Most Popular";
        public int MaxItems { get; set; } = 15;
        public bool Enabled { get; set; } = true;
        public List<AdminPopularProductItemDto> Items { get; set; } = new List<AdminPopularProductItemDto>();
    }

    public class SearchProductCandidateDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Unit { get; set; }
        public string Photos { get; set; }
        public decimal Price { get; set; }
        public int CategoryId { get; set; }
        public string CategoryTitle { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public bool Active { get; set; }
        public bool IsAlreadyInPopular { get; set; }
    }
}
