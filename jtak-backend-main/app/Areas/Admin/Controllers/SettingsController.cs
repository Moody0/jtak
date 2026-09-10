using System.Threading.Tasks;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;
using URF.Core.Abstractions;
using Microsoft.AspNetCore.Identity;
using App.Controllers;
using App.Shared.Services;
using App.Shared.Entities;
using App.Areas.Admin.Models;
using App.Resources;
using App.Shared.Entities.Enums;

namespace App.Areas.Admin.Controllers
{
    [Authorize(nameof(AppPermissionKey.AdminPermission))]
    [Area("Admin")]
    public class SettingsController : BaseController
    {
        private readonly IMapper _mapper;
        private readonly IGenericSettingService _service;
        private readonly ILogger _logger;
        private readonly IWebHostEnvironment _env;

        public SettingsController(IUnitOfWork UOW,
                                    ILogger<SettingsController> logger,
                                    UserManager<AppUser> userManager,
                                    IMapper mapper,
                                    IGenericSettingService service,
                                    INotificationService notificationService,
                                    IWebHostEnvironment hostingEnvironment) : base(UOW, mapper, logger, userManager)
        {
            _service = service;
            _env = hostingEnvironment;
            _mapper = mapper;
            _logger = logger;
        }

        #region Index
        public async Task<IActionResult> Index()
        {
            ViewBag.Title = _Nav.Settings;
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            var model = await _service.GetValue<SettingsVm>("SettingsVm", lang);
            InitViewBags(model);
            return View(model);
        }
        [HttpPost]
        public async Task<IActionResult> Index(SettingsVm vm)
        {
            var lang = System.Threading.Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
            await _service.SetValue("SettingsVm", vm, lang);
            InitViewBags(vm);
            return View(vm);
        }
        #endregion

        private void InitViewBags(SettingsVm vm = null)
        {
        }
    }
}
