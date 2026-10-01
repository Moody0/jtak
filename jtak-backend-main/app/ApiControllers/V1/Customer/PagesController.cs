using App.ApiModels;
using App.Shared.Services;
using App.Shared.Data.App;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Globalization;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ApiVersion("1")]
    public class PagesController : SolApiController
    {
        private readonly IGenericSettingService _service;
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly ILogger _logger;
        private readonly IMapper _mapper;

        public PagesController(IGenericSettingService service, IAppUnitOfWork unitOfWork, IMapper mapper, ILogger<PagesController> logger)
        {
            _service = service;
            _unitOfWork = unitOfWork;
            _logger = logger;
            _mapper = mapper;
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
