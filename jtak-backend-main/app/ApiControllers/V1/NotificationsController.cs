using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.Helpers;
using App.Shared.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using OpenIddict.Validation.AspNetCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1
{
    [Route("api/v{version:apiVersion}/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    public class NotificationsController : SolApiController
    {
        private readonly UserManager<AppUser> _userManager;
        private readonly INotificationService _notificationService;
        private readonly ILogger _logger;
        public NotificationsController(INotificationService notificationService, ILogger<NotificationsController> logger, UserManager<AppUser> userManager)
        {
            _notificationService = notificationService;
            _userManager = userManager;
            _logger = logger;
        }

        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [AllowAnonymous]
        [Route("{page}")]
        public async Task<ActionResult<NotificationMessageDto[]>> GetNotifications(int page = 0)
        {
            var user = await _userManager.GetUserAsync(User);
            var notifications = (await _notificationService.GetNotifications(user?.Id))
                .Select(x => new NotificationMessageDto
                {
                    CreatedDate = x.CreatedDate,
                    Text = x.Text,
                    Title = x.Title,
                    Id = x.Id,
                    Url = x.Url,
                    EntityData = x.EntityData,
                    EventKey = x.EventKey
                })
                .OrderByDescending(x => x.CreatedDate)
                .Skip(20 * page)
                .Take(20)
                .ToArray();

            return notifications;
        }

        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("Count")]
        public async Task<ActionResult<int>> GetNotificationCount()
        {
            var user = await _userManager.GetUserAsync(User);
            var count = await _notificationService.CountUnreadNotifications(user.Id);

            return count;
        }

        [HttpGet]
        [Route("Test/{id}")]
        public async Task<ActionResult<bool>> Test(Guid id)
        {
            await _notificationService.SendPushNotification(new Shared.Entities.Notification
            {
                TitleAr = "تست",
                TitleEn = "Test",
                TitleTr = "bir test",
                TextAr = "تكست",
                TextEn = "Text",
                TextTr = "bir text",
                Topic = "orders",
                Url = $"{AppDomainHelper.DashboardDomain}\\Orders\\1",
                NotificationType = NotificationType.Order
            }, new[] { id }, true);

            return true;
        }

        [HttpPost]
        [Route("Subscribe/{topic}/{token}")]
        public async Task<ActionResult<bool>> Subscribe(string topic, string token)
        {
            var messaging = NotificationService.EnsureFirebaseMessaging();

            var registrationTokens = new List<string>() { token };

            foreach (var lang in new[] { "ar", "en", "tr" })
            {
                if (topic.EndsWith(lang))
                {
                    await messaging.SubscribeToTopicAsync(registrationTokens, topic);
                }
                else
                {
                    var baseTopic = topic.Substring(0, topic.LastIndexOf('_') + 1);
                    var oldTopic = baseTopic + lang;
                    await messaging.UnsubscribeFromTopicAsync(registrationTokens, oldTopic);
                }
            }
            return true;
        }

        [HttpPost]
        [Route("Unsubscribe/{topic}/{token}")]
        public async Task<ActionResult<bool>> Unsubscribe(string topic, string token)
        {
            var messaging = NotificationService.EnsureFirebaseMessaging();

            var registrationTokens = new List<string>() { token };

            // Subscribe the devices corresponding to the registration tokens to the topic
            var response = await messaging.UnsubscribeFromTopicAsync(registrationTokens, topic);
            // See the TopicManagementResponse reference documentation for the contents of response.
            Console.WriteLine($"{response.SuccessCount} tokens were subscribed successfully");
            return true;
        }
    }
}
