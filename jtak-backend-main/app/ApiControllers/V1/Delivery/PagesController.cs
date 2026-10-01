using App.ApiModels;
using App.Shared.Services;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Delivery
{
    [Route("api/v{version:apiVersion}/Delivery/[controller]")]
    [ApiVersion("1")]
    public class PagesController : SolApiController
    {
        private readonly IGenericSettingService _settings;

        public PagesController(IGenericSettingService settings) => _settings = settings;

        [HttpGet("About")]
        public Task<PageVm> About() => GetPage("About");

        [HttpGet("PrivacyPolicy")]
        public Task<PageVm> PrivacyPolicy() => GetPage("PrivacyPolicy");

        [HttpGet("PaymentPolicy")]
        public Task<PageVm> PaymentPolicy() => GetPage("PaymentPolicy");

        [HttpGet("TermsAndConditions")]
        public Task<PageVm> TermsAndConditions() => GetPage("TermsAndConditions_Delivery");

        private Task<PageVm> GetPage(string key) =>
            PageSettingsReader.GetPage(_settings, key, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
    }
}
