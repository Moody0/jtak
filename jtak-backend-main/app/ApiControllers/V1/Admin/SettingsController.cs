using App.ApiModels;
using App.Shared.Services;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class SettingsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IProductCategoryService _categoryService;
        private readonly IGenericSettingService _genericSetting;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public SettingsController(IProductService service, IProductCategoryService categoryService, IGenericSettingService genericSetting, IAppUnitOfWork unitOfWork, IMapper mapper, ILogger<SettingsController> logger)
        {
            _service = service;
            _categoryService = categoryService;
            _genericSetting = genericSetting;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
        }

        /// <summary>
        /// Get Settings Value
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        public async Task<ActionResult<bool>> SetSettings(SettingsVm vm)
        {
            vm.HomeFeaturedCategories = null;
            vm.HomeFeaturedProducts = null;
            await _genericSetting.SetValue(nameof(SettingsVm), vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            return true;
        }

        /// <summary>
        /// Set Settings Value
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        public async Task<ActionResult<SettingsVm>> GetSettings()
        {
            var settings = await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            if (settings == null)
            {
                settings = new SettingsVm();
            }
            var featuredCategoryIds = settings.HomeFeaturedCategoryIds?
                .Where(id => id > 0)
                .Distinct()
                .ToArray() ?? Array.Empty<int>();

            if (featuredCategoryIds.Any())
            {
                var categories = await _categoryService.Queryable()
                    .Where(x => featuredCategoryIds.Contains(x.Id) && x.Active && x.ParentId == null)
                    .Select(x => _mapper.Map<ProductCategoryDto>(x))
                    .ToArrayAsync();

                // A SQL IN clause does not preserve the administrator's
                // chosen order, so restore it before sending the settings
                // back to the dashboard.
                settings.HomeFeaturedCategories = featuredCategoryIds
                    .Select(id => categories.FirstOrDefault(x => x.Id == id))
                    .Where(x => x != null)
                    .ToArray();
            }
            else
            {
                settings.HomeFeaturedCategories = Array.Empty<ProductCategoryDto>();
            }
            settings.HomeFeaturedProducts = settings.HomeFeaturedProductIds?.Any() == true ? await _service.Queryable().Select(x => _mapper.Map<ProductDto>(x)).ToArrayAsync() : Array.Empty<ProductDto>();

            return settings;
        }
    }
}
