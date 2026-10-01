using System;
using System.Linq;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using App.ApiControllers.V1.Customer;
using App.ApiModels;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class ErrandRequestsTests
    {
        [Fact]
        public async Task ValidMapPinCreatesSupportTicket_WhileOutsidePinIsRejectedDespiteHomsAddress()
        {
            var user = new AppUser
            {
                Id = Guid.NewGuid(),
                FirstName = "Rami",
                PhoneNumber = "+963991234567"
            };
            var userStore = new Mock<IUserStore<AppUser>>();
            var userManager = new Mock<UserManager<AppUser>>(
                userStore.Object, null, null, null, null, null, null, null, null);
            userManager.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>()))
                .ReturnsAsync(user);

            using var db = new AppDbContext(
                new DbContextOptionsBuilder<AppDbContext>()
                    .UseInMemoryDatabase($"errands-{Guid.NewGuid()}").Options,
                new HttpContextAccessor());
            SupportMessage saved = null;
            var support = new Mock<ISupportMessageService>();
            support.Setup(x => x.Queryable()).Returns(db.SupportMessages);
            support.Setup(x => x.Insert(It.IsAny<SupportMessage>()))
                .Callback<SupportMessage>(x => { saved = x; db.SupportMessages.Add(x); });
            var uow = new Mock<IAppUnitOfWork>();
            uow.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
                .Returns(() => db.SaveChangesAsync());
            var controller = new ErrandRequestsController(
                support.Object, uow.Object, userManager.Object, null,
                NullLogger<ErrandRequestsController>.Instance)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };

            var request = new CreateErrandRequestDto
            {
                RequestKey = Guid.NewGuid(),
                Items = "دواء من الصيدلية",
                PickupPlace = "صيدلية في الوعر",
                DeliveryAddress = "عنوان خارج المدينة لكنه مكتوب حمص",
                DeliveryLat = 34.7333m,
                DeliveryLng = 36.7167m,
                PhoneNumber = "+963991234567"
            };
            var accepted = await controller.Create(request);
            Assert.IsType<OkObjectResult>(accepted.Result);
            Assert.NotNull(saved);
            Assert.Equal(user.Id, saved.UserId);
            Assert.Equal(SupportMessageStatus.New, saved.Status);
            Assert.Contains("صيدلية في الوعر", saved.Message);
            Assert.Contains("https://www.google.com/maps?q=34.7333,36.7167", saved.Message);

            saved = null;
            request.DeliveryLat = 33.5138m;
            request.DeliveryLng = 36.2765m;
            request.DeliveryAddress = "حمص، محافظة حمص";
            var rejected = await controller.Create(request);
            var error = Assert.IsType<BadRequestObjectResult>(rejected.Result);
            Assert.Contains("خارج منطقة التغطية", Assert.IsType<ApiErr>(error.Value).Errors.First());
            Assert.Null(saved);
            support.Verify(x => x.Insert(It.IsAny<SupportMessage>()), Times.Once);
        }
    }
}
