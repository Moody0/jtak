using App.ApiModels;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using App.Shared.Services.Domain;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Modules.Catalog.Services;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Identity;
using App.Shared.Entities;
using System;
using System.Globalization;
using System.Linq;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ApiVersion("1")]
    public class HomeController : SolApiController
    {
        private readonly IGenericSettingService _genericSetting;
        private readonly IBannerService _bService;
        private readonly IAddressService _addrService;
        private readonly IProductCategoryService _catService;
        private readonly INotificationService _notifService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public HomeController(UserManager<AppUser> userManager,
            IAddressService addrService,
            IProductCategoryService catService,
            INotificationService notifService,
            IBannerService bService,
            IGenericSettingService genericSetting,
            IMapper mapper,
            ILogger<HomeController> logger)
        {
            _userManager = userManager;
            _addrService = addrService;
            _catService = catService;
            _notifService = notifService;
            _bService = bService;
            _genericSetting = genericSetting;
            _logger = logger;
            _mapper = mapper;
        }

        /// <summary>
        /// Get Home Page params
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [AllowAnonymous, Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        public async Task<ActionResult<HomeVm>> Get()
        {
            //var settings = await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), CultureInfo.CurrentCulture.TwoLetterISOLanguageName) ?? new SettingsVm() { };
            var user = await _userManager.GetUserAsync(User);
            var u = user != null ? _mapper.Map<UserDto>(user) : null;
            if (u != null)
                u.UserTopicId = _notifService.GetUserTopic(u.Id);
            var categories = await _catService.GetProductCategoriesTree();
            var settings = await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            // Admin settings are authored in the dashboard's Arabic locale.
            // Feature placement is platform-wide, so an English customer must
            // receive the same Home arrangement when no local override exists.
            settings ??= await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), "ar");
            var featuredCategoryIds = settings?.HomeFeaturedCategoryIds?
                .Where(id => id > 0)
                .Distinct()
                .ToArray() ?? Array.Empty<int>();

            // Preserve the exact order from the admin dashboard. Until an
            // admin makes a selection, retain the existing ordered root
            // categories so current installations do not get an empty Home.
            var featuredCategories = featuredCategoryIds.Any()
                ? featuredCategoryIds
                    .Select(id => categories.FirstOrDefault(category => category.Id == id))
                    .Where(category => category != null)
                    .ToArray()
                : categories;

            return new HomeVm
            {
                User = u,
                Addresses = await _addrService.GetUserAddresses(user?.Id),
                Banners = await _bService.GetBanners(BannerLocation.HomePage),
                Categories = categories,
                FeaturedCategories = featuredCategories
            };
        }
    }
}
