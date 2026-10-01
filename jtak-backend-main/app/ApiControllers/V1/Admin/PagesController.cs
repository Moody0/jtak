using App.ApiModels;
using App.Shared.Services;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OpenIddict.Validation.AspNetCore;
using System.Globalization;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class PagesController : SolApiController
    {
        private readonly IGenericSettingService _service;

        public PagesController(IGenericSettingService service)
        {
            _service = service;
        }

        [HttpPut]
        [Route("About")]
        public async Task<ActionResult<PageVm>> About(PageVm vm)
        {
            await _service.SetValue("About", vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            return vm;
        }

        [HttpPut]
        [Route("PrivacyPolicy")]
        public async Task<ActionResult<PageVm>> PrivacyPolicy([FromBody] PageVm vm) => await SavePage("PrivacyPolicy", vm);

        [HttpPut]
        [Route("PaymentPolicy")]
        public async Task<ActionResult<PageVm>> PaymentPolicy([FromBody] PageVm vm) => await SavePage("PaymentPolicy", vm);

        [HttpPut]
        [Route("TermsAndConditions")]
        public async Task<ActionResult<PageVm>> TermsAndConditions(
            [FromBody] PageVm vm,
            [FromQuery] string app = "customer")
        {
            if (!TryGetTermsSettingKey(app, out var settingKey))
                return BadRequest(new { message = "Unknown app. Use customer, delivery, or warehouse." });

            await _service.SetValue(settingKey, vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            return vm;
        }




        /// <summary>
        /// Get About page
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("About")]
        public async Task<ActionResult<PageVm>> About() =>
            await PageSettingsReader.GetPage(_service, "About", CultureInfo.CurrentCulture.TwoLetterISOLanguageName);


        // <summary>
        // Get PrivacyPolicy page
        // </summary>
        // <returns></returns>
        [HttpGet]
        [Route("PrivacyPolicy")]
        public async Task<ActionResult<PageVm>> PrivacyPolicy() =>
            await PageSettingsReader.GetPage(_service, "PrivacyPolicy", CultureInfo.CurrentCulture.TwoLetterISOLanguageName);


        // <summary>
        // Get PaymentPolicy page
        // </summary>
        // <returns></returns>
        [HttpGet]
        [Route("PaymentPolicy")]
        public async Task<ActionResult<PageVm>> PaymentPolicy() =>
            await PageSettingsReader.GetPage(_service, "PaymentPolicy", CultureInfo.CurrentCulture.TwoLetterISOLanguageName);



        // <summary>
        // Get TermsAndConditions page
        // </summary>
        // <returns></returns>
        [HttpGet]
        [Route("TermsAndConditions")]
        public async Task<ActionResult<PageVm>> TermsAndConditions([FromQuery] string app = "customer")
        {
            if (!TryGetTermsSettingKey(app, out var settingKey))
                return BadRequest(new { message = "Unknown app. Use customer, delivery, or warehouse." });

            var language = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var page = await PageSettingsReader.GetPage(_service, settingKey, language);
            if (string.IsNullOrWhiteSpace(page.Body) && settingKey != "TermsAndConditions")
                page = await PageSettingsReader.GetPage(_service, "TermsAndConditions", language);
            return page;
        }

        private async Task<ActionResult<PageVm>> SavePage(string key, PageVm vm)
        {
            if (vm == null) return BadRequest("Page content is required");
            vm.Title = string.IsNullOrWhiteSpace(vm.Title) ? key : vm.Title;
            await _service.SetValue(key, vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            return vm;
        }

        private static bool TryGetTermsSettingKey(string app, out string settingKey)
        {
            switch ((app ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "customer":
                    settingKey = "TermsAndConditions";
                    return true;
                case "delivery":
                    settingKey = "TermsAndConditions_Delivery";
                    return true;
                case "warehouse":
                    settingKey = "TermsAndConditions_Warehouse";
                    return true;
                default:
                    settingKey = null;
                    return false;
            }
        }
    }
}
