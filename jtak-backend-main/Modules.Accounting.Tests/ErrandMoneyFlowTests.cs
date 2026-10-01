using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class ErrandMoneyFlowTests
    {
        [Fact]
        public async Task CompetingDeliveryAndReturnClaims_CannotBothProceed()
        {
            var name = $"errand-race-{Guid.NewGuid()}";
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(name).Options;
            using var setup = new AppDbContext(options, new HttpContextAccessor());
            var request = new SupportMessage { Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Purchased, ErrandPurchaseCost = 800m };
            setup.SupportMessages.Add(request);
            await setup.SaveChangesAsync();
            using var delivery = new AppDbContext(options, new HttpContextAccessor());
            using var returned = new AppDbContext(options, new HttpContextAccessor());
            var deliveryView = await delivery.SupportMessages.FirstAsync(x => x.Id == request.Id);
            var returnView = await returned.SupportMessages.FirstAsync(x => x.Id == request.Id);
            deliveryView.ErrandStatus = ErrandStatus.DeliveryPending;
            await delivery.SaveChangesAsync();
            returnView.ErrandStatus = ErrandStatus.ReturnPending;
            await Assert.ThrowsAsync<DbUpdateConcurrencyException>(
                () => returned.SaveChangesAsync());
        }

        [Fact]
        public async Task DriverCanSeeOnlyOwnAssignedErrands()
        {
            using var app = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-driver-{Guid.NewGuid()}").Options,
                new HttpContextAccessor());
            var driver = new AppUser { Id = Guid.NewGuid() };
            var own = new SupportMessage { Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Assigned, ErrandDriverUserId = driver.Id,
                ErrandItemPrice = 100m, ErrandDeliveryFee = 20m };
            var other = new SupportMessage { Title = "طلبات - اطلب أي شيء",
                ErrandStatus = ErrandStatus.Assigned, ErrandDriverUserId = Guid.NewGuid(),
                ErrandItemPrice = 200m, ErrandDeliveryFee = 30m };
            app.SupportMessages.AddRange(own, other);
            await app.SaveChangesAsync();
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(driver);
            var env = new Mock<Microsoft.AspNetCore.Hosting.IWebHostEnvironment>();
            var api = new App.ApiControllers.V1.Delivery.ErrandRequestsController(app, users.Object, env.Object,
                NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance)
            { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };
            var list = Assert.IsType<OkObjectResult>((await api.List()).Result);
            var rows = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto[]>(list.Value);
            Assert.Single(rows);
            Assert.Equal(own.Id, rows[0].Id);
            Assert.Equal(120m, rows[0].TotalCashToCollect);
            Assert.IsType<NotFoundResult>((await api.Get(other.Id)).Result);

            for (var i = 0; i < 55; i++)
                app.SupportMessages.Add(new SupportMessage { Title = "طلبات - اطلب أي شيء",
                    ErrandStatus = ErrandStatus.Delivered, ErrandDriverUserId = driver.Id,
                    CreatedDate = DateTime.UtcNow.AddMinutes(i) });
            await app.SaveChangesAsync();
            var refreshed = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto[]>(
                Assert.IsType<OkObjectResult>((await api.List()).Result).Value);
            Assert.Equal(21, refreshed.Length);
            Assert.Equal(own.Id, refreshed[0].Id);
            Assert.DoesNotContain(refreshed, x => x.Id == other.Id);
        }

        [Theory]
        [InlineData(600, 200)]
        [InlineData(0, 800)]
        [InlineData(800, 0)]
        public async Task ReturnAfterPurchase_ReleasesGoodsAndRecordsUnrecoveredLossOnce(
            int refunded, int expectedLoss)
        {
            var accessor = new HttpContextAccessor();
            using var app = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-return-app-{Guid.NewGuid()}").Options, accessor);
            using var accounting = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase($"errand-return-ledger-{Guid.NewGuid()}").Options, accessor);
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var driverId = Guid.NewGuid();
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء", ErrandRequestKey = Guid.NewGuid(),
                ErrandStatus = ErrandStatus.Purchased, ErrandDriverUserId = driverId,
                ErrandItemPrice = 1000m, ErrandDeliveryFee = 100m,
                ErrandPurchaseCost = 800m
            };
            app.SupportMessages.Add(request);
            await app.SaveChangesAsync();
            var floatAccount = await ledger.GetOrCreateUserAccountAsync(driverId,
                AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Float");
            var goods = await ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ErrandGoodsInTransit, "Goods", AccountType.Asset);
            var vault = await ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "seed-return", Entries = new()
                {
                    new() { AccountId = floatAccount.Id, Debit = 1200m },
                    new() { AccountId = goods.Id, Debit = 800m },
                    new() { AccountId = vault.Id, Credit = 2000m }
                }
            });
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            var admin = new App.ApiControllers.V1.Admin.ErrandRequestsController(app, accounting,
                ledger, users.Object, null,
                NullLogger<App.ApiControllers.V1.Admin.ErrandRequestsController>.Instance);
            var returned = new ReturnErrandDto { RefundAmount = refunded, Reason = "إرجاع قبل التسليم" };
            var firstReturn = Assert.IsType<OkObjectResult>((await admin.Return(request.Id, returned)).Result);
            Assert.Equal(ErrandStatus.Returned,
                Assert.IsType<ErrandAdminDto>(firstReturn.Value).Status);
            var repeatedReturn = Assert.IsType<OkObjectResult>((await admin.Return(request.Id, returned)).Result);
            Assert.Equal(ErrandStatus.Returned,
                Assert.IsType<ErrandAdminDto>(repeatedReturn.Value).Status);
            Assert.Equal(1200m + refunded, await ledger.GetAccountBalanceAsync(floatAccount.Id));
            Assert.Equal(0m, await ledger.GetAccountBalanceAsync(goods.Id));
            var loss = await accounting.Accounts.FirstAsync(x => x.AccountCode == SystemAccountCodes.OperationalExpense);
            Assert.Equal(expectedLoss, await ledger.GetAccountBalanceAsync(loss.Id));
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(x =>
                x.IdempotencyKey == $"ErrandReturn-{request.Id}"));
        }

        [Theory]
        [InlineData(false)]
        [InlineData(true)]
        public async Task PurchaseAndDelivery_RecordFullCashFloat_MarginAndDriverEarningOnce(bool driverActions)
        {
            var accessor = new HttpContextAccessor();
            using var app = new AppDbContext(
                new DbContextOptionsBuilder<AppDbContext>()
                    .UseInMemoryDatabase($"errand-app-{Guid.NewGuid()}").Options, accessor);
            using var accounting = new AccountingDbContext(
                new DbContextOptionsBuilder<AccountingDbContext>()
                    .UseInMemoryDatabase($"errand-ledger-{Guid.NewGuid()}").Options, accessor);
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var customer = new AppUser { Id = Guid.NewGuid(), PhoneNumber = "+963991234567" };
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true, MaxCashFloat = 5000m };
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            users.Setup(x => x.FindByIdAsync(driver.Id.ToString())).ReturnsAsync(driver);
            users.Setup(x => x.IsInRoleAsync(driver, AppRoleName.Delivery.ToString())).ReturnsAsync(true);
            users.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(customer);
            users.Setup(x => x.GetUsersInRoleAsync(AppRoleName.Delivery.ToString()))
                .ReturnsAsync(new System.Collections.Generic.List<AppUser> { driver });

            var support = new Mock<ISupportMessageService>();
            support.Setup(x => x.Queryable()).Returns(app.SupportMessages);
            support.Setup(x => x.Insert(It.IsAny<SupportMessage>()))
                .Callback<SupportMessage>(x => app.SupportMessages.Add(x));
            var uow = new Mock<IAppUnitOfWork>();
            uow.Setup(x => x.SaveChangesAsync(default)).Returns(() => app.SaveChangesAsync());
            var customerApi = new App.ApiControllers.V1.Customer.ErrandRequestsController(
                support.Object, uow.Object, users.Object, null,
                NullLogger<App.ApiControllers.V1.Customer.ErrandRequestsController>.Instance)
            { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };
            var create = new App.ApiControllers.V1.Customer.CreateErrandRequestDto
            {
                DeviceLocation = new Modules.Orders.Entities.CustomerDeviceLocation { Latitude = 34.7333m, Longitude = 36.7167m, AccuracyMeters = 10m, CapturedAt = DateTimeOffset.UtcNow },
                RequestKey = Guid.NewGuid(), Items = "شيبسي وبيبسي", PickupPlace = "محل في حمص",
                DeliveryAddress = "حمص", DeliveryLat = 34.7333m, DeliveryLng = 36.7167m,
                PhoneNumber = customer.PhoneNumber
            };
            var created = Assert.IsType<App.ApiControllers.V1.Customer.ErrandRequestDto>(
                Assert.IsType<OkObjectResult>((await customerApi.Create(create)).Result).Value);
            var replay = Assert.IsType<App.ApiControllers.V1.Customer.ErrandRequestDto>(
                Assert.IsType<OkObjectResult>((await customerApi.Create(create)).Result).Value);
            Assert.Equal(created.Id, replay.Id);
            var request = await app.SupportMessages.SingleAsync();

            var floatAccount = await ledger.GetOrCreateUserAccountAsync(driver.Id, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Driver Float");
            var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                "Company Vault", AccountType.Asset);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "seed-errand-float", Entries = new()
                {
                    new() { AccountId = floatAccount.Id, Debit = 2000m },
                    new() { AccountId = vault.Id, Credit = 2000m }
                }
            });

            var settlement = new ErrandSettlementService(app, accounting, ledger, null);
            var settings = new Mock<App.Shared.Services.IGenericSettingService>();
            settings.Setup(x => x.GetValue<Modules.Orders.Entities.ErrandDriverEarningSetting>(
                    Modules.Orders.Entities.ErrandDriverEarningSetting.Key, null))
                .ReturnsAsync(new Modules.Orders.Entities.ErrandDriverEarningSetting { Amount = 150m });
            var deliveryStatus = new Mock<Modules.Shipping.Services.IDeliveryService>();
            deliveryStatus.Setup(x => x.GetDeliveryStatus(It.IsAny<Guid>()))
                .ReturnsAsync(new Modules.Shipping.Entities.DeliveryStatus { IsOnline = true,
                    PendingOrders = new System.Collections.Generic.List<Modules.Shipping.Entities.ShippingOrderDto>
                    { new() { OrderId = 61, DriverId = driver.Id } } });
            var notifications = new Mock<INotificationService>();
            var admin = new App.ApiControllers.V1.Admin.ErrandRequestsController(
                app, accounting, ledger, users.Object, notifications.Object,
                NullLogger<App.ApiControllers.V1.Admin.ErrandRequestsController>.Instance,
                settlement, deliveryService: deliveryStatus.Object, genericSetting: settings.Object);
            Assert.IsType<ConflictObjectResult>((await admin.Assign(request.Id,
                new AssignErrandDto { DriverUserId = driver.Id })).Result);
            Assert.IsType<OkObjectResult>((await admin.Quote(request.Id,
                new QuoteErrandDto { ItemPrice = 1000m, DeliveryFee = 100m, AcceptDriverSubsidy = true })).Result);
            Assert.Equal(150m, request.ErrandDriverEarning);
            var activeQuoteKey = request.ErrandQuoteKey;
            Assert.IsType<ConflictObjectResult>((await admin.Quote(request.Id,
                new QuoteErrandDto { ItemPrice = 1000m, DeliveryFee = 100m, AcceptDriverSubsidy = true })).Result);
            Assert.Equal(activeQuoteKey, request.ErrandQuoteKey);

            Assert.IsType<ConflictObjectResult>((await customerApi.Approve(request.Id,
                new App.ApiControllers.V1.Customer.ApproveErrandQuoteDto
                { QuoteKey = Guid.NewGuid() })).Result);
            Assert.Equal(ErrandStatus.Quoted, request.ErrandStatus);
            Assert.IsType<OkObjectResult>((await customerApi.Approve(request.Id,
                new App.ApiControllers.V1.Customer.ApproveErrandQuoteDto
                { QuoteKey = request.ErrandQuoteKey.Value })).Result);
            var unfundedDriver = new AppUser { Id = Guid.NewGuid(), IsActive = true, MaxCashFloat = 5000m };
            users.Setup(x => x.FindByIdAsync(unfundedDriver.Id.ToString())).ReturnsAsync(unfundedDriver);
            users.Setup(x => x.IsInRoleAsync(unfundedDriver, AppRoleName.Delivery.ToString())).ReturnsAsync(true);
            deliveryStatus.Setup(x => x.GetDeliveryStatus(driver.Id))
                .ReturnsAsync(new Modules.Shipping.Entities.DeliveryStatus { IsOnline = false });
            Assert.IsType<ConflictObjectResult>((await admin.Assign(request.Id,
                new AssignErrandDto { DriverUserId = driver.Id })).Result);
            deliveryStatus.Setup(x => x.GetDeliveryStatus(driver.Id))
                .ReturnsAsync(new Modules.Shipping.Entities.DeliveryStatus { IsOnline = true,
                    PendingOrders = new System.Collections.Generic.List<Modules.Shipping.Entities.ShippingOrderDto>
                    { new() { OrderId = 61, DriverId = driver.Id } } });
            Assert.IsType<BadRequestObjectResult>((await admin.Assign(request.Id,
                new AssignErrandDto { DriverUserId = unfundedDriver.Id })).Result);
            Assert.IsType<OkObjectResult>((await admin.Assign(request.Id,
                new AssignErrandDto { DriverUserId = driver.Id })).Result);
            notifications.Verify(x => x.SendPushNotification(
                It.Is<Notification>(n => n.EntityData == $"ErrandDelivery:{request.Id}"),
                It.Is<Guid[]>(ids => ids.Length == 1 && ids[0] == driver.Id), true, false), Times.Once);
            var driverUsers = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            driverUsers.Setup(x => x.GetUserAsync(It.IsAny<ClaimsPrincipal>())).ReturnsAsync(driver);
            var driverApi = new App.ApiControllers.V1.Delivery.ErrandRequestsController(
                app, driverUsers.Object, null,
                NullLogger<App.ApiControllers.V1.Delivery.ErrandRequestsController>.Instance, settlement)
            { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };
            var assigned = Assert.IsType<App.ApiControllers.V1.Delivery.DriverErrandDto[]>(
                Assert.IsType<OkObjectResult>((await driverApi.List()).Result).Value);
            Assert.Equal(request.Id, Assert.Single(assigned).Id);
            var options = Assert.IsType<ErrandDriverAvailabilityDto[]>(
                Assert.IsType<OkObjectResult>((await admin.Drivers()).Result).Value);
            var availability = Assert.Single(options);
            Assert.Equal(driver.Id, availability.Id);
            Assert.Equal(1, availability.ActiveDeliveryOrders);
            Assert.Equal(1, availability.ActivePurchaseRequests);
            Assert.Equal(2000m, availability.AvailableCashFloat);
            var pendingCustomer = Assert.IsType<App.ApiControllers.V1.Customer.ErrandRequestDto>(
                (await customerApi.Get(request.Id)).Value);
            Assert.Equal(1100m, pendingCustomer.Total);
            Assert.Null(pendingCustomer.DeliveryCode);
            Assert.Matches("^[0-9]{6}$", request.ErrandDeliveryCode);
            Assert.IsType<BadRequestObjectResult>((await admin.Purchase(request.Id,
                new PurchaseErrandDto { PurchaseCost = 1100m, ReceiptReference = "R-1" })).Result);
            // The older driver app may provide a photo without a receipt number.
            if (!driverActions) request.ErrandReceiptPhotoToken = "legacy-photo-token";
            if (driverActions)
                Assert.IsType<OkObjectResult>((await driverApi.Purchase(request.Id,
                    new App.ApiControllers.V1.Delivery.SubmitErrandReceiptDto { PurchaseCost = 800m, ReceiptReference = "R-1" })).Result);
            else
                Assert.IsType<OkObjectResult>((await admin.Purchase(request.Id,
                    new PurchaseErrandDto { PurchaseCost = 800m })).Result);
            var purchasedCustomer = Assert.IsType<App.ApiControllers.V1.Customer.ErrandRequestDto>(
                (await customerApi.Get(request.Id)).Value);
            Assert.Equal(ErrandStatus.Purchased, purchasedCustomer.ErrandStatus);
            Assert.Equal(request.ErrandDeliveryCode, purchasedCustomer.DeliveryCode);
            if (!driverActions) Assert.Equal("legacy-photo-token", request.ErrandReceiptPhotoToken);
            Assert.Equal(1200m, await ledger.GetAccountBalanceAsync(floatAccount.Id));
            Assert.IsType<BadRequestObjectResult>((await admin.Deliver(request.Id,
                new DeliverErrandDto { CustomerReceived = true, CashCollected = true,
                    DeliveryCode = request.ErrandDeliveryCode,
                    CollectedAmount = 1000m })).Result);
            Assert.IsType<BadRequestObjectResult>((await admin.Deliver(request.Id,
                new DeliverErrandDto { CustomerReceived = true, CashCollected = true,
                    DeliveryCode = "000000", CollectedAmount = 1100m })).Result);
            var delivery = new DeliverErrandDto { CustomerReceived = true,
                CashCollected = true, CollectedAmount = 1100m,
                DeliveryCode = request.ErrandDeliveryCode, RecoveryReason = "Legacy admin recovery test" };
            if (driverActions)
            {
                var driverDelivery = new App.ApiControllers.V1.Delivery.CompleteErrandDeliveryDto
                { CustomerReceived = true, CashCollected = true, CollectedAmount = 1099m, DeliveryCode = request.ErrandDeliveryCode };
                for (var i = 0; i < 5; i++)
                    Assert.IsType<BadRequestObjectResult>((await driverApi.Deliver(request.Id, driverDelivery)).Result);
                Assert.Equal(0, request.ErrandDeliveryCodeFailedAttempts);
                driverDelivery.CollectedAmount = 1100m;
                driverDelivery.DeliveryCode = "000000";
                Assert.IsType<BadRequestObjectResult>((await driverApi.Deliver(request.Id, driverDelivery)).Result);
                Assert.Equal(1, request.ErrandDeliveryCodeFailedAttempts);
                driverDelivery.DeliveryCode = request.ErrandDeliveryCode;
                Assert.IsType<OkObjectResult>((await driverApi.Deliver(request.Id, driverDelivery)).Result);
                Assert.IsType<OkObjectResult>((await driverApi.Deliver(request.Id, driverDelivery)).Result);
                Assert.Equal(0, request.ErrandDeliveryCodeFailedAttempts);
            }
            else
            {
                Assert.IsType<OkObjectResult>((await admin.Deliver(request.Id, delivery)).Result);
                Assert.IsType<OkObjectResult>((await admin.Deliver(request.Id, delivery)).Result);
            }
            var deliveredCustomer = Assert.IsType<App.ApiControllers.V1.Customer.ErrandRequestDto>(
                (await customerApi.Get(request.Id)).Value);
            Assert.Equal(ErrandStatus.Delivered, deliveredCustomer.ErrandStatus);
            Assert.Equal(1100m, deliveredCustomer.CashCollected);

            Assert.Equal(2300m, await ledger.GetAccountBalanceAsync(floatAccount.Id));
            Assert.Equal(1100m, request.ErrandCashCollected);
            Assert.Equal(ErrandStatus.Delivered, request.ErrandStatus);
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(x =>
                x.IdempotencyKey == $"ErrandPurchase-{request.Id}"));
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(x =>
                x.IdempotencyKey == $"ErrandDelivery-{request.Id}"));
            var margin = await accounting.Accounts.FirstAsync(x =>
                x.AccountCode == SystemAccountCodes.ErrandProductMarginRevenue);
            var earning = await accounting.Accounts.FirstAsync(x =>
                x.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix));
            var goods = await accounting.Accounts.FirstAsync(x =>
                x.AccountCode == SystemAccountCodes.ErrandGoodsInTransit);
            Assert.Equal(200m, await ledger.GetAccountBalanceAsync(margin.Id));
            Assert.Equal(150m, await ledger.GetAccountBalanceAsync(earning.Id));
            var subsidy = await accounting.Accounts.FirstAsync(x =>
                x.AccountCode == SystemAccountCodes.DriverEarningSubsidyExpense);
            Assert.Equal(50m, await ledger.GetAccountBalanceAsync(subsidy.Id));
            Assert.Equal(0m, await ledger.GetAccountBalanceAsync(goods.Id));
            var deliveryJournal = await accounting.JournalTransactions.Include(x => x.Entries)
                .SingleAsync(x => x.IdempotencyKey == $"ErrandDelivery-{request.Id}");
            Assert.Equal(deliveryJournal.Entries.Sum(x => x.Debit),
                deliveryJournal.Entries.Sum(x => x.Credit));
        }

        [Fact]
        public async Task DriverSettlement_RejectsOverageAndWrongProof_AndIsIdempotent()
        {
            var accessor = new HttpContextAccessor();
            using var app = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-driver-settlement-app-{Guid.NewGuid()}").Options, accessor);
            using var accounting = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase($"errand-driver-settlement-ledger-{Guid.NewGuid()}").Options, accessor);
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var driverId = Guid.NewGuid();
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء", ErrandRequestKey = Guid.NewGuid(),
                ErrandStatus = ErrandStatus.Assigned, ErrandDriverUserId = driverId,
                ErrandItemPrice = 1000m, ErrandDeliveryFee = 100m,
                ErrandDeliveryCode = "123456"
            };
            app.SupportMessages.Add(request);
            await app.SaveChangesAsync();
            var floatAccount = await ledger.GetOrCreateUserAccountAsync(driverId, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Driver Float");
            var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                "Company Vault", AccountType.Asset);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "seed-errand-driver-settlement", Entries = new()
                {
                    new() { AccountId = floatAccount.Id, Debit = 2000m },
                    new() { AccountId = vault.Id, Credit = 2000m }
                }
            });
            var service = new ErrandSettlementService(app, accounting, ledger, null);

            var overage = await service.RecordPurchaseAsync(request, 1001m, "R-1", null, driverId, "Delivery");
            Assert.False(overage.Success);
            Assert.Equal(ErrandStatus.Assigned, request.ErrandStatus);

            // Model a timeout after the API persisted PurchasePending but before it
            // acknowledged the ledger post. The retry uploads a different photo token.
            request.ErrandStatus = ErrandStatus.PurchasePending;
            request.ErrandPurchaseCost = 800m;
            request.ErrandReceiptReference = "R-1";
            request.ErrandReceiptPhotoToken = "old-photo-token";
            await app.SaveChangesAsync();
            var purchase = await service.RecordPurchaseAsync(request, 800m, "R-1-retry",
                "new-photo-token", driverId, "Delivery");
            Assert.True(purchase.Success);
            Assert.Equal(ErrandStatus.Purchased, request.ErrandStatus);
            Assert.True((await service.RecordPurchaseAsync(request, 800m, "R-1-retry",
                "new-photo-token", driverId, "Delivery")).Success);
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(x =>
                x.IdempotencyKey == $"ErrandPurchase-{request.Id}"));

            Assert.False((await service.RecordDeliveryAsync(request, 1099m, request.ErrandDeliveryCode,
                true, true, driverId, "Delivery")).Success);
            Assert.False((await service.RecordDeliveryAsync(request, 1100m, "000000",
                true, true, driverId, "Delivery")).Success);
            Assert.Equal(ErrandStatus.Purchased, request.ErrandStatus);

            Assert.True((await service.RecordDeliveryAsync(request, 1100m, request.ErrandDeliveryCode,
                true, true, driverId, "Delivery")).Success);
            Assert.True((await service.RecordDeliveryAsync(request, 1100m, request.ErrandDeliveryCode,
                true, true, driverId, "Delivery")).Success);
            Assert.Equal(ErrandStatus.Delivered, request.ErrandStatus);
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(x =>
                x.IdempotencyKey == $"ErrandDelivery-{request.Id}"));
        }

        [Fact]
        public async Task AttachingReceiptPhotoAfterPurchase_DoesNotChangeCostOrPostLedgerAgain()
        {
            var accessor = new HttpContextAccessor();
            using var app = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase($"errand-attach-photo-app-{Guid.NewGuid()}").Options, accessor);
            using var accounting = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase($"errand-attach-photo-ledger-{Guid.NewGuid()}").Options, accessor);
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var driverId = Guid.NewGuid();
            var request = new SupportMessage
            {
                Title = "طلبات - اطلب أي شيء", ErrandRequestKey = Guid.NewGuid(),
                ErrandStatus = ErrandStatus.Purchased, ErrandDriverUserId = driverId,
                ErrandItemPrice = 1000m, ErrandDeliveryFee = 100m,
                ErrandPurchaseCost = 800m, ErrandReceiptReference = "R-1"
            };
            app.SupportMessages.Add(request);
            await app.SaveChangesAsync();
            var floatAccount = await ledger.GetOrCreateUserAccountAsync(driverId, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Driver Float");
            var goods = await ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.ErrandGoodsInTransit, "Goods", AccountType.Asset);
            var vault = await ledger.GetOrCreateSystemAccountAsync(
                SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = $"ErrandPurchase-{request.Id}",
                ReferenceType = "ErrandPurchase", ReferenceId = request.Id.ToString(),
                Entries = new()
                {
                    new() { AccountId = goods.Id, Debit = 800m },
                    new() { AccountId = floatAccount.Id, Credit = 800m }
                }
            });
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "seed-photo-test-vault",
                Entries = new()
                {
                    new() { AccountId = floatAccount.Id, Debit = 800m },
                    new() { AccountId = vault.Id, Credit = 800m }
                }
            });
            var transactionCount = await accounting.JournalTransactions.CountAsync();
            var service = new ErrandSettlementService(app, accounting, ledger, null);

            Assert.True((await service.RecordPurchaseAsync(request, 800m, "R-1",
                "receipt-photo-one", driverId, "Delivery")).Success);
            await app.Entry(request).ReloadAsync();
            Assert.Equal(ErrandStatus.Purchased, request.ErrandStatus);
            Assert.Equal(800m, request.ErrandPurchaseCost);
            Assert.Equal("receipt-photo-one", request.ErrandReceiptPhotoToken);

            Assert.True((await service.RecordPurchaseAsync(request, 800m, "R-1",
                "receipt-photo-retry", driverId, "Delivery")).Success);
            await app.Entry(request).ReloadAsync();
            Assert.Equal("receipt-photo-one", request.ErrandReceiptPhotoToken);
            Assert.Equal(transactionCount, await accounting.JournalTransactions.CountAsync());
        }
    }
}
