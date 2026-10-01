using System.Security.Claims;
using System.Text.Json;
using App.ApiControllers.V1;
using App.Helpers;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class ErrandReceiptPrivacyTests
{
    [Theory]
    [InlineData(ErrandStatus.Purchased)]
    [InlineData(ErrandStatus.Delivered)]
    [InlineData(ErrandStatus.DeliveryPending)]
    public async Task CustomerListAndDetailsExcludeInternalReceipts(ErrandStatus status)
    {
        using var db = Database();
        var customer = new AppUser { Id = Guid.NewGuid() };
        var driver = new AppUser { Id = Guid.NewGuid() };
        var row = new SupportMessage {
            Title = "طلبات - اطلب أي شيء", UserId = customer.Id,
            ErrandDriverUserId = driver.Id, ErrandStatus = status,
            ErrandItemPrice = 50m, ErrandDeliveryFee = 10m,
            ErrandPurchaseCost = 30m, ErrandReceiptReference = "PRIVATE-16",
            ErrandReceiptPhotoToken = "private-photo.jpg", ErrandDeliveryCode = "123456"
        };
        db.SupportMessages.Add(row);
        await db.SaveChangesAsync();
        var users = Users(customer);
        var support = new Mock<ISupportMessageService>();
        support.Setup(x => x.Queryable()).Returns(db.SupportMessages);
        var api = new App.ApiControllers.V1.Customer.ErrandRequestsController(
            support.Object, null, users.Object, null,
            NullLogger<App.ApiControllers.V1.Customer.ErrandRequestsController>.Instance, db)
        { ControllerContext = Context() };
        var details = (await api.Get(row.Id)).Value!;
        var list = (await api.List()).Value!;
        Assert.Single(list);
        foreach (var dto in new[] { details, list[0] }) {
            using var json = JsonDocument.Parse(JsonSerializer.Serialize(dto,
                new JsonSerializerOptions(JsonSerializerDefaults.Web)));
            Assert.Equal(60m, json.RootElement.GetProperty("total").GetDecimal());
            foreach (var field in new[] { "purchaseCost", "receiptReference", "receiptPhotoToken" })
                Assert.False(json.RootElement.TryGetProperty(field, out _));
            Assert.DoesNotContain("PRIVATE-16", json.RootElement.GetRawText());
            Assert.DoesNotContain("private-photo", json.RootElement.GetRawText());
        }
        users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(driver);
        var driverApi = new App.ApiControllers.V1.Delivery.ErrandRequestsController(db,
            users.Object, new Mock<IWebHostEnvironment>().Object,
            NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance)
        { ControllerContext = Context() };
        var driverDto = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto>(
            Assert.IsType<OkObjectResult>((await driverApi.Get(row.Id)).Result).Value);
        Assert.Equal(30m, driverDto.PurchaseCost);
        Assert.Equal("PRIVATE-16", driverDto.ReceiptReference);
    }

    [Fact]
    public async Task PublicMediaBlocksReceiptsAndOldThumbnailsButKeepsProductImages()
    {
        using var db = Database();
        var root = Path.Combine(Path.GetTempPath(), "receipt-privacy-" + Guid.NewGuid());
        Directory.CreateDirectory(root);
        var env = new Mock<IWebHostEnvironment>();
        env.SetupGet(x => x.ContentRootPath).Returns(root);
        env.SetupGet(x => x.WebRootPath).Returns(Path.Combine(root, "wwwroot"));
        var receipt = "2026_9_30_" + Guid.NewGuid().ToString("N") + ".jpg";
        var product = "2026_9_30_" + Guid.NewGuid().ToString("N") + ".webp";
        try {
            await File.WriteAllBytesAsync(env.Object.GetPhysicalPath(receipt), new byte[] { 1 });
            await File.WriteAllBytesAsync(env.Object.GetPhysicalPath(product), new byte[] { 1 });
            var request = new SupportMessage { ErrandStatus = ErrandStatus.Delivered,
                ErrandReceiptPhotoToken = receipt };
            db.SupportMessages.Add(request);
            await db.SaveChangesAsync();
            var api = new ServicesController(null, NullLogger<ServicesController>.Instance,
                Users(new AppUser()).Object, null, env.Object, db) { ControllerContext = Context() };
            foreach (var token in new[] { receipt, receipt + "_extra",
                receipt.Replace(".jpg", "150x150c.jpg") }) {
                Assert.IsType<NotFoundResult>(await api.Download(token));
                Assert.IsType<NotFoundResult>(await api.PreviewImageApi(token));
            }
            Assert.IsType<NotFoundResult>(await api.Download("../receipt.jpg"));
            Assert.IsType<PhysicalFileResult>(await api.Download(product));
            Assert.IsType<PhysicalFileResult>(await api.PreviewImageApi(product));
            Assert.IsType<PhysicalFileResult>(await api.ErrandReceipt(request.Id));
            Assert.Equal("private, no-store", api.Response.Headers["Cache-Control"].ToString());
            Assert.IsType<NotFoundResult>(await api.ErrandReceipt(request.Id + 1));
            // Controller actions invoked directly do not run MVC authorization.
            // Check the endpoint policy separately; the global scheme validates the bearer token.
            var policy = typeof(ServicesController).GetMethod(nameof(ServicesController.ErrandReceipt))!
                .GetCustomAttributes(typeof(AuthorizeAttribute), false).Cast<AuthorizeAttribute>().Single();
            Assert.Equal(nameof(AppPermissionKey.AdminPermission), policy.Policy);
            Assert.Empty(typeof(ServicesController).GetMethod(nameof(ServicesController.ErrandReceipt))!
                .GetCustomAttributes(typeof(AllowAnonymousAttribute), false));
        } finally { Directory.Delete(root, true); }
    }

    private static AppDbContext Database() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase("receipt-privacy-" + Guid.NewGuid()).Options, new HttpContextAccessor());
    private static ControllerContext Context() => new() { HttpContext = new DefaultHttpContext() };
    private static Mock<UserManager<AppUser>> Users(AppUser user) {
        var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
            null, null, null, null, null, null, null, null);
        users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(user);
        return users;
    }
}
