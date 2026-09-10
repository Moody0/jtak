using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using URF.Core.Abstractions;
using Solf.Services;

using App.Models;
using Microsoft.AspNetCore.Http;
using BitArmory.ReCaptcha;
using System.Text.Json;
using App.Shared.Entities;
using App.Shared.Services.Extentions;
using App.Shared.Services.Helpers;

namespace App.Controllers
{
    [Authorize]
    public class ContactController : BaseController
    {
        private readonly IEmailService _service;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ContactController(IUnitOfWork UOW,
                                    ILogger<MeController> logger,
                                    UserManager<AppUser> userManager,
                                    IMapper mapper,
                                    IHttpContextAccessor httpContextAccessor,
                                    IEmailService service) : base(UOW, mapper, logger, userManager)
        {
            _service = service;
            _httpContextAccessor = httpContextAccessor;
        }
        
        [AllowAnonymous]
        [HttpPost]
        public async Task<IActionResult> Index(ContactMessageDto model)
        {
            Request.Form.TryGetValue("captcha", out var token);
            var rresult = await new ReCaptchaService().Verify3Async(token, _httpContextAccessor?.HttpContext?.Connection?.RemoteIpAddress.ToString(), "6LeA2n8dAAAAAJJIrhPUbaa0y14JBU9SuXSjn0dm");
            if (!rresult.IsSuccess || rresult.Action != "Register" && rresult.Score < 0.5)
            {
                Logger.LogError(JsonSerializer.Serialize(rresult));
                return Redirect(AppDomainHelper.BaseUrl);
            }

            await _service.SendContactMessage(model.Name, model.Phone, model.Email, model.Message, null);

            return Redirect($"{AppDomainHelper.BaseUrl}/contact.html?msg=success");
        }

    }
}
