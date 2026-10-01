using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using App.Shared.Services.Extentions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Services;
using Modules.Orders.Entities;

namespace App.BackgroundTasks
{
    public class OrderNotificationOutboxWorker : SolScheduledService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<OrderNotificationOutboxWorker> _logger;

        public OrderNotificationOutboxWorker(
            IServiceProvider services,
            ILogger<OrderNotificationOutboxWorker> logger)
            : base(TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(20), logger, nameof(OrderNotificationOutboxWorker))
        {
            _services = services ?? throw new ArgumentNullException(nameof(services));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            using var scope = _services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var now = DateTime.UtcNow;
            var candidateIds = await db.OrderOutboxMessages
                .AsNoTracking()
                .Where(x => x.ProcessedAtUtc == null &&
                            (x.NextAttemptAtUtc == null || x.NextAttemptAtUtc <= now) &&
                            (x.LockedUntilUtc == null || x.LockedUntilUtc < now))
                .OrderBy(x => x.Id)
                .Select(x => x.Id)
                .Take(20)
                .ToListAsync(cancellationToken);

            foreach (var id in candidateIds)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await ProcessOneAsync(scope.ServiceProvider, db, id, cancellationToken);
            }
        }

        private async Task ProcessOneAsync(
            IServiceProvider services,
            OrdersDbContext db,
            long id,
            CancellationToken cancellationToken)
        {
            var now = DateTime.UtcNow;
            var lockId = Guid.NewGuid();
            var claimed = await db.OrderOutboxMessages
                .Where(x => x.Id == id && x.ProcessedAtUtc == null &&
                            (x.NextAttemptAtUtc == null || x.NextAttemptAtUtc <= now) &&
                            (x.LockedUntilUtc == null || x.LockedUntilUtc < now))
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(x => x.LockId, (Guid?)lockId)
                    .SetProperty(x => x.LockedUntilUtc, (DateTime?)now.AddMinutes(5))
                    .SetProperty(x => x.AttemptCount, x => x.AttemptCount + 1), cancellationToken);

            if (claimed != 1)
                return;

            var message = await db.OrderOutboxMessages
                .FirstAsync(x => x.Id == id && x.LockId == lockId, cancellationToken);

            try
            {
                await DispatchAsync(services, db, message, cancellationToken);
                message.ProcessedAtUtc = DateTime.UtcNow;
                message.NextAttemptAtUtc = null;
                message.LastError = null;
                message.LockId = null;
                message.LockedUntilUtc = null;
            }
            catch (Exception ex)
            {
                var retryMinutes = Math.Min(60, Math.Pow(2, Math.Min(message.AttemptCount, 6)));
                message.NextAttemptAtUtc = DateTime.UtcNow.AddMinutes(retryMinutes);
                message.LastError = ex.ToString().Length <= 2000 ? ex.ToString() : ex.ToString().Substring(0, 2000);
                message.LockId = null;
                message.LockedUntilUtc = null;
                _logger.LogError(ex,
                    "Order notification outbox message {MessageId} ({BusinessKey}) failed on attempt {AttemptCount}.",
                    message.Id, message.BusinessKey, message.AttemptCount);
            }

            await db.SaveChangesAsync(cancellationToken);
        }

        private static async Task DispatchAsync(
            IServiceProvider services,
            OrdersDbContext db,
            OrderOutboxMessage message,
            CancellationToken cancellationToken)
        {
            var order = await db.Orders
                .AsNoTracking()
                .Include(x => x.OrderDetails)
                .FirstOrDefaultAsync(x => x.Id == message.OrderId, cancellationToken)
                ?? throw new InvalidOperationException($"Order {message.OrderId} no longer exists.");

            var notificationService = services.GetRequiredService<INotificationService>();
            var merchantService = services.GetRequiredService<IMerchantService>();

            if (message.EventType == OrderOutboxMessage.MerchantNewOrder)
            {
                if (!int.TryParse(message.Payload, out var merchantId))
                    throw new InvalidOperationException($"Outbox message {message.Id} has an invalid merchant payload.");

                var ownerId = await merchantService.GetOwnerId(merchantId);
                var details = order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray();
                await notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, order.Id, details);
                return;
            }

            if (message.EventType == OrderOutboxMessage.AdminAcceptedMerchant)
            {
                if (!int.TryParse(message.Payload, out var merchantId))
                    throw new InvalidOperationException($"Outbox message {message.Id} has an invalid merchant payload.");

                var ownerId = await merchantService.GetOwnerId(merchantId);
                var details = order.OrderDetails.Where(x => x.MerchantId == merchantId).ToArray();
                if (details.Length > 0)
                    await notificationService.SendMerchantNewOrderRecived(new[] { ownerId }, order.Id, details);
                return;
            }

            if (message.EventType == OrderOutboxMessage.AdminAcceptedAdmins)
            {
                var userManager = services.GetRequiredService<UserManager<AppUser>>();
                var adminIds = (await userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString()))
                    .Where(x => x.IsActive)
                    .Select(x => x.Id)
                    .ToArray();

                if (adminIds.Length > 0)
                    await notificationService.SendAdminMerchantDecision(
                        adminIds, order.Id, true, "إدارة جيتك", message.Payload);
                return;
            }

            if (message.EventType == OrderOutboxMessage.AdminNewOrder)
            {
                var merchantIds = order.OrderDetails.Select(x => x.MerchantId).Distinct().ToArray();
                var hasExternalMerchant = await merchantService.Queryable()
                    .AnyAsync(x => merchantIds.Contains(x.Id) && x.MerchantKind != MerchantKind.DarkStore, cancellationToken);
                var userManager = services.GetRequiredService<UserManager<AppUser>>();
                var adminIds = (await userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString()))
                    .Where(x => x.IsActive)
                    .Select(x => x.Id)
                    .ToArray();

                if (adminIds.Length > 0)
                    await notificationService.SendAdminNewOrder(adminIds, order.Id, hasExternalMerchant);
                return;
            }

            throw new InvalidOperationException($"Unsupported order outbox event type '{message.EventType}'.");
        }
    }
}
