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

using App.Shared.Services.Pricing;
using Modules.Orders.Entities;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class SettingsController : SolApiController
    {
        private readonly IProductService _service;
        private readonly IProductCategoryService _categoryService;
        private readonly IMerchantService _merchantService;
        private readonly IGenericSettingService _genericSetting;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;
        private readonly IAdminAuditService _auditService;
        private readonly IDriverPricingService _driverPricingService;

        public SettingsController(
            IProductService service,
            IProductCategoryService categoryService,
            IMerchantService merchantService,
            IGenericSettingService genericSetting,
            IAppUnitOfWork unitOfWork,
            IMapper mapper,
            ILogger<SettingsController> logger,
            IAdminAuditService auditService = null,
            IDriverPricingService driverPricingService = null)
        {
            _service = service;
            _categoryService = categoryService;
            _merchantService = merchantService;
            _genericSetting = genericSetting;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
            _auditService = auditService;
            _driverPricingService = driverPricingService;
        }

        /// <summary>
        /// Set Settings Value
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        public async Task<ActionResult<bool>> SetSettings(SettingsVm vm)
        {
            if (vm?.DriverPricing != null && !vm.DriverPricing.IsValid)
                return BadRequest("إعدادات أجور السائق غير صالحة. يجب تحديد أجر موجب والتحقق من القيم والحد الأقصى للأجرة.");

            var previousSettings = await _genericSetting.GetValue<SettingsVm>(nameof(SettingsVm), CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            var previousRate = await _genericSetting.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key);

            var beforeState = new
            {
                UsdToSypExchangeRate = previousRate?.Rate ?? previousSettings?.UsdToSypExchangeRate ?? 0,
                HomeFeaturedCategoryIds = previousSettings?.HomeFeaturedCategoryIds,
                HomeFeaturedProductIds = previousSettings?.HomeFeaturedProductIds
            };

            vm.HomeFeaturedCategories = null;
            vm.HomeFeaturedProducts = null;
            await _genericSetting.SetValue(nameof(SettingsVm), vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);

            // The rest of the settings blob is stored per language, but a rate
            // is not translatable and every culture has to resolve the same
            // one, so it is kept under its own neutral key as well.
            if (vm.UsdToSypExchangeRate > 0 && (previousRate?.Rate ?? 0) != vm.UsdToSypExchangeRate)
            {
                await _genericSetting.SetValue(UsdExchangeRateSetting.Key,
                                               new UsdExchangeRateSetting { Rate = vm.UsdToSypExchangeRate });

                // Dollar-quoted products store their selling price in the local
                // currency, so the new rate has to be written through to them.
                var repriced = await _merchantService.RepriceUsdDenominatedProducts(vm.UsdToSypExchangeRate);
                _logger.LogInformation("Exchange rate changed to {Rate}; repriced {Count} dollar-quoted products.",
                                       vm.UsdToSypExchangeRate, repriced);
            }

            if (vm.DriverPricing != null)
            {
                if (_driverPricingService != null)
                    await _driverPricingService.SaveSettingAsync(vm.DriverPricing);
                else
                    await _genericSetting.SetValue(DriverPricingSetting.Key, vm.DriverPricing);
            }

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Settings",
                    Action = "UpdateSettings",
                    EntityType = "Settings",
                    EntityId = "GlobalSettings",
                    Description = $"تحديث إعدادات النظام وسعر الصرف ({vm.UsdToSypExchangeRate:N0} ل.س)",
                    Result = "Success",
                    BeforeState = beforeState,
                    AfterState = new
                    {
                        vm.UsdToSypExchangeRate,
                        vm.HomeFeaturedCategoryIds,
                        vm.HomeFeaturedProductIds,
                        vm.DriverPricing
                    }
                });
            }

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

            // The neutral key is the authority for the rate; the copy inside the
            // localized blob is only there for older clients.
            var rate = await _genericSetting.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key);
            if (rate != null && rate.Rate > 0)
            {
                settings.UsdToSypExchangeRate = rate.Rate;
            }

            // Driver compensation pricing setting
            if (_driverPricingService != null)
            {
                settings.DriverPricing = await _driverPricingService.GetSettingAsync();
            }
            else
            {
                settings.DriverPricing = (await _genericSetting.GetValue<DriverPricingSetting>(DriverPricingSetting.Key)) ?? new DriverPricingSetting();
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

        /// <summary>
        /// Get Driver Delivery Compensation Pricing Configuration
        /// </summary>
        [HttpGet("DriverPricing")]
        public async Task<ActionResult<DriverPricingSetting>> GetDriverPricing()
        {
            if (_driverPricingService != null)
                return Ok(await _driverPricingService.GetSettingAsync());

            var setting = await _genericSetting.GetValue<DriverPricingSetting>(DriverPricingSetting.Key);
            return Ok(setting ?? new DriverPricingSetting());
        }

        /// <summary>
        /// Update Driver Delivery Compensation Pricing Configuration
        /// </summary>
        [HttpPut("DriverPricing")]
        public async Task<ActionResult<bool>> SetDriverPricing([FromBody] DriverPricingSetting setting)
        {
            if (setting == null || !setting.IsValid)
                return BadRequest("إعدادات أجور السائق غير صالحة. يجب تحديد أجر موجب، وتكون القيم غير سالبة والحد الأقصى صفراً أو مساوياً للحد الأدنى على الأقل.");

            if (_driverPricingService != null)
            {
                if (!await _driverPricingService.SaveSettingAsync(setting))
                    return BadRequest("تعذر حفظ إعدادات أجور السائق لأنها غير صالحة.");
            }
            else
                await _genericSetting.SetValue(DriverPricingSetting.Key, setting);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Settings",
                    Action = "UpdateDriverPricing",
                    EntityType = "DriverPricingSetting",
                    EntityId = DriverPricingSetting.Key,
                    Description = setting.Mode == DriverPricingMode.Fixed
                        ? $"تحديث تسعير أجور الكباتن إلى مبلغ ثابت ({setting.FixedAmount:N0} ل.س)"
                        : $"تحديث تسعير أجور الكباتن حسب المسافة ({setting.DistanceRatePerUnit:N0} ل.س/{(setting.Unit == DistanceUnit.Mile ? "ميل" : "كم")})",
                    Result = "Success",
                    AfterState = setting
                });
            }

            return Ok(true);
        }

        /// <summary>Fixed driver wage, applied only to "اطلب ما تحتاجه" requests.</summary>
        [HttpGet("ErrandDriverEarning")]
        public async Task<ActionResult<ErrandDriverEarningSetting>> GetErrandDriverEarning()
        {
            var setting = await _genericSetting.GetValue<ErrandDriverEarningSetting>(ErrandDriverEarningSetting.Key);
            return Ok(setting ?? new ErrandDriverEarningSetting());
        }

        [HttpPut("ErrandDriverEarning")]
        public async Task<ActionResult<bool>> SetErrandDriverEarning([FromBody] ErrandDriverEarningSetting setting)
        {
            if (setting == null || !setting.IsValid)
                return BadRequest("أدخل أجراً ثابتاً موجباً وصالحاً لمندوب طلبات اطلب ما تحتاجه.");

            await _genericSetting.SetValue(ErrandDriverEarningSetting.Key, setting);
            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Settings", Action = "UpdateErrandDriverEarning",
                    EntityType = "ErrandDriverEarningSetting", EntityId = ErrandDriverEarningSetting.Key,
                    Description = $"تحديث أجر مندوب اطلب ما تحتاجه إلى {setting.Amount:N2} ل.س لكل طلب",
                    Result = "Success", AfterState = setting
                });
            }
            return Ok(true);
        }
    }
}
