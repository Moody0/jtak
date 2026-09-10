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
    }
}
