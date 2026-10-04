using App.ApiModels;
using App.Shared.Services;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OpenIddict.Validation.AspNetCore;
using System.Globalization;
using System;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class PagesController : SolApiController
    {
        private readonly IGenericSettingService _service;

        private readonly IAdminAuditService _audit;
        private readonly ILogger<PagesController> _logger;

        public PagesController(IGenericSettingService service, IAdminAuditService audit = null, ILogger<PagesController> logger = null)
        {
            _service = service;
            _audit = audit;
            _logger = logger;
        }

        [HttpPut]
        [Route("About")]
        public async Task<ActionResult<PageVm>> About([FromBody] PageVm vm) => await SavePage("About", vm);

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

            return await SavePage(settingKey, vm);
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
            // Show only the content actually stored for this app; copying is explicit.
            return page;
        }

        private async Task<ActionResult<PageVm>> SavePage(string key, PageVm vm)
        {
            if (vm == null || string.IsNullOrWhiteSpace(System.Net.WebUtility.HtmlDecode(
                System.Text.RegularExpressions.Regex.Replace(vm.Body ?? "", "<[^>]*>", ""))) || (vm.Body?.Length ?? 0) > 200000 || (vm.Title?.Length ?? 0) > 200)
                return BadRequest(new { message = "أدخل محتوى نصياً للصفحة، حتى 200 ألف حرف، وعنواناً حتى 200 حرف." });
            var before = await PageSettingsReader.GetPage(_service, key, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            vm.Title = string.IsNullOrWhiteSpace(vm.Title) ? key : vm.Title;
            await _service.SetValue(key, vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            if (_audit != null)
                try { await _audit.LogAsync(new AdminAuditLogEntry { Module = "Pages", Action = "Update", EntityType = "Page", EntityId = key,
                    Description = "تحديث محتوى صفحة التطبيق", Result = "Success", BeforeState = before, AfterState = vm }); }
                catch (Exception ex) { _logger?.LogError(ex, "Page saved but audit logging failed for {Page}.", key); }
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
