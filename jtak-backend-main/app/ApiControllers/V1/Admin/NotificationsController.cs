using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using Modules.Catalog.Services;
using App.Shared.Services.eCommerce;
using System.Globalization;
using Solf.Models;
using App.Shared.Entities.Enums;
using App.Shared.Data.App;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    [ApiVersion("1")]
    public class NotificationsController : SolApiController
    {
        private readonly INotificationService _service;
        private readonly UserManager<AppUser> _userManager;
        private readonly IAdminNotificationSummaryService _summaryService;

        public NotificationsController(
            INotificationService service,
            UserManager<AppUser> userManager,
            IAdminNotificationSummaryService summaryService)
        {
            _userManager = userManager;
            _service = service;
            _summaryService = summaryService;
        }

        /// <summary>
        /// Get real-time actionable notification and pending counter summary for admin sidebar
        /// </summary>
        [HttpGet]
        [Route("Summary")]
        public async Task<ActionResult<AdminNotificationSummaryDto>> Summary()
        {
            var summary = await _summaryService.GetSummaryAsync();
            return Ok(summary);
        }

        /// <summary>
        /// Get Notifications
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Datatable")]
        public async Task<ActionResult<TableResponseModel<NotificationDto>>> Datatable([FromBody] MetronicTable request)
        {
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new NotificationDto
            {
                Id = x.Id,
                TitleAr = x.TitleAr,
                TitleEn = x.TitleEn,
                TitleTr = x.TitleTr,
                TextAr = x.TextAr,
                TextEn = x.TextEn,
                TextTr = x.TextTr,
                Image = x.Image,
                Url = x.Url
            }, x => x.NotificationType == NotificationType.GlobalNotification);
            return list;
        }



        [HttpPost]
        public async Task<ActionResult<bool>> Create(NotificationDto vm)
        {
            var notification = new Notification
            {
                Topic = "all",
                TitleAr = vm.TitleAr,
                TitleEn = vm.TitleAr,
                TitleTr = vm.TitleAr,

                TextAr = vm.TextAr,
                TextEn = vm.TextAr,
                TextTr = vm.TextAr,

                //Image = string.IsNullOrWhiteSpace(vm.Image)?null: $"/api/v1/Services/PreviewImage/{vm.Image}?w=1000&h=500&crop=True",
                Image = string.IsNullOrWhiteSpace(vm.Image)?null: $"/api/v1/Services/Download/{vm.Image}",
                Url = vm.Url,
                NotificationType = NotificationType.GlobalNotification,
            };
            var recivers = (await _userManager.GetUsersInRoleAsync(AppRoleName.Customer.ToString())).Select(x => x.Id).ToArray();
            await _service.SendPushNotification(notification, recivers);
            return true;
        }
    }
}
