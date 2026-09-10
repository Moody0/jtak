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
