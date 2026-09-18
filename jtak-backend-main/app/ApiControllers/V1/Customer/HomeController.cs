using App.ApiModels;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using App.Shared.Services.Domain;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Identity;
using App.Shared.Entities;
using System;
using System.Globalization;
using System.Linq;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using App.Extensions;
using static OpenIddict.Abstractions.OpenIddictConstants;

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
        private readonly IHomeCategoriesService _homeCategoriesService;
        private readonly INotificationService _notifService;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public HomeController(UserManager<AppUser> userManager,
            IAddressService addrService,
            IProductCategoryService catService,
            IHomeCategoriesService homeCategoriesService,
            INotificationService notifService,
            IBannerService bService,
            IGenericSettingService genericSetting,
            IMapper mapper,
            ILogger<HomeController> logger)
        {
            _userManager = userManager;
            _addrService = addrService;
            _catService = catService;
            _homeCategoriesService = homeCategoriesService;
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
            if (user == null)
            {
                var uid = User.GetUserId();
                if (uid.HasValue)
                {
                    user = await _userManager.Users.FirstOrDefaultAsync(x => x.Id == uid.Value);
                }
            }

            if (user == null && User.Identity?.IsAuthenticated == true)
            {
                var userName = User.Identity?.Name 
                    ?? User.FindFirst(Claims.Name)?.Value 
                    ?? User.FindFirst(ClaimTypes.Name)?.Value;
                if (!string.IsNullOrWhiteSpace(userName))
                {
                    user = await _userManager.FindByNameAsync(userName) 
                        ?? await _userManager.FindByPhoneNumberAsync(userName);
                }
            }

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

            // Home Categories configuration (curated grid)
            var homeConfig = await _homeCategoriesService.GetConfig();
            var homeCategoriesEnabled = homeConfig?.Enabled ?? true;
            var homeCategoriesMaxItems = homeConfig?.MaxItems ?? 8;

            HomeCategoryTileDto[] homeCategories;
            if (!homeCategoriesEnabled)
            {
                homeCategories = Array.Empty<HomeCategoryTileDto>();
                featuredCategories = Array.Empty<ProductCategoryDto>();
            }
            else
            {
                var tiles = (await _homeCategoriesService.GetTiles(activeOnly: true))
                    .Where(tile => tile.TargetExists && tile.HasAvailableContent);
                if (homeCategoriesMaxItems > 0)
                {
                    tiles = tiles.Take(homeCategoriesMaxItems);
                }
                homeCategories = tiles.ToArray();

                // Older app builds read FeaturedCategories and know nothing about
                // tiles, so mirror the same arrangement into it wherever a tile
                // points at a product category.
                if (homeCategories.Any())
                {
                    var mirrored = homeCategories
                        .Where(tile => tile.ProductCategoryId.HasValue)
                        .Select(tile => categories.FirstOrDefault(category => category.Id == tile.ProductCategoryId.Value))
                        .Where(category => category != null)
                        .ToArray();
                    if (mirrored.Any())
                        featuredCategories = mirrored;
                }
            }

            return new HomeVm
            {
                User = u,
                Addresses = await _addrService.GetUserAddresses(user?.Id),
                Banners = await _bService.GetAllActiveBanners(),
                Categories = categories,
                FeaturedCategories = featuredCategories,
                HomeCategories = homeCategories,
                HomeCategoriesEnabled = homeCategoriesEnabled,
                HomeCategoriesMaxItems = homeCategoriesMaxItems,
                HomeCategoriesTitle = homeConfig?.SectionTitle,
                HomeCategoriesTitleEn = homeConfig?.SectionTitleEn
            };
        }

        /// <summary>
        /// Public settings including current USD to SYP exchange rate
        /// </summary>
        [HttpGet, Route("Settings"), AllowAnonymous]
        public async Task<ActionResult<object>> Settings()
        {
            var rateSetting = await _genericSetting.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key);
            decimal rate = 15000m;
            if (rateSetting != null && rateSetting.Rate > 0)
            {
                rate = rateSetting.Rate;
            }
            else
            {
                var settings = await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), "ar");
                if (settings != null && settings.UsdToSypExchangeRate > 0)
                {
                    rate = settings.UsdToSypExchangeRate;
                }
            }

            return Ok(new
            {
                usdToSypExchangeRate = rate
            });
        }
    }
}
