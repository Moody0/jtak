using App.ApiModels;
using App.Shared.Services.Extentions;
using App.Shared.Entities;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Solf.Services;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class ContactController : SolApiController
    {
        private readonly IEmailService _service;
        private readonly UserManager<AppUser> _userManager;

        public ContactController(IEmailService service, UserManager<AppUser> userManager, ILogger<ContactController> logger, IMapper mapper)
        {
            _service = service;
            _userManager = userManager;
        }

        [HttpPost]
        [AllowAnonymous]
        public async Task<ActionResult<bool>> CreateContactMessage(ContactMessageDto model)
        {
            var user = await _userManager.GetUserAsync(User);
            await _service.SendContactMessage(model.DisplayName, model.Title, model.Email, model.Message, user);
            return true;
        }
    }
}