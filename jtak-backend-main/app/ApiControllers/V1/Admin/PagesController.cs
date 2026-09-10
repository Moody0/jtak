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

        //[HttpPut]
        //[Route("PrivacyPolicy")]
        //public async Task<ActionResult<PageVm>> PrivacyPolicy(PageVm vm)
        //{
        //    await _service.SetValue("PrivacyPolicy", vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
        //    return vm;
        //}

        //[HttpPut]
        //[Route("PaymentPolicy")]
        //public async Task<ActionResult<PageVm>> PaymentPolicy(PageVm vm)
        //{
        //    await _service.SetValue("PaymentPolicy", vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
        //    return vm;
        //}

        [HttpPut]
        [Route("TermsAndConditions")]
        public async Task<ActionResult<PageVm>> TermsAndConditions(PageVm vm)
        {
            await _service.SetValue("TermsAndConditions", vm, CultureInfo.CurrentCulture.TwoLetterISOLanguageName);
            return vm;
        }




        /// <summary>
        /// Get About page
        /// </summary>
        /// <returns></returns>
        [HttpGet]
        [Route("About")]
        public async Task<ActionResult<PageVm>> About() =>
            (await _service.GetValue<PageVm>("About", CultureInfo.CurrentCulture.TwoLetterISOLanguageName)) ?? new PageVm();


        // <summary>
        // Get PrivacyPolicy page
        // </summary>
        // <returns></returns>
        //[HttpGet]
        //[Route("PrivacyPolicy")]
        //public async Task<ActionResult<PageVm>> PrivacyPolicy() =>
        //    (await _service.GetValue<PageVm>("PrivacyPolicy", CultureInfo.CurrentCulture.TwoLetterISOLanguageName)) ?? new PageVm();


        // <summary>
        // Get PaymentPolicy page
        // </summary>
        // <returns></returns>
        //[HttpGet]
        //[Route("PaymentPolicy")]
        //public async Task<ActionResult<PageVm>> PaymentPolicy() =>
        //    (await _service.GetValue<PageVm>("PaymentPolicy", CultureInfo.CurrentCulture.TwoLetterISOLanguageName)) ?? new PageVm();



        // <summary>
        // Get TermsAndConditions page
        // </summary>
        // <returns></returns>
        [HttpGet]
        [Route("TermsAndConditions")]
        public async Task<ActionResult<PageVm>> TermsAndConditions() =>
            (await _service.GetValue<PageVm>("TermsAndConditions", CultureInfo.CurrentCulture.TwoLetterISOLanguageName)) ?? new PageVm();
    }
}
