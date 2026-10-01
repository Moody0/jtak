using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Identity;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminNotificationCampaignTests
    {
        [Theory]
        [InlineData("customers", "Customer", "all")]
        [InlineData("delivery", "Delivery", "campaign_delivery")]
        [InlineData("warehouse", "Merchant", "campaign_warehouse")]
        public async Task Create_SendsOnlyToTheSelectedAppRole(string target, string expectedRole, string expectedTopic)
        {
            var selectedUser = new AppUser { Id = Guid.NewGuid(), IsActive = true };
            var inactiveUser = new AppUser { Id = Guid.NewGuid(), IsActive = false };
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(x => x.GetUsersInRoleAsync(It.IsAny<string>()))
                .ReturnsAsync((string role) => role == expectedRole
                    ? new List<AppUser> { selectedUser, inactiveUser }
                    : new List<AppUser> { new AppUser { Id = Guid.NewGuid(), IsActive = true } });

            Notification sent = null;
            Guid[] recipients = null;
            var service = new Mock<INotificationService>();
            service.Setup(x => x.IsCampaignPushConfigured()).Returns(true);
            service.Setup(x => x.SendCampaignNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>()))
                .Callback<Notification, Guid[]>((notification, ids) =>
                {
                    sent = notification;
                    recipients = ids;
                })
                .ReturnsAsync(new CampaignPushResult { RecipientAccounts = 1, AcceptedLanguages = 3 });

            var controller = new NotificationsController(service.Object, users.Object, null);
            await controller.Create(new CampaignNotificationRequest
            {
                Target = target,
                TitleAr = "رسالة جديدة",
                TextAr = "نص رسالة الاختبار"
            });

            Assert.Equal(expectedTopic, sent.Topic);
            Assert.Equal(new[] { selectedUser.Id }, recipients);
            users.Verify(x => x.GetUsersInRoleAsync(expectedRole), Times.Once);
            users.Verify(x => x.GetUsersInRoleAsync(It.IsAny<string>()), Times.Once);
        }
    }
}
