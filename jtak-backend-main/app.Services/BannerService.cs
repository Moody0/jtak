using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using AutoMapper;
using App.Shared.Entities.Domain;
using Solf.Base;
using Microsoft.Extensions.Caching.Memory;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;

namespace App.Shared.Services
{
    public interface IBannerService : ISolService<Banner, BannerDto>
    {
        Task<BannerLiteDto[]> GetBanners(BannerLocation location = BannerLocation.HomePage);
        Task<BannerLiteDto[]> GetAllActiveBanners();
    }

    public class BannerService : SolService<Banner, BannerDto>, IBannerService
    {
        private readonly IMapper _mapper;
        private readonly IMemoryCache _cache;
        public BannerService(ITrackableRepository<Banner, AppDbContext> repository, IMapper mapper, IMemoryCache cache) : base(repository)
        {
            _mapper = mapper;
            _cache = cache;
        }

        public async Task<BannerLiteDto[]> GetBanners(BannerLocation location = BannerLocation.HomePage) =>
            await _cache.GetValue($"BannerCache_{location}", null,
                async () => await Repository.Queryable()
                                            .Where(x => x.Active && (x.BannerLocation == location || x.BannerLocation == BannerLocation.All))
                                            .OrderBy(x => x.Order)
                                            .Select(x => new BannerLiteDto
                                            {
                                                Id = x.Id,
                                                Title = x.Title,
                                                Description = x.Description,
                                                Url = x.Url,
                                                FeaturedImage = x.FeaturedImage,
                                                Order = x.Order,
                                                BannerLocation = x.BannerLocation
                                            })
                                            .ToArrayAsync());

        public async Task<BannerLiteDto[]> GetAllActiveBanners() =>
            await _cache.GetValue("BannerCache_AllActive", null,
                async () => await Repository.Queryable()
                                            .Where(x => x.Active)
                                            .OrderBy(x => x.Order)
                                            .Select(x => new BannerLiteDto
                                            {
                                                Id = x.Id,
                                                Title = x.Title,
                                                Description = x.Description,
                                                Url = x.Url,
                                                FeaturedImage = x.FeaturedImage,
                                                Order = x.Order,
                                                BannerLocation = x.BannerLocation
                                            })
                                            .ToArrayAsync());

    }
}