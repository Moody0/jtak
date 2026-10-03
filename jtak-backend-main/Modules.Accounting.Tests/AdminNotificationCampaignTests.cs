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
using Microsoft.AspNetCore.Mvc;
using Modules.Catalog.Services;
using Modules.Catalog.Entities;

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
            Assert.Equal("/app/home", sent.Url);
            Assert.Equal(new[] { selectedUser.Id }, recipients);
            users.Verify(x => x.GetUsersInRoleAsync(expectedRole), Times.Once);
            users.Verify(x => x.GetUsersInRoleAsync(It.IsAny<string>()), Times.Once);
        }

        [Theory]
        [InlineData("customers", null, "/app/home")]
        [InlineData("customers", "  ", "/app/home")]
        [InlineData("customers", "orders", "/app/orders")]
        [InlineData("customers", "grocery", "/app/grocery")]
        [InlineData("customers", "restaurants", "/app/restaurants")]
        [InlineData("customers", "favorites", "/app/favorites")]
        [InlineData("customers", "errands", "/app/errands")]
        [InlineData("customers", "merchant", "/app/merchant/12")]
        [InlineData("delivery", "home", "/app/home")]
        [InlineData("delivery", "orders", "/app/orders")]
        [InlineData("delivery", "errands", "/app/errands")]
        [InlineData("delivery", "finance", "/app/finance")]
        [InlineData("warehouse", "home", "/app/home")]
        [InlineData("warehouse", "orders", "/app/orders")]
        [InlineData("warehouse", "products", "/app/products")]
        [InlineData("warehouse", "finance", "/app/finance")]
        public async Task Create_PersistsTheSelectedDestination(string target, string destination, string expectedUrl)
        {
            var (controller, service) = CreateController();
            var result = await controller.Create(new CampaignNotificationRequest
            {
                Target = target, Destination = destination, DestinationId = 12,
                TitleAr = "رسالة جديدة", TextAr = "نص رسالة الاختبار"
            });
            Assert.IsNotType<BadRequestObjectResult>(result.Result);
            service.Verify(s => s.SendCampaignNotification(It.Is<Notification>(n => n.Url == expectedUrl), It.IsAny<Guid[]>()), Times.Once);
        }

        [Theory]
        [InlineData("customers", "finance")]
        [InlineData("delivery", "merchant")]
        [InlineData("warehouse", "errands")]
        [InlineData("customers", "https://example.com")]
        public async Task Create_RejectsUnsupportedDestinations(string target, string destination)
        {
            var (controller, service) = CreateController();
            var result = await controller.Create(new CampaignNotificationRequest
            {
                Target = target, Destination = destination,
                TitleAr = "رسالة جديدة", TextAr = "نص رسالة الاختبار"
            });
            Assert.IsType<BadRequestObjectResult>(result.Result);
            service.Verify(s => s.SendCampaignNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>()), Times.Never);
        }

        [Theory]
        [InlineData(null)]
        [InlineData(0)]
        [InlineData(999)]
        public async Task Create_RejectsMissingOrUnavailableMerchant(int? id)
        {
            var (controller, service) = CreateController();
            var result = await controller.Create(new CampaignNotificationRequest
            {
                Target = "customers", Destination = "merchant", DestinationId = id,
                TitleAr = "رسالة جديدة", TextAr = "نص رسالة الاختبار"
            });
            Assert.IsType<BadRequestObjectResult>(result.Result);
            service.Verify(s => s.SendCampaignNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>()), Times.Never);
        }

        private static (NotificationsController, Mock<INotificationService>) CreateController()
        {
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(u => u.GetUsersInRoleAsync(It.IsAny<string>())).ReturnsAsync(new List<AppUser>());
            var service = new Mock<INotificationService>();
            service.Setup(s => s.IsCampaignPushConfigured()).Returns(true);
            service.Setup(s => s.SendCampaignNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>()))
                .ReturnsAsync(new CampaignPushResult { AcceptedLanguages = 3 });
            var merchants = new Mock<IMerchantService>();
            merchants.Setup(m => m.FindAsync(12)).ReturnsAsync(new Merchant { Id = 12, Active = true });
            return (new NotificationsController(service.Object, users.Object, null, merchants: merchants.Object), service);
        }
    }
}
