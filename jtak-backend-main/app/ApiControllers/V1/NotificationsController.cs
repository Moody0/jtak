using App.ApiModels;
using App.Shared.Services;
using App.Shared.Services.Helpers;
using App.Shared.Entities;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
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
        private readonly IWebHostEnvironment _env;
        private readonly ILogger _logger;
        public NotificationsController(INotificationService notificationService, IWebHostEnvironment env, ILogger<NotificationsController> logger, UserManager<AppUser> userManager)
        {
            _notificationService = notificationService;
            _userManager = userManager;
            _logger = logger;
            _env = env;
        }

        [HttpGet]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [AllowAnonymous]
        [Route("{page}")]
        public async Task<ActionResult<NotificationMessageDto[]>> GetNotifications(int page = 0)
        {
            var user = await _userManager.GetUserAsync(User);
            var notifications = (await _notificationService.GetNotifications(user.Id))
                .Select(x => new NotificationMessageDto
                {
                    CreatedDate = x.CreatedDate,
                    Text = x.Text,
                    Title = x.Title,
                    Id = x.Id
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
            string path = _env.ContentRootPath + "/rightbite-4e059-firebase-adminsdk-8hcrm-eb184d3cf3.json";
            if (FirebaseApp.DefaultInstance == null)
                FirebaseApp.Create(new AppOptions() { Credential = GoogleCredential.FromFile(path) });

            var registrationTokens = new List<string>() { token };

            foreach (var lang in new[] { "ar", "en", "tr" })
            {
                if (topic.EndsWith(lang))
                {
                    await FirebaseMessaging.DefaultInstance.SubscribeToTopicAsync(registrationTokens, topic);
                }
                else
                {
                    var oldTopic = topic.Split("_").FirstOrDefault() + "_" + lang;
                    await FirebaseMessaging.DefaultInstance.UnsubscribeFromTopicAsync(registrationTokens, oldTopic);
                }
            }
            return true;
        }

        [HttpPost]
        [Route("Unsubscribe/{topic}/{token}")]
        public async Task<ActionResult<bool>> Unsubscribe(string topic, string token)
        {
            string path = _env.ContentRootPath + "/rightbite-4e059-firebase-adminsdk-8hcrm-eb184d3cf3.json";
            if (FirebaseApp.DefaultInstance == null)
                FirebaseApp.Create(new AppOptions() { Credential = GoogleCredential.FromFile(path) });

            var registrationTokens = new List<string>() { token };

            // Subscribe the devices corresponding to the registration tokens to the topic
            var response = await FirebaseMessaging.DefaultInstance.UnsubscribeFromTopicAsync(registrationTokens, topic);
            // See the TopicManagementResponse reference documentation for the contents of response.
            Console.WriteLine($"{response.SuccessCount} tokens were subscribed successfully");
            return true;
        }
    }
}
