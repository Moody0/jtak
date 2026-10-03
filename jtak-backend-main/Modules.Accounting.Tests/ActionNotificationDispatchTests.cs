using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using App.Shared.Services.Options;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;
using Modules.Orders.Entities;
using Xunit;
using FcmMessage = FirebaseAdmin.Messaging.Message;

namespace Modules.Accounting.Tests;

public class ActionNotificationDispatchTests
{
    private sealed class Sender : NotificationService
    {
        public readonly List<FcmMessage> Messages;
        public bool FailAfterSending;
        public Sender(AppDbContext db, List<FcmMessage> messages) : base(
            new TrackableRepository<Notification, AppDbContext>(db),
            new Mock<INotificationMessageRepo>().Object,
            Options.Create(new SolAppOptions { DefaultLanguage = "ar", SupportedLanguages = new[] { "ar" } }),
            Options.Create(new NotificationOptions { UserTopicSalt = "test-salt" }), null, null,
            new AppUnitOfWork(db), null, NullLogger<NotificationService>.Instance) => Messages = messages;
        protected override async Task<string> SendActionPushAsync(FcmMessage message, CancellationToken token)
        {
            Messages.Add(message);
            await Task.Delay(10, token);
            if (FailAfterSending) throw new InvalidOperationException("Transport acknowledgement lost");
            return "accepted";
        }
    }

    private sealed class Fixture : IDisposable
    {
        private readonly SqliteConnection _connection = new("Data Source=:memory:");
        private readonly List<AppDbContext> _contexts = new();
        public readonly List<FcmMessage> Messages = new();
        public readonly Guid UserId = Guid.NewGuid();
        public Fixture()
        {
            _connection.Open();
            var db = Context();
            db.Database.EnsureCreated();
            db.Users.Add(new AppUser { Id = UserId, UserName = "qa", FullName = "QA", IsActive = true });
            db.SaveChanges();
        }
        public AppDbContext Context()
        {
            var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_connection).Options, null);
            _contexts.Add(db);
            return db;
        }
        public Sender Service() => new(Context(), Messages);
        public void Dispose() { foreach (var db in _contexts) db.Dispose(); _connection.Dispose(); }
    }

    [Fact]
    public async Task RepeatedCancellation_OneHistoryEntryAndOnePushPerRecipient()
    {
        using var f = new Fixture();
        await f.Service().SendOrderCanceledForNoCourier(new[] { f.UserId, f.UserId }, 60);
        await f.Service().SendOrderCanceledForNoCourier(new[] { f.UserId }, 60);
        using var db = f.Context();
        var n = Assert.Single(await db.Notifications.Include(x => x.NotificationMessages).ToListAsync());
        Assert.Single(n.NotificationMessages);
        Assert.NotNull(n.PushSentAtUtc);
        Assert.Equal(1, n.PushAttemptCount);
        Assert.Contains("10 دقائق", n.TextAr);
        Assert.Contains("10 minutes", n.TextEn);
        Assert.Contains("10 dakika", n.TextTr);
        var push = Assert.Single(f.Messages);
        Assert.EndsWith("_customer_ar", push.Topic);
        Assert.Equal(n.DispatchKey, push.Android.Notification.Tag);
        Assert.Equal(n.DispatchKey, push.Data["EventKey"]);
    }

    [Fact]
    public async Task SameAccountInTwoApps_ReceivesOnlyTheAppropriateScopedEvents()
    {
        using var f = new Fixture();
        await f.Service().SendOrderCanceledForNoCourier(new[] { f.UserId }, 60, "customer");
        await f.Service().SendOrderCanceledForNoCourier(new[] { f.UserId }, 60, "warehouse");
        Assert.Equal(2, f.Messages.Count);
        Assert.Single(f.Messages.Where(x => x.Topic.EndsWith("_customer_ar")));
        Assert.Single(f.Messages.Where(x => x.Topic.EndsWith("_warehouse_ar")));
        Assert.DoesNotContain(f.Messages, x => x.Topic.EndsWith("_delivery_ar"));
    }

    [Fact]
    public async Task LostAcknowledgement_RetryReusesHistoryIdAndPlatformTag()
    {
        using var f = new Fixture();
        var sender = f.Service();
        sender.FailAfterSending = true;
        await sender.SendOrderCanceledForNoCourier(new[] { f.UserId }, 60);
        using var db = f.Context();
        var pending = await db.Notifications.SingleAsync();
        Assert.Null(pending.PushSentAtUtc);
        Assert.NotNull(pending.PushNextAttemptAtUtc);
        await db.Notifications.ExecuteUpdateAsync(x => x.SetProperty(n => n.PushNextAttemptAtUtc, (DateTime?)null));
        await f.Service().RetryPendingNotificationsAsync(CancellationToken.None);
        Assert.Equal(2, f.Messages.Count);
        Assert.Equal(f.Messages[0].Data["Id"], f.Messages[1].Data["Id"]);
        Assert.Equal(f.Messages[0].Android.Notification.Tag, f.Messages[1].Android.Notification.Tag);
        Assert.Equal(f.Messages[0].Apns.Headers["apns-collapse-id"], f.Messages[1].Apns.Headers["apns-collapse-id"]);
        Assert.Equal(1, await f.Context().Notifications.CountAsync());
        Assert.NotNull((await f.Context().Notifications.SingleAsync()).PushSentAtUtc);
    }

    [Fact]
    public async Task ConcurrentCallers_OnlyOneClaimsTheAction()
    {
        using var f = new Fixture();
        await Task.WhenAll(Enumerable.Range(0, 10).Select(_ =>
            f.Service().SendOrderCanceledForNoCourier(new[] { f.UserId }, 60)));
        Assert.Single(f.Messages);
        Assert.Equal(1, await f.Context().Notifications.CountAsync());
    }

    [Fact]
    public async Task DifferentActionsAndNewMatchingRounds_AreNotSuppressed()
    {
        using var f = new Fixture();
        await f.Service().SendCustomerOrderReadyForPickup(new[] { f.UserId }, 60, "QA");
        await f.Service().SendCustomerOrderDelivered(new[] { f.UserId }, 60);
        await f.Service().SendDeliveryNewOrderRecived(new[] { f.UserId }, 60, Array.Empty<OrderDetail>(), 1);
        await f.Service().SendDeliveryNewOrderRecived(new[] { f.UserId }, 60, Array.Empty<OrderDetail>(), 2);
        Assert.Equal(4, f.Messages.Count);
        Assert.Equal(4, f.Messages.Select(x => x.Data["EventKey"]).Distinct().Count());
    }

    [Fact]
    public void DispatchIdentity_IsPerActionRecipientAndApp()
    {
        var user = Guid.NewGuid();
        var a = NotificationService.ActionDispatchKey("cancel:60", user, "customer");
        Assert.Equal(a, NotificationService.ActionDispatchKey("cancel:60", user, "customer"));
        Assert.NotEqual(a, NotificationService.ActionDispatchKey("cancel:61", user, "customer"));
        Assert.NotEqual(a, NotificationService.ActionDispatchKey("cancel:60", user, "warehouse"));
        Assert.NotEqual(a, NotificationService.ActionDispatchKey("cancel:60", Guid.NewGuid(), "customer"));
    }
}
