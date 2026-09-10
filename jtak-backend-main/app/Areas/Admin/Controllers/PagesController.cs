using System.Threading.Tasks;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using App.Resources;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;
using URF.Core.Abstractions;
using Microsoft.AspNetCore.Identity;
using App.Controllers;
using App.Models.Pages;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Entities;

namespace App.Areas.Admin.Controllers
{
    [Authorize(nameof(AppPermissionKey.AdminPermission))]
    [Area("Admin")]
    public class PagesController : BaseController
    {
        private readonly IGenericSettingService _service;
        private readonly IWebHostEnvironment _env;

        public PagesController(IUnitOfWork UOW,
                               ILogger<PagesController> logger,
                               UserManager<AppUser> userManager,
                               IMapper mapper,
                               IGenericSettingService service,
                               IWebHostEnvironment env) : base(UOW, mapper, logger, userManager)
        {
            _service = service;
            _env = env;
        }

        #region PrivacyPolicy
        public async Task<IActionResult> PrivacyPolicy()
        {
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            var model = await _service.GetValue<PrivacyPolicyPageVm>("PrivacyPolicyPageVm", lang);
            Init(model);
            return View(model);
        }

        [HttpPost]
        public async Task<IActionResult> PrivacyPolicy(PrivacyPolicyPageVm vm)
        {
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            await _service.SetValue("PrivacyPolicyPageVm", vm, lang);
            Init(vm);
            return View(vm);
        }
        private void Init(PrivacyPolicyPageVm model)
        {
            ViewBag.Title = _Nav.Settings + " - " + _Nav.PrivacyPolicy;
        }
        #endregion
        
        #region TermsAndConditions
        public async Task<IActionResult> TermsAndConditions()
        {
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            var model = await _service.GetValue<TermsAndConditionsPageVm>("TermsAndConditionsPageVm", lang);
            Init(model);
            return View(model);
        }

        [HttpPost]
        public async Task<IActionResult> TermsAndConditions(TermsAndConditionsPageVm vm)
        {
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            await _service.SetValue("TermsAndConditionsPageVm", vm, lang);
            Init(vm);
            return View(vm);
        }
        private void Init(TermsAndConditionsPageVm model)
        {
            ViewBag.Title = _Nav.Settings + " - " + _Nav.TermsAndConditions;
        }
        #endregion

    }
}
