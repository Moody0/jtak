using System.Collections.Generic;

namespace App.ApiModels
{
    public class RestaurantCategoryItem
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string TitleEn { get; set; } = string.Empty;
        public string Image { get; set; } = string.Empty;
        public int Order { get; set; }
        public bool Active { get; set; } = true;
        public string FilterTag { get; set; } = string.Empty;

        /// <summary>
        /// Catalog category this entry represents. This is the real link: the
        /// merchants behind it are the ones that actually sell something in the
        /// category. FilterTag remains only as a fallback for entries that have
        /// not been pointed at a category yet.
        /// </summary>
        public int? ProductCategoryId { get; set; }

        /// <summary>
        /// How many merchants currently sell in this category. Computed on read
        /// rather than stored, so it cannot drift from the catalog. An entry
        /// with none is not shown to customers.
        /// </summary>
        public int MerchantCount { get; set; }
    }

    public class RestaurantCategoriesSectionConfig
    {
        public string SectionTitle { get; set; } = "كل المطاعم";
        public string SectionTitleEn { get; set; } = "All Restaurants";

        /// <summary>
        /// Heading for the same set of categories where it appears as a strip on
        /// Home. It is separate from SectionTitle because that one heads the
        /// restaurants page, where different wording reads correctly.
        /// </summary>
        public string HomeSectionTitle { get; set; } = "أصناف متنوعة";
        public string HomeSectionTitleEn { get; set; } = "Browse by kind";

        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Whether the strip appears on Home at all, independent of the
        /// restaurants page listing.
        /// </summary>
        public bool ShowOnHome { get; set; } = true;

        public List<RestaurantCategoryItem> Items { get; set; } = new List<RestaurantCategoryItem>();
    }

    public class AdminRestaurantCategoriesResponse
    {
        public string SectionTitle { get; set; } = "كل المطاعم";
        public string SectionTitleEn { get; set; } = "All Restaurants";
        public string HomeSectionTitle { get; set; } = "أصناف متنوعة";
        public string HomeSectionTitleEn { get; set; } = "Browse by kind";
        public bool Enabled { get; set; } = true;
        public bool ShowOnHome { get; set; } = true;

        /// <summary>Categories the administrator can point an entry at.</summary>
        public List<RestaurantCategoryTargetDto> AvailableCategories { get; set; } = new List<RestaurantCategoryTargetDto>();
        public int TotalCount { get; set; }
        public int ActiveCount { get; set; }
        public List<RestaurantCategoryItem> Items { get; set; } = new List<RestaurantCategoryItem>();
    }

    public class CustomerRestaurantCategoriesResponse
    {
        public string SectionTitle { get; set; } = "كل المطاعم";
        public string SectionTitleEn { get; set; } = "All Restaurants";
        public string HomeSectionTitle { get; set; } = "أصناف متنوعة";
        public string HomeSectionTitleEn { get; set; } = "Browse by kind";
        public bool Enabled { get; set; } = true;
        public bool ShowOnHome { get; set; } = true;
        public List<RestaurantCategoryItem> Items { get; set; } = new List<RestaurantCategoryItem>();
    }

    public class RestaurantCategoryTargetDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string ParentTitle { get; set; }
        public int MerchantCount { get; set; }
    }
}
