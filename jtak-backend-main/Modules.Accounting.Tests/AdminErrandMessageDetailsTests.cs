using System;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Services;
using AutoMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminErrandMessageDetailsTests
    {
        [Fact]
        public async Task GetIncludesUnavailableReasonFailedAttemptsAndLatestException()
        {
            using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"admin-errand-details-{Guid.NewGuid()}").Options,
                new Microsoft.AspNetCore.Http.HttpContextAccessor());
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Unavailable,
                ErrandUnavailableReason = "المتجر لا يملك المنتج بالسعر المعتمد",
                ErrandDeliveryCodeFailedAttempts = 3
            };
            db.SupportMessages.Add(request);
            await db.SaveChangesAsync();
            db.ErrandStatusEvents.Add(new ErrandStatusEvent
            {
                SupportMessageId = request.Id,
                FromStatus = (int)ErrandStatus.Purchased,
                ToStatus = (int)ErrandStatus.Purchased,
                ActorRole = "Delivery",
                Note = "EXCEPTION: تعذر إكمال التسليم",
                CreatedDate = DateTime.UtcNow
            });
            await db.SaveChangesAsync();

            var support = new Mock<ISupportMessageService>();
            support.Setup(x => x.Queryable()).Returns(db.SupportMessages);
            var controller = new SupportMessagesController(
                support.Object, new AppUnitOfWork(db),
                NullLogger<SupportMessagesController>.Instance,
                Mock.Of<IMapper>());

            var action = await controller.Get(request.Id);
            var message = Assert.IsType<SupportMessageDto>(action.Value);

            Assert.Equal(request.ErrandUnavailableReason, message.ErrandUnavailableReason);
            Assert.Equal(3, message.ErrandDeliveryCodeFailedAttempts);
            Assert.Equal("EXCEPTION: تعذر إكمال التسليم", message.ErrandLatestException);
        }
    }
}
