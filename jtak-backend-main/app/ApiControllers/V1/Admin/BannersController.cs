using App.Extensions;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Data.App;
using Solf.Models;
using App.Shared.Entities.Enums;
using Microsoft.Extensions.Caching.Memory;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class BannerController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IBannerService _service;
        private readonly IMemoryCache _cache;

        public BannerController(IAppUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IBannerService service,
            ILogger<BannerController> logger,
            IMemoryCache cache,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _cache = cache;
            _service = service;
        }


        /// <summary>
        /// Get a paged/filtered/ordered list of Banners
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<BannerDto>>> DataTable([FromBody] MetronicTable request) =>
            await _service.ListMetronicTableQueryable(request, x => new BannerDto
            {
                Id = x.Id,
                Title = x.Title,
                Description = x.Description,
                FeaturedImage = x.FeaturedImage,
                Order = x.Order,
                Url = x.Url,
                BannerLocation = x.BannerLocation,
                Active = x.Active
            });


        /// <summary>
        /// Create Banner
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(BannerDto model)
        {
            var uid = User.GetUserId();
            var entity = new Banner
            {
                Title = model.Title,
                Description = model.Description,
                FeaturedImage = model.FeaturedImage,
                Order = model.Order,
                Url = model.Url,
                BannerLocation = model.BannerLocation,
                Active = model.Active
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();
            return entity.Id;
        }

        /// <summary>
        /// Edit Banner
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, BannerDto model)
        {
            var entity = await _service.FindAsync(id);
            if (entity == null)
            {
                return BadRequest("Not found!");
            }
            var uid = User.GetUserId();
            entity.Title = model.Title;
            entity.Description = model.Description;
            entity.FeaturedImage = model.FeaturedImage;
            entity.Order = model.Order;
            entity.Url = model.Url;
            entity.BannerLocation = model.BannerLocation;
            entity.Active = model.Active;

            await _uow.SaveChangesAsync();
            InvalidateBannerCache();

            return entity.Id;
        }

        /// <summary>
        /// Delete Banner
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            InvalidateBannerCache();
            return true;
        }

        private void InvalidateBannerCache()
        {
            _cache.Remove($"BannerCache_{BannerLocation.HomePage}");
            _cache.Remove($"BannerCache_{BannerLocation.DontMiss}");
            _cache.Remove($"BannerCache_{BannerLocation.RestaurantsPage}");
            _cache.Remove($"BannerCache_{BannerLocation.MarketPage}");
            _cache.Remove($"BannerCache_{BannerLocation.All}");
            _cache.Remove("BannerCache_AllActive");
        }
    }
}
