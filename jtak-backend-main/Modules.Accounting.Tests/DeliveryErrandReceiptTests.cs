using System;
using System.Security.Claims;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

using System.Collections.Generic;
using System.IO;
using System.Threading;
using App.Helpers;
using App.Services;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;

namespace Modules.Accounting.Tests
{
    public class DeliveryErrandReceiptTests
    {
        [Fact]
        public async Task DriverCanSubmitReceiptReferenceAndPurchaseCost()
        {
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true };
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-receipt-{Guid.NewGuid()}").Options;

            using var db = new AppDbContext(options, new HttpContextAccessor());
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Assigned,
                ErrandDriverUserId = driver.Id,
                ErrandItemPrice = 1000m
            };
            db.SupportMessages.Add(request);
            await db.SaveChangesAsync();

            var users = new Mock<UserManager<AppUser>>(
                new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>()))
                .ReturnsAsync(driver);

            var env = new Mock<IWebHostEnvironment>();
            var controller = new App.ApiControllers.V1.Delivery.ErrandRequestsController(
                db, users.Object, env.Object,
                NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };

            var result = await controller.SubmitReceipt(request.Id,
                new App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto
                {
                    PurchaseCost = 600m,
                    ReceiptReference = "373634646"
                });

            var response = Assert.IsType<OkObjectResult>(result.Result);
            var receipt = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto>(response.Value);
            Assert.Equal(600m, receipt.PurchaseCost);
            Assert.Equal("373634646", receipt.ReceiptReference);
            Assert.Null(receipt.ReceiptPhotoToken);

            var saved = await db.SupportMessages.FirstAsync(x => x.Id == request.Id);
            Assert.Equal(600m, saved.ErrandPurchaseCost);
            Assert.Equal("373634646", saved.ErrandReceiptReference);
        }

        [Fact]
        public async Task ReceiptCostAboveApprovedQuoteIsRejectedWithoutSaving()
        {
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true };
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-receipt-limit-{Guid.NewGuid()}").Options;

            using var db = new AppDbContext(options, new HttpContextAccessor());
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Assigned,
                ErrandDriverUserId = driver.Id,
                ErrandItemPrice = 500m
            };
            db.SupportMessages.Add(request);
            await db.SaveChangesAsync();

            var users = new Mock<UserManager<AppUser>>(
                new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>()))
                .ReturnsAsync(driver);

            var controller = new App.ApiControllers.V1.Delivery.ErrandRequestsController(
                db, users.Object, new Mock<IWebHostEnvironment>().Object,
                NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };

            var result = await controller.SubmitReceipt(request.Id,
                new App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto
                {
                    PurchaseCost = 600m,
                    ReceiptReference = "373634646"
                });

            Assert.IsType<BadRequestObjectResult>(result.Result);
            var saved = await db.SupportMessages.FirstAsync(x => x.Id == request.Id);
            Assert.Null(saved.ErrandPurchaseCost);
            Assert.Null(saved.ErrandReceiptReference);
        }

        [Fact]
        public async Task PurchaseWithPhotoKeepsPhotoFileOnDiskAndSavesToken()
        {
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true };
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-purchase-photo-{Guid.NewGuid()}").Options;
            var accountingOptions = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase($"accounting-{Guid.NewGuid()}").Options;

            using var db = new AppDbContext(options, new HttpContextAccessor());
            using var accounting = new AccountingDbContext(accountingOptions, new HttpContextAccessor());
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);

            var floatAccount = await ledger.GetOrCreateUserAccountAsync(driver.Id, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Cash Float - Errand Driver");
            var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                ReferenceType = "FloatSeed", ReferenceId = driver.Id.ToString(), IdempotencyKey = $"seed-{driver.Id}",
                Description = "Seed float",
                Entries = new()
                {
                    new() { AccountId = floatAccount.Id, Debit = 5000m },
                    new() { AccountId = vault.Id, Credit = 5000m }
                }
            });

            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Assigned,
                ErrandDriverUserId = driver.Id,
                ErrandItemPrice = 1000m
            };
            db.SupportMessages.Add(request);
            await db.SaveChangesAsync();

            var users = new Mock<UserManager<AppUser>>(
                new Mock<IUserStore<AppUser>>().Object, null, null, null, null, null, null, null, null);
            users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(driver);

            var tempDir = Path.Combine(Path.GetTempPath(), "errand-test-" + Guid.NewGuid());
            Directory.CreateDirectory(tempDir);
            try
            {
                var env = new Mock<IWebHostEnvironment>();
                env.SetupGet(x => x.ContentRootPath).Returns(tempDir);

                var settlement = new ErrandSettlementService(db, accounting, ledger, null);
                var controller = new App.ApiControllers.V1.Delivery.ErrandRequestsController(
                    db, users.Object, env.Object,
                    NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance,
                    settlement);

                var fileMock = new Mock<IFormFile>();
                var content = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46 }; // valid JPEG header bytes
                var ms = new MemoryStream(content);
                fileMock.Setup(f => f.OpenReadStream()).Returns(ms);
                fileMock.Setup(f => f.FileName).Returns("receipt.jpg");
                fileMock.Setup(f => f.Length).Returns(content.Length);
                fileMock.Setup(f => f.CopyToAsync(It.IsAny<Stream>(), It.IsAny<CancellationToken>()))
                    .Returns((Stream stream, CancellationToken token) => stream.WriteAsync(content, 0, content.Length, token));

                var httpContext = new DefaultHttpContext();
                var formFiles = new FormFileCollection { fileMock.Object };
                httpContext.Request.ContentType = "multipart/form-data";
                httpContext.Request.Form = new FormCollection(new Dictionary<string, Microsoft.Extensions.Primitives.StringValues>
                {
                    ["PurchaseCost"] = "600",
                    ["ReceiptReference"] = "R-123"
                }, formFiles);
                controller.ControllerContext = new ControllerContext { HttpContext = httpContext };

                var result = await controller.Purchase(request.Id, new App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto
                {
                    PurchaseCost = 600m,
                    ReceiptReference = "R-123",
                    ReceiptPhoto = fileMock.Object
                });

                var okResult = Assert.IsType<OkObjectResult>(result.Result);
                var dto = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto>(okResult.Value);
                Assert.NotNull(dto.ReceiptPhotoToken);
                Assert.Equal("R-123", dto.ReceiptReference);
                Assert.Equal(600m, dto.PurchaseCost);

                var saved = await db.SupportMessages.FirstAsync(x => x.Id == request.Id);
                Assert.Equal(dto.ReceiptPhotoToken, saved.ErrandReceiptPhotoToken);

                var savedPath = env.Object.GetPhysicalPath(dto.ReceiptPhotoToken);
                Assert.True(File.Exists(savedPath), "The uploaded receipt photo must NOT be deleted after a successful purchase.");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }
    }
}
