using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Entities;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using App.Shared.Services.Extentions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Shipping.Services;

namespace App.BackgroundTasks
{
    /// <summary>
    /// Server-owned courier dispatch loop. Offer persistence, not mobile timers,
    /// is the source of truth for who can claim an order.
    /// </summary>
    public sealed class CourierDispatchWorker : SolScheduledService
    {
        private const int DriversPerWave = 3;
        private static readonly TimeSpan OfferDuration = TimeSpan.FromSeconds(25);
        private static readonly TimeSpan LocationFreshness = TimeSpan.FromMinutes(5);

        private readonly IServiceProvider _services;
        private readonly ILogger<CourierDispatchWorker> _logger;

        public CourierDispatchWorker(IServiceProvider services, ILogger<CourierDispatchWorker> logger)
            : base(TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5), logger, nameof(CourierDispatchWorker))
        {
            _services = services ?? throw new ArgumentNullException(nameof(services));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            using var scope = _services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
            var now = DateTime.UtcNow;
            var orderIds = await db.Orders.AsNoTracking()
                .Where(x => x.OrderStatus == OrderStatus.Success &&
                            x.CourierMatchingStartedAtUtc != null &&
                            x.CourierMatchingCompletedAtUtc == null &&
                            (x.DeliveryId == null || x.DeliveryId == Guid.Empty))
                .OrderBy(x => x.CourierMatchingDeadlineAtUtc)
                .Select(x => x.Id)
                .Take(100)
                .ToListAsync(cancellationToken);

            foreach (var orderId in orderIds)
            {
                cancellationToken.ThrowIfCancellationRequested();
                try
                {
                    await ProcessOrderAsync(scope.ServiceProvider, db, orderId, now, cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Courier dispatch processing failed for order {OrderId}.", orderId);
                }
            }
        }

        private async Task ProcessOrderAsync(IServiceProvider services, OrdersDbContext db, int orderId,
            DateTime now, CancellationToken cancellationToken)
        {
            var expiredCount = await db.OrderDispatchOffers
                .Where(x => x.OrderId == orderId && x.Status == OrderDispatchOfferStatus.Offered && x.ExpiresAtUtc <= now)
                .ExecuteUpdateAsync(update => update
                    .SetProperty(x => x.Status, OrderDispatchOfferStatus.TimedOut)
                    .SetProperty(x => x.RespondedAtUtc, (DateTime?)now), cancellationToken);

            var order = await db.Orders.Include(x => x.OrderDetails)
                .FirstOrDefaultAsync(x => x.Id == orderId, cancellationToken);
            if (order == null || order.CourierMatchingCompletedAtUtc.HasValue ||
                order.DeliveryId.HasValue && order.DeliveryId != Guid.Empty)
                return;

            if (!order.CourierMatchingDeadlineAtUtc.HasValue || order.CourierMatchingDeadlineAtUtc <= now)
            {
                await CancelUnassignedOrderAsync(services, db, order, now, cancellationToken);
                return;
            }

            var hasLiveOffer = await db.OrderDispatchOffers.AnyAsync(x =>
                x.OrderId == orderId && x.MatchingRound == order.CourierMatchingRound &&
                x.Status == OrderDispatchOfferStatus.Offered && x.ExpiresAtUtc > now, cancellationToken);
            if (hasLiveOffer) return;

            var matchingDetails = order.OrderDetails.Where(x =>
                x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled).ToArray();
            if (matchingDetails.Length == 0 || matchingDetails.Any(x =>
                    x.OrderDetailStatus != OrderDetailStatus.MerchantAccepted &&
                    x.OrderDetailStatus != OrderDetailStatus.ReadyForPickup))
                return;

            var merchantIds = matchingDetails.Select(x => x.MerchantId).Distinct().ToArray();
            var merchantService = services.GetRequiredService<IMerchantService>();
            var pickupPoints = await merchantService.GetMerchantStops(merchantIds);
            if (pickupPoints.Length == 0) return;

            var pickup = pickupPoints[0];
            var deliveryService = services.GetRequiredService<IDeliveryService>();
            var onlineDrivers = await deliveryService.GetOnlineDeliveryIds();
            if (onlineDrivers.Length == 0) return;

            var alreadyOffered = await db.OrderDispatchOffers.AsNoTracking()
                .Where(x => x.OrderId == orderId && x.MatchingRound == order.CourierMatchingRound)
                .Select(x => x.DriverId)
                .ToListAsync(cancellationToken);
            var excluded = alreadyOffered.ToHashSet();
            var candidates = new System.Collections.Generic.List<(Guid DriverId, double Distance)>();
            foreach (var driverId in onlineDrivers)
            {
                if (excluded.Contains(driverId)) continue;
                var status = await deliveryService.GetDeliveryStatus(driverId);
                if (!status.IsOnline || !status.LastLocationUpdatedAt.HasValue ||
                    status.LastLocationUpdatedAt.Value < now.Subtract(LocationFreshness))
                    continue;

                var activeOrders = status.PendingOrders.Where(x => !x.CompletedDate.HasValue)
                    .Select(x => x.OrderId).Distinct().Count();
                if (activeOrders >= 3) continue;
                var distance = status.Loc.DistanceInMeters((pickup.Lat, pickup.Lng));
                candidates.Add((driverId, distance));
            }

            if (candidates.Count == 0) return; // Retry next tick until the fixed deadline.

            var wave = await db.OrderDispatchOffers.AsNoTracking()
                .Where(x => x.OrderId == orderId && x.MatchingRound == order.CourierMatchingRound)
                .Select(x => (int?)x.WaveNumber)
                .MaxAsync(cancellationToken) ?? 0;
            var selected = candidates.OrderBy(x => x.Distance).Take(DriversPerWave).ToArray();
            var expiresAt = now.Add(OfferDuration);
            foreach (var candidate in selected)
            {
                db.OrderDispatchOffers.Add(new OrderDispatchOffer
                {
                    OrderId = orderId,
                    DriverId = candidate.DriverId,
                    MatchingRound = order.CourierMatchingRound,
                    WaveNumber = wave + 1,
                    OfferedAtUtc = now,
                    ExpiresAtUtc = expiresAt,
                    Status = OrderDispatchOfferStatus.Offered
                });
            }
            await db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Courier dispatch saved {OfferCount} offers for order {OrderId}, round {Round}, wave {Wave}, expiring at {ExpiresAtUtc}.",
                selected.Length, orderId, order.CourierMatchingRound, wave + 1, expiresAt);

            try
            {
                await services.GetRequiredService<INotificationService>()
                    .SendDeliveryNewOrderRecived(selected.Select(x => x.DriverId).ToArray(), orderId, matchingDetails, order.CourierMatchingRound);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                // Push is a wake-up hint, not ownership of the offer. A Firebase
                // outage must not remove a durable offer from the polling API or
                // permanently exclude its driver from this matching round.
                _logger.LogWarning(ex, "Courier dispatch push failed for order {OrderId}, round {Round}, wave {Wave}. Saved offers remain available until {ExpiresAtUtc}.",
                    orderId, order.CourierMatchingRound, wave + 1, expiresAt);
            }
        }

        private async Task CancelUnassignedOrderAsync(IServiceProvider services, OrdersDbContext db,
            Order order, DateTime now, CancellationToken cancellationToken)
        {
            // No claim can succeed past the persisted deadline. Release the catalog
            // reservation first so a transient catalog DB outage is retried next tick.
            await services.GetRequiredService<IInventoryBatchService>()
                .ReleaseReservationAsync(order.Id, reason: "No courier accepted before the matching deadline");

            // This conditional update wins only if a driver has not claimed the order.
            var completed = await db.Orders
                .Where(x => x.Id == order.Id && x.CourierMatchingCompletedAtUtc == null &&
                            (x.DeliveryId == null || x.DeliveryId == Guid.Empty) &&
                            x.CourierMatchingDeadlineAtUtc <= now)
                .ExecuteUpdateAsync(update => update
                    .SetProperty(x => x.CourierMatchingCompletedAtUtc, (DateTime?)now), cancellationToken);
            if (completed == 0) return;

            var affectedDetails = order.OrderDetails.Where(x =>
                x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                x.OrderDetailStatus != OrderDetailStatus.Delivered).ToArray();
            foreach (var detail in affectedDetails)
                detail.OrderDetailStatus = OrderDetailStatus.DeliveryCanceled;

            var orderService = services.GetRequiredService<Modules.Orders.Services.IOrderService>();
            orderService.Log(order.Id, OrderDetailStatus.DeliveryCanceled, affectedDetails);
            await db.SaveChangesAsync(cancellationToken);

            var notification = services.GetRequiredService<INotificationService>();
            // Report the persisted window, including orders created before a policy change.
            var matchingMinutes = order.CourierMatchingStartedAtUtc.HasValue && order.CourierMatchingDeadlineAtUtc.HasValue
                ? Math.Max(1, (int)Math.Round((order.CourierMatchingDeadlineAtUtc.Value -
                    order.CourierMatchingStartedAtUtc.Value).TotalMinutes, MidpointRounding.AwayFromZero))
                : CourierMatchingPolicy.TimeoutMinutes;
            await notification.SendOrderCanceledForNoCourier(new[] { order.UserId }, order.Id,
                matchingMinutes: matchingMinutes);
            var merchantIds = order.OrderDetails.Select(x => x.MerchantId).Distinct().ToArray();
            foreach (var merchantId in merchantIds)
            {
                var ownerId = await services.GetRequiredService<IMerchantService>().GetOwnerId(merchantId);
                if (ownerId != Guid.Empty)
                    await notification.SendOrderCanceledForNoCourier(new[] { ownerId }, order.Id, "warehouse", matchingMinutes);
            }
        }
    }
}
