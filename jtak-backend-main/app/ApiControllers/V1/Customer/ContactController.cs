using System;
using System.Threading.Tasks;
using App.ApiModels;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Solf.Services;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class ContactController : SolApiController
    {
        private readonly IEmailService _emailService;
        private readonly ISupportMessageService _supportService;
        private readonly IAppUnitOfWork _uow;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger<ContactController> _logger;

        public ContactController(
            IEmailService emailService,
            ISupportMessageService supportService,
            IAppUnitOfWork uow,
            UserManager<AppUser> userManager,
            ILogger<ContactController> logger)
        {
            _emailService = emailService;
            _supportService = supportService;
            _uow = uow;
            _userManager = userManager;
            _logger = logger;
        }

        [HttpPost]
        [AllowAnonymous]
        public async Task<ActionResult<bool>> CreateContactMessage([FromBody] ContactMessageDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.Message))
            {
                return BadRequest(ApiErr.Create("يرجى كتابة نص الرسالة"));
            }

            var user = await _userManager.GetUserAsync(User);
            var senderName = !string.IsNullOrWhiteSpace(model.DisplayName)
                ? model.DisplayName.Trim()
                : (user != null ? $"{user.FirstName} {user.LastName}".Trim() : "عميل جيتك");
            if (string.IsNullOrWhiteSpace(senderName)) senderName = "عميل جيتك";

            var senderPhone = !string.IsNullOrWhiteSpace(model.PhoneNumber)
                ? model.PhoneNumber.Trim()
                : user?.PhoneNumber;

            var senderEmail = !string.IsNullOrWhiteSpace(model.Email)
                ? model.Email.Trim()
                : user?.Email;

            var title = !string.IsNullOrWhiteSpace(model.Title)
                ? model.Title.Trim()
                : "رسالة إلى الدعم الفني";

            var supportMessage = new SupportMessage
            {
                UserId = user?.Id,
                SenderName = senderName,
                SenderPhone = senderPhone,
                SenderEmail = senderEmail,
                Title = title,
                Message = model.Message.Trim(),
                Status = SupportMessageStatus.New,
                CreatedDate = DateTime.UtcNow
            };

            _supportService.Insert(supportMessage);
            await _uow.SaveChangesAsync();

            // Send notification email asynchronously with failure tolerance
            try
            {
                if (_emailService != null)
                {
                    await _emailService.SendContactMessage(senderName, title, senderEmail, model.Message, user, senderPhone);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send contact message email notification, database record saved successfully.");
            }

            return true;
        }
    }
}
