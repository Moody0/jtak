using App.Shared.Entities;
using Modules.Catalog.Entities;
using App.Shared.Entities.Domain;
using Modules.Orders.Entities;
using App.Extensions;
using App.Shared.Services.Options;
using AutoMapper;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Options;

namespace App
{
    public class MappingProfile : Profile
    {
        public MappingProfile(IWebHostEnvironment env, IOptions<SolAppOptions> options)
        {
            //CreateMap<SolRole, RoleVm>()
            //    .ForMember(x => x.RolePermissions,
            //        o => o.MapFrom(y => EnumsExtensions.GetValues<AppPermissionKey>().Select(p => new RolePermissionVm()
            //        {
            //            AppPermissionKey = p,
            //            IsAllowed = y.RolePermissions.Any(z => z.SolPermissionKey == (int)p)
            //        })));

            CreateMap<Banner, BannerDto>();
            CreateMap<Banner, BannerLiteDto>();

            CreateMap<AppUser, UserDto>();
            //Role ?

            CreateMap<Faq, FaqLiteDto>();
            CreateMap<Product, ProductDto>();
            CreateMap<ProductCategory, ProductCategoryDto>();
            this.CreateMultiLingualMap<Testimonial, TestimonialTranslation, TestimonialDto>(options.Value.DefaultLanguage);
            CreateMap<Order, OrderDto>();
            CreateMap<OrderDetail, OrderDetailDto>();
            CreateMap<Tag, TagDto>();
            CreateMap<Address, AddressDto>();
            CreateMap<FavoriteProduct, FavoriteProductDto>();
            CreateMap<ProductReview, ProductReviewDto>();
            CreateMap<ProductTag, TagDto>()
                .ForMember(x => x.Id, o => o.MapFrom(y => y.Tag.Id))
                .ForMember(x => x.NameAr, o => o.MapFrom(y => y.Tag.NameAr))
                .ForMember(x => x.NameEn, o => o.MapFrom(y => y.Tag.NameEn))
                .ForMember(x => x.NameTr, o => o.MapFrom(y => y.Tag.NameTr))
                .ForMember(x => x.Photo, o => o.MapFrom(y => y.Tag.Photo));
        }
    }
}
