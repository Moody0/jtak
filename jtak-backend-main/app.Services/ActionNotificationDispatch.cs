using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using App.Shared.Entities;
using App.Shared.Services.Helpers;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace App.Shared.Services
{
    public partial class NotificationService
    {
        public static string ActionDispatchKey(string eventKey, Guid userId, string audience) =>
            Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{audience ?? "shared"}|{userId:D}|{eventKey}"))).ToLowerInvariant();

        private async Task SendActionNotificationAsync(App.Shared.Entities.Notification source, Guid[] users)
        {
            foreach (var userId in users)
            {
                var key = ActionDispatchKey(source.EventKey, userId, source.AudienceApp);
                var db = _unitOfWork.Context;
                var notification = await db.Notifications.AsNoTracking().FirstOrDefaultAsync(x => x.DispatchKey == key);
                if (notification == null)
                {
                    notification = new App.Shared.Entities.Notification
                    {
                        TitleAr = source.TitleAr, TitleEn = source.TitleEn, TitleTr = source.TitleTr,
                        TextAr = source.TextAr, TextEn = source.TextEn, TextTr = source.TextTr,
                        Image = source.Image, Url = source.Url, Topic = source.Topic,
                        NotificationType = source.NotificationType, EntityData = source.EntityData,
                        DispatchKey = key, AudienceApp = source.AudienceApp,
                        NotificationMessages = new List<NotificationMessage> { new NotificationMessage { UserId = userId } }
                    };
                    db.Notifications.Add(notification);
                    try
                    {
                        // Notification history and its recipient commit together.
                        await _unitOfWork.SaveChangesAsync();
                    }
                    catch (DbUpdateException)
                    {
                        // A concurrent caller may have inserted the same event.
                        foreach (var recipient in notification.NotificationMessages)
                            db.Entry(recipient).State = EntityState.Detached;
                        db.Entry(notification).State = EntityState.Detached;
                        notification = await db.Notifications.AsNoTracking().FirstOrDefaultAsync(x => x.DispatchKey == key);
                        if (notification == null) throw;
                    }
                }
                await TryDispatchActionAsync(notification.Id, CancellationToken.None);
            }
        }

        public async Task RetryPendingNotificationsAsync(CancellationToken cancellationToken)
        {
            var now = DateTime.UtcNow;
            var ids = await _unitOfWork.Context.Notifications.AsNoTracking()
                .Where(x => x.DispatchKey != null && x.PushSentAtUtc == null &&
                    (x.PushNextAttemptAtUtc == null || x.PushNextAttemptAtUtc <= now) &&
                    (x.PushLockedUntilUtc == null || x.PushLockedUntilUtc <= now))
                .OrderBy(x => x.Id).Select(x => x.Id).Take(50).ToArrayAsync(cancellationToken);
            foreach (var id in ids)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await TryDispatchActionAsync(id, cancellationToken);
            }
        }

        private async Task TryDispatchActionAsync(int id, CancellationToken cancellationToken)
        {
            var db = _unitOfWork.Context;
            var now = DateTime.UtcNow;
            var lockId = Guid.NewGuid();
            var claimed = await db.Notifications.Where(x => x.Id == id && x.PushSentAtUtc == null &&
                (x.PushNextAttemptAtUtc == null || x.PushNextAttemptAtUtc <= now) &&
                (x.PushLockedUntilUtc == null || x.PushLockedUntilUtc <= now))
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(x => x.PushLockId, (Guid?)lockId)
                    .SetProperty(x => x.PushLockedUntilUtc, (DateTime?)now.AddMinutes(5))
                    .SetProperty(x => x.PushAttemptCount, x => x.PushAttemptCount + 1), cancellationToken);
            if (claimed != 1) return;
            var n = await db.Notifications.AsNoTracking().Include(x => x.NotificationMessages)
                .SingleAsync(x => x.Id == id, cancellationToken);
            try
            {
                var recipient = n.NotificationMessages.Single().UserId;
                var baseTopic = GetUserTopic(recipient).ToString();
                if (!string.IsNullOrWhiteSpace(n.AudienceApp)) baseTopic += "_" + n.AudienceApp;
                foreach (var language in AppOptions.SupportedLanguages.Distinct())
                {
                    var image = string.IsNullOrWhiteSpace(n.Image) ? null : AppDomainHelper.ApiUrl + n.Image;
                    var message = new Message
                    {
                        Topic = $"{baseTopic}_{language}",
                        Notification = new FirebaseAdmin.Messaging.Notification
                        { Title = n.GetTitle(language), Body = n.GetText(language), ImageUrl = image },
                        Data = n.GetPayload(language),
                        Android = new AndroidConfig
                        {
                            Priority = Priority.High,
                            Notification = new AndroidNotification
                            {
                                Tag = n.DispatchKey, Sound = "default", Icon = "notification_icon",
                                Priority = NotificationPriority.MAX, EventTimestamp = n.CreatedDate
                            }
                        },
                        Apns = new ApnsConfig
                        {
                            Headers = new Dictionary<string, string> { ["apns-collapse-id"] = n.DispatchKey },
                            Aps = new Aps { Sound = "default", MutableContent = true },
                            FcmOptions = new ApnsFcmOptions { ImageUrl = image }
                        }
                    };
                    await SendActionPushAsync(message, cancellationToken);
                }
                await db.Notifications.Where(x => x.Id == id && x.PushLockId == lockId)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(x => x.PushSentAtUtc, (DateTime?)DateTime.UtcNow)
                        .SetProperty(x => x.PushLockId, (Guid?)null)
                        .SetProperty(x => x.PushLockedUntilUtc, (DateTime?)null)
                        .SetProperty(x => x.PushNextAttemptAtUtc, (DateTime?)null), cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
            catch (Exception ex)
            {
                // Transport acknowledgement is not exactly-once delivery. A retry
                // reuses the same platform tag and client event key, never a new alert.
                var retryAt = DateTime.UtcNow.AddSeconds(Math.Min(300, 5 * Math.Pow(2, Math.Min(n.PushAttemptCount, 6))));
                await db.Notifications.Where(x => x.Id == id && x.PushLockId == lockId)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(x => x.PushLockId, (Guid?)null)
                        .SetProperty(x => x.PushLockedUntilUtc, (DateTime?)null)
                        .SetProperty(x => x.PushNextAttemptAtUtc, (DateTime?)retryAt), cancellationToken);
                _logger.LogWarning(ex, "Action notification {NotificationId} will be retried without creating another history entry.", id);
            }
        }

        protected virtual Task<string> SendActionPushAsync(Message message, CancellationToken cancellationToken) =>
            EnsureFirebaseMessaging().SendAsync(message, cancellationToken);
    }
}
