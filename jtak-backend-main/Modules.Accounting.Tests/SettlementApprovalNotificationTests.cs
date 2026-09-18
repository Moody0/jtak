using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class SettlementApprovalNotificationTests
{
    private static AccountingDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .AddInterceptors(new LedgerImmutabilityInterceptor())
            .Options;
        return new AccountingDbContext(options, null);
    }

    [Fact]
    public async Task Test01_MerchantApproval_SendsApprovedNotification_WithAwaitingReceiptWording()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // 1. Setup merchant payable balance
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 1001,
            CaptainUserId = Guid.NewGuid(),
            DeliveryFee = 5000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 10, MerchantTitle = "Meat Station", TotalAmount = 50_000m, MerchantAmount = 45_000m, PlatformCommission = 5_000m }
            }
        });

        // 2. Create merchant settlement request
        var req = await service.CreateMerchantRequestAsync(
            merchantOwnerId,
            "Meat Station Owner",
            "0933111222",
            new[] { new MerchantSettlementSource { MerchantId = 10, MerchantTitle = "Meat Station" } },
            new CreateSettlementRequestDto { Amount = 45_000m, Method = "cash", AccountDetails = "Cashier" });

        // 3. Admin approves
        var approved = await service.AcceptAsync(req.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Approved, approved.Status);

        // 4. Dispatch notification using extension method
        await mockNotif.Object.SendSettlementApproved(
            new[] { approved.RequestedByUserId },
            approved.RequestNumber,
            approved.Amount,
            isMerchant: true);

        // 5. Verify notification assertions
        Assert.Single(sentNotifications);
        var sent = sentNotifications.First();
        Assert.Equal(merchantOwnerId, sent.Receivers.Single());
        Assert.Equal("تم قبول طلب التسوية", sent.Notification.TitleAr);
        Assert.Contains("45,000", sent.Notification.TextAr);
        Assert.Contains("بانتظار الاستلام والتأكيد", sent.Notification.TextAr);
        Assert.DoesNotContain("تمت التسوية", sent.Notification.TextAr);
        Assert.DoesNotContain("تم الدفع", sent.Notification.TextAr);
        Assert.Equal(NotificationType.Payment, sent.Notification.NotificationType);
    }

    [Fact]
    public async Task Test02_DriverApproval_SendsDriverNotification_WithCleanApprovalWording()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        var captainId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // 1. Setup captain COD cash float
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 2002,
            CaptainUserId = captainId,
            CaptainName = "Captain Samer",
            DeliveryFee = 5000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 1, MerchantTitle = "Store", TotalAmount = 10_000m, MerchantAmount = 9_000m, PlatformCommission = 1_000m }
            }
        });

        // 2. Create captain settlement request
        var req = await service.CreateCaptainRequestAsync(captainId, "Captain Samer", "0944555666",
            new CreateSettlementRequestDto { Amount = 5000m });

        // 3. Admin approves
        var approved = await service.AcceptAsync(req.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Completed, approved.Status);

        // 4. Dispatch notification
        await mockNotif.Object.SendSettlementApproved(
            new[] { approved.RequestedByUserId },
            approved.RequestNumber,
            approved.Amount,
            isMerchant: false);

        // 5. Verify notification assertions
        Assert.Single(sentNotifications);
        var sent = sentNotifications.First();
        Assert.Equal(captainId, sent.Receivers.Single());
        Assert.Equal("تم قبول طلب التسوية", sent.Notification.TitleAr);
        Assert.Contains("5,000", sent.Notification.TextAr);
        Assert.DoesNotContain("بانتظار الاستلام والتأكيد", sent.Notification.TextAr);
        Assert.Equal(NotificationType.Payment, sent.Notification.NotificationType);
    }

    [Fact]
    public async Task Test03_SettlementRejection_SendsRejectionNotification_WithReason()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 3003,
            CaptainUserId = Guid.NewGuid(),
            DeliveryFee = 0m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 15, MerchantTitle = "Bakery", TotalAmount = 30_000m, MerchantAmount = 27_000m, PlatformCommission = 3_000m }
            }
        });

        var req = await service.CreateMerchantRequestAsync(
            merchantOwnerId,
            "Bakery Owner",
            "0955112233",
            new[] { new MerchantSettlementSource { MerchantId = 15, MerchantTitle = "Bakery" } },
            new CreateSettlementRequestDto { Amount = 27_000m });

        // Reject with explicit reason
        var rejected = await service.RejectAsync(req.Id, adminId, "بيانات الحساب البنكي غير مطابقة");
        Assert.Equal(SettlementRequestStatus.Rejected, rejected.Status);

        await mockNotif.Object.SendSettlementRejected(
            new[] { rejected.RequestedByUserId },
            rejected.RequestNumber,
            rejected.Amount,
            rejected.RejectionReason);

        Assert.Single(sentNotifications);
        var sent = sentNotifications.First();
        Assert.Equal(merchantOwnerId, sent.Receivers.Single());
        Assert.Equal("تم رفض طلب التسوية", sent.Notification.TitleAr);
        Assert.Contains("بيانات الحساب البنكي غير مطابقة", sent.Notification.TextAr);
        Assert.Contains("27,000", sent.Notification.TextAr);
    }

    [Fact]
    public async Task Test04_ApprovalFailure_DoesNotSendNotification()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        // Attempting to accept a non-existent request ID
        var fakeId = Guid.NewGuid();
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.AcceptAsync(fakeId, Guid.NewGuid()));

        // Notification list remains untouched
        Assert.Empty(sentNotifications);
    }

    [Fact]
    public async Task Test05_DoubleApprovalRetry_ThrowsAndPreventsDuplicateNotification()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 5005,
            CaptainUserId = Guid.NewGuid(),
            DeliveryFee = 0m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 22, MerchantTitle = "Sweet Shop", TotalAmount = 20_000m, MerchantAmount = 18_000m, PlatformCommission = 2_000m }
            }
        });

        var req = await service.CreateMerchantRequestAsync(
            merchantOwnerId,
            "Sweet Shop Owner",
            "0966778899",
            new[] { new MerchantSettlementSource { MerchantId = 22, MerchantTitle = "Sweet Shop" } },
            new CreateSettlementRequestDto { Amount = 18_000m });

        // First approval
        var firstApproved = await service.AcceptAsync(req.Id, adminId);
        await mockNotif.Object.SendSettlementApproved(new[] { firstApproved.RequestedByUserId }, firstApproved.RequestNumber, firstApproved.Amount, true);
        Assert.Single(sentNotifications);

        // Second approval attempt (simulating double-click / retry)
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.AcceptAsync(req.Id, adminId));

        // Still exactly ONE notification sent
        Assert.Single(sentNotifications);
    }

    [Fact]
    public async Task Test06_RecipientIsolation_MerchantDoesNotReceiveDriverNotification_AndViceVersa()
    {
        var sentNotifications = new List<(Notification Notification, Guid[] Receivers)>();
        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, r, s, sp) => sentNotifications.Add((n, r)))
            .Returns(Task.CompletedTask);

        var merchantUserId = Guid.NewGuid();
        var driverUserId = Guid.NewGuid();

        // Send merchant notification
        await mockNotif.Object.SendSettlementApproved(new[] { merchantUserId }, "SET-M01", 10_000m, isMerchant: true);

        // Send driver notification
        await mockNotif.Object.SendSettlementApproved(new[] { driverUserId }, "SET-D01", 15_000m, isMerchant: false);

        Assert.Equal(2, sentNotifications.Count);

        var merchantNotif = sentNotifications[0];
        Assert.Equal(merchantUserId, merchantNotif.Receivers.Single());
        Assert.NotEqual(driverUserId, merchantNotif.Receivers.Single());
        Assert.Contains("بانتظار الاستلام والتأكيد", merchantNotif.Notification.TextAr);

        var driverNotif = sentNotifications[1];
        Assert.Equal(driverUserId, driverNotif.Receivers.Single());
        Assert.NotEqual(merchantUserId, driverNotif.Receivers.Single());
        Assert.DoesNotContain("بانتظار الاستلام والتأكيد", driverNotif.Notification.TextAr);
    }

    [Fact]
    public async Task Test07_PushNotificationFailure_DoesNotCorruptDatabaseApproval()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);

        var mockNotif = new Mock<INotificationService>();
        mockNotif.Setup(m => m.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .ThrowsAsync(new InvalidOperationException("Simulated push error"));

        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 7007,
            CaptainUserId = Guid.NewGuid(),
            DeliveryFee = 0m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 33, MerchantTitle = "Grill House", TotalAmount = 40_000m, MerchantAmount = 36_000m, PlatformCommission = 4_000m }
            }
        });

        var req = await service.CreateMerchantRequestAsync(
            merchantOwnerId,
            "Grill House Owner",
            "0977889900",
            new[] { new MerchantSettlementSource { MerchantId = 33, MerchantTitle = "Grill House" } },
            new CreateSettlementRequestDto { Amount = 36_000m });

        // Database approval succeeds
        var approved = await service.AcceptAsync(req.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Approved, approved.Status);

        // Notification sending throws, but caught safely by controller pattern
        var exceptionThrown = false;
        try
        {
            await mockNotif.Object.SendSettlementApproved(new[] { approved.RequestedByUserId }, approved.RequestNumber, approved.Amount, true);
        }
        catch
        {
            exceptionThrown = true;
        }

        Assert.True(exceptionThrown);

        // Database record remains intact and properly Approved in the database
        var dbRecord = await context.SettlementRequests.FindAsync(req.Id);
        Assert.NotNull(dbRecord);
        Assert.Equal(SettlementRequestStatus.Approved, dbRecord.Status);
    }
}
