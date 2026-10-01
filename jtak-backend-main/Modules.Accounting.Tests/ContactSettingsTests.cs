using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.ApiControllers.V1.Customer;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Solf.Services;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class ContactSettingsTests
    {
        [Fact]
        public void SystemContactSettings_DefaultValues_AreStandardJtakContacts()
        {
            var settings = new SystemContactSettings();

            Assert.Equal("0985615705", settings.PhoneNumber);
            Assert.Equal("+963985615705", settings.PhoneInternational);
            Assert.Equal("0985 615 705", settings.PhoneFormatted);
            Assert.Equal("963985615705", settings.WhatsAppNumber);
            Assert.Equal("contact@jtak.app", settings.SupportEmail);
            Assert.Equal("https://www.facebook.com/app.jtak/", settings.FacebookUrl);
            Assert.Equal("https://www.instagram.com/JTAKcompany/", settings.InstagramUrl);
            Assert.Equal("https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ", settings.YoutubeUrl);
        }

        [Fact]
        public void Normalize_HandlesLocalSyrianMobileNumber()
        {
            var settings = new SystemContactSettings
            {
                PhoneNumber = " 0912345678 ",
                PhoneInternational = null,
                PhoneFormatted = null,
                WhatsAppNumber = " 0912345678 "
            };

            settings.Normalize();

            Assert.Equal("0912345678", settings.PhoneNumber);
            Assert.Equal("+963912345678", settings.PhoneInternational);
            Assert.Equal("0912 345 678", settings.PhoneFormatted);
            Assert.Equal("963912345678", settings.WhatsAppNumber);
        }

        [Fact]
        public void Normalize_HandlesNullSocialUrlsGracefully()
        {
            var settings = new SystemContactSettings
            {
                FacebookUrl = null,
                InstagramUrl = null,
                YoutubeUrl = null,
                TelegramUrl = null
            };

            settings.Normalize();

            Assert.Equal(string.Empty, settings.FacebookUrl);
            Assert.Equal(string.Empty, settings.InstagramUrl);
            Assert.Equal(string.Empty, settings.YoutubeUrl);
            Assert.Equal(string.Empty, settings.TelegramUrl);
        }

        [Fact]
        public async Task ContactController_GetContactSettings_ReturnsDefaultsWhenGenericSettingNull()
        {
            var emailMock = new Mock<IEmailService>();
            var supportMock = new Mock<ISupportMessageService>();
            var uowMock = new Mock<IAppUnitOfWork>();
            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManager = new UserManager<AppUser>(userStoreMock.Object, null, null, null, null, null, null, null, null);
            var loggerMock = new Mock<ILogger<ContactController>>();

            var controller = new ContactController(
                emailMock.Object,
                supportMock.Object,
                uowMock.Object,
                userManager,
                loggerMock.Object,
                null);

            var actionResult = await controller.GetContactSettings();
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var resultSettings = Assert.IsType<SystemContactSettings>(okResult.Value);

            Assert.Equal("0985615705", resultSettings.PhoneNumber);
            Assert.Equal("963985615705", resultSettings.WhatsAppNumber);
        }

        [Fact]
        public async Task ContactController_GetContactSettings_ReturnsPersistedSettings()
        {
            var emailMock = new Mock<IEmailService>();
            var supportMock = new Mock<ISupportMessageService>();
            var uowMock = new Mock<IAppUnitOfWork>();
            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManager = new UserManager<AppUser>(userStoreMock.Object, null, null, null, null, null, null, null, null);
            var loggerMock = new Mock<ILogger<ContactController>>();
            var genericSettingMock = new Mock<IGenericSettingService>();

            var customSettings = new SystemContactSettings
            {
                PhoneNumber = "0999111222",
                WhatsAppNumber = "963999111222"
            };

            genericSettingMock.Setup(x => x.GetValue<SystemContactSettings>(SystemContactSettings.Key, null))
                .ReturnsAsync(customSettings);

            var controller = new ContactController(
                emailMock.Object,
                supportMock.Object,
                uowMock.Object,
                userManager,
                loggerMock.Object,
                genericSettingMock.Object);

            var actionResult = await controller.GetContactSettings();
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var resultSettings = Assert.IsType<SystemContactSettings>(okResult.Value);

            Assert.Equal("0999111222", resultSettings.PhoneNumber);
            Assert.Equal("963999111222", resultSettings.WhatsAppNumber);
        }
    }
}
