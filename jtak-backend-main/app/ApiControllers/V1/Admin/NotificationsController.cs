using App.ApiModels;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Linq;
using System;
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
using App.Shared.Services.Helpers;

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
        private readonly IAdminAuditService _auditService;

        public NotificationsController(
            INotificationService service,
            UserManager<AppUser> userManager,
            IAdminNotificationSummaryService summaryService,
            IAdminAuditService auditService = null)
        {
            _userManager = userManager;
            _service = service;
            _summaryService = summaryService;
            _auditService = auditService;
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

        [HttpGet]
        [Route("CampaignAudiences")]
        public async Task<ActionResult<CampaignAudiencesDto>> CampaignAudiences()
        {
            return new CampaignAudiencesDto
            {
                Customers = (await ActiveRecipients(AppRoleName.Customer)).Length,
                Delivery = (await ActiveRecipients(AppRoleName.Delivery)).Length,
                Warehouse = (await ActiveRecipients(AppRoleName.Merchant)).Length,
                PushConfigured = _service.IsCampaignPushConfigured()
            };
        }

        /// <summary>
        /// Get Notifications
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Datatable")]
        public async Task<ActionResult<TableResponseModel<NotificationDto>>> Datatable([FromBody] MetronicTable request)
        {
            if (request != null && request.PageNumber > 0)
            {
                request.PageNumber -= 1;
            }
            var lang = CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
            var list = await _service.ListMetronicTableQueryable(request, x => new NotificationDto
            {
                Id = x.Id,
                CreatedDate = x.CreatedDate,
                Topic = x.Topic,
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
        public async Task<ActionResult<CampaignPushResult>> Create(CampaignNotificationRequest vm)
        {
            if (vm == null || string.IsNullOrWhiteSpace(vm.TitleAr) || string.IsNullOrWhiteSpace(vm.TextAr))
                return BadRequest(ApiErr.Create("عنوان الإشعار ونصه مطلوبان."));

            var title = vm.TitleAr.Trim();
            var body = vm.TextAr.Trim();
            if (title.Length < 3 || title.Length > 100 || body.Length < 5 || body.Length > 500)
                return BadRequest(ApiErr.Create("العنوان يجب أن يكون بين 3 و100 حرف، والنص بين 5 و500 حرف."));

            var audience = (vm.Target ?? string.Empty).Trim().ToLowerInvariant();
            var role = audience switch
            {
                "customers" => AppRoleName.Customer,
                "delivery" => AppRoleName.Delivery,
                "warehouse" => AppRoleName.Merchant,
                _ => (AppRoleName?)null
            };
            if (!role.HasValue)
                return BadRequest(ApiErr.Create("يرجى اختيار تطبيق مستهدف صالح."));

            if (!_service.IsCampaignPushConfigured())
                return StatusCode(StatusCodes.Status503ServiceUnavailable,
                    ApiErr.Create("إرسال الإشعارات غير مهيأ على الخادم. يرجى إعداد بيانات Firebase أولاً."));

            var topic = audience switch
            {
                "customers" => "all",
                "delivery" => "campaign_delivery",
                _ => "campaign_warehouse"
            };
            var openOrders = string.Equals(vm.Destination, "orders", StringComparison.OrdinalIgnoreCase);
            var url = openOrders && audience == "delivery"
                ? $"{AppDomainHelper.DashboardUrl}/Orders/NewDeliveryOrder/0"
                : openOrders && audience == "warehouse"
                    ? $"{AppDomainHelper.DashboardUrl}/Orders/NewMerchantOrder/0"
                    : null;
            var notification = new Notification
            {
                Topic = topic,
                TitleAr = title,
                TitleEn = title,
                TitleTr = title,

                TextAr = body,
                TextEn = body,
                TextTr = body,

                //Image = string.IsNullOrWhiteSpace(vm.Image)?null: $"/api/v1/Services/PreviewImage/{vm.Image}?w=1000&h=500&crop=True",
                Image = string.IsNullOrWhiteSpace(vm.Image) ? null : $"/api/v1/Services/Download/{vm.Image.Trim()}",
                Url = url,
                NotificationType = NotificationType.GlobalNotification,
            };
            var recipients = await ActiveRecipients(role.Value);
            var result = await _service.SendCampaignNotification(notification, recipients);
            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Notifications",
                    Action = "Create",
                    EntityType = "Notification",
                    EntityId = notification.Id.ToString(),
                    Description = $"إرسال إشعار إلى تطبيق {audience}: {title}",
                    Result = result.AcceptedLanguages > 0 ? "Success" : "Failed",
                    AfterState = new { Audience = audience, result.RecipientAccounts, result.AcceptedLanguages, result.FailedLanguages, result.FailureCode, result.HistoryRetained }
                });
            }
            return result;
        }

        [HttpDelete]
        public async Task<ActionResult<object>> DeleteCampaigns([FromBody] int[] ids)
        {
            var requestedIds = (ids ?? Array.Empty<int>()).Where(id => id > 0).Distinct().ToArray();
            if (requestedIds.Length == 0)
                return BadRequest(ApiErr.Create("يرجى تحديد إشعار واحد على الأقل."));

            var deletedCount = await _service.DeleteCampaignNotifications(requestedIds);
            if (_auditService != null && deletedCount > 0)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Notifications",
                    Action = "Delete",
                    EntityType = "Notification",
                    Description = $"حذف {deletedCount} من الإشعارات العامة من سجل التطبيق",
                    Result = "Success",
                    AfterState = new { RequestedIds = requestedIds, DeletedCount = deletedCount }
                });
            }

            return Ok(new { deletedCount });
        }

        private async Task<Guid[]> ActiveRecipients(AppRoleName role)
        {
            return (await _userManager.GetUsersInRoleAsync(role.ToString()))
                .Where(user => user.IsActive && user.DeletionDate == null)
                .Select(user => user.Id)
                .Distinct()
                .ToArray();
        }
    }

    public class CampaignNotificationRequest
    {
        public string Target { get; set; }
        public string TitleAr { get; set; }
        public string TextAr { get; set; }
        public string Image { get; set; }
        public string Destination { get; set; }
    }

    public class CampaignAudiencesDto
    {
        public int Customers { get; set; }
        public int Delivery { get; set; }
        public int Warehouse { get; set; }
        public bool PushConfigured { get; set; }
    }
}
