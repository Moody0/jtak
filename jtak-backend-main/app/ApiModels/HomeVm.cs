using Modules.Catalog.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities;

namespace App.ApiModels
{
    public class HomeVm
    {
        public UserDto User { get; set; }
        public BannerLiteDto[] Banners { get; set; }
        public AddressDto[] Addresses { get; set; }
        public ProductCategoryDto[] Categories { get; set; }
        // This is intentionally separate from Categories. Categories is the
        // complete catalog tree used throughout the app, while this ordered
        // collection is the exact set the administrator chose for Home.
        public ProductCategoryDto[] FeaturedCategories { get; set; }

        // The curated Home grid. Each tile states where it leads, so the app
        // routes on data instead of recognising words in a category title.
        // FeaturedCategories above is kept in step with it for app builds that
        // predate this field.
        public HomeCategoryTileDto[] HomeCategories { get; set; }
    }
}
