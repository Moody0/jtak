using Modules.Catalog.Entities;

namespace App.ApiModels
{
    public class SettingsVm
    {
        public string HomeSeoTitle { get; set; }
        public string HomeSeoDescription { get; set; }

        public int[] HomeFeaturedProductIds { get; set; }
        public ProductDto[] HomeFeaturedProducts { get; set; }
        public int[] HomeFeaturedCategoryIds { get; set; }
        public ProductCategoryDto[] HomeFeaturedCategories { get; set; }

        public decimal UsdToSypExchangeRate { get; set; } = 15000;
    }
}
