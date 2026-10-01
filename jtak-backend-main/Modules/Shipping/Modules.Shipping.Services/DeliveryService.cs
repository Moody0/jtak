using App.Shared.Data.MultiContext;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shipping.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Shipping.Entities;
using Solf.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Shipping.Services
{
    public interface IDeliveryService : ISolService<ShippingOrder, ShippingOrderDto>
    {
        Task UpdateDeliveryLocation(Guid uid, (decimal Lat, decimal Lng) loc, double? heading = null, double? speed = null, DateTime? capturedAtUtc = null);
        Task<DeliveryStatus> GetDeliveryStatus(Guid uid);
        Task<Guid[]> GetOnlineDeliveryIds();
        Task SetDutyStatus(Guid uid, bool isOnline);
        Task<(Guid Id, int Distance)> PickBestDelivery((decimal Lat, decimal Lng, int MerchantId)[] allMerchantStops);
        Task AddOrder(Guid uid, int oid, ShippingOrderDto[] merchantLocations, ShippingOrderDto customerLoction);
        Task RemoveOrder(Guid uid, int oid, int? mid = null);
        Task<List<ShippingOrderDto>> GetOrderStops(int orderId);
        Task CompensateOrderStops(Guid uid, int oid);
    }
    public class DeliveryService : SolService<ShippingOrder, ShippingOrderDto>, IDeliveryService
    {
        private readonly IMemoryCache _cache;
        private readonly IUserService _userService;
        private readonly IShippingUnitOfWork _uow;
        public DeliveryService(
            ITrackableRepository<ShippingOrder, ShippingDbContext> shippingOrderRepo,
            IShippingUnitOfWork uow,
            IMemoryCache cache,
            IUserService userServuce) : base(shippingOrderRepo)
        {
            _uow = uow;
            _cache = cache;
            _userService = userServuce;
        }

        public async Task<(Guid Id, int Distance)> PickBestDelivery((decimal Lat, decimal Lng, int MerchantId)[] allMerchantStops)
        {
            var deliveryUsers = (await _userService.ListFromRoles(AppRoleName.Delivery.ToString()))
                                                    .Where(x => x.IsActive)
                                                    .Select(x => new { x.Id, x.FullName })
                                                    .ToArray();
            if (allMerchantStops == null || allMerchantStops.Length == 0 || deliveryUsers.Length == 0)
                return default;

            var candidates = new List<(Guid Id, int SequentialDistance, int Score)>();

            foreach (var du in deliveryUsers)
            {
                var s = await GetDeliveryStatus(du.Id);
                if (!s.IsOnline) continue;

                // Active orders on this courier
                var activeOrders = s.PendingOrders.Where(p => p.CompletedDate == null).Select(p => p.OrderId).Distinct().Count();

                // Heavy penalty for couriers already handling 3+ active deliveries (capacity cap)
                var loadPenalty = activeOrders switch
                {
                    0 => 0,
                    1 => 1500,
                    2 => 3500,
                    _ => 12000
                };

                // Location freshness & stale GPS check
                if (!s.LastLocationUpdatedAt.HasValue || s.LastLocationUpdatedAt.Value < DateTime.UtcNow.AddMinutes(-30))
                    continue;

                var hasFreshGps = s.LastLocationUpdatedAt.Value >= DateTime.UtcNow.AddMinutes(-10);
                var freshnessPenalty = hasFreshGps ? 0 : 3000;

                // Calculate realistic sequential pickup route distance
                int routeDistance = 0;
                if (allMerchantStops.Length == 1)
                {
                    routeDistance = (int)s.FreeOnStop.Loc.DistanceInMeters((allMerchantStops[0].Lat, allMerchantStops[0].Lng));
                }
                else if (allMerchantStops.Length > 1)
                {
                    // Sequential route from courier location through all merchant stops
                    var curr = s.FreeOnStop.Loc;
                    var remaining = allMerchantStops.ToList();
                    while (remaining.Count > 0)
                    {
                        var nearest = remaining.OrderBy(m => curr.DistanceInMeters((m.Lat, m.Lng))).First();
                        routeDistance += (int)curr.DistanceInMeters((nearest.Lat, nearest.Lng));
                        curr = (nearest.Lat, nearest.Lng);
                        remaining.Remove(nearest);
                    }
                }

                var totalScore = routeDistance + loadPenalty + freshnessPenalty;
                candidates.Add((du.Id, routeDistance, totalScore));
            }

            var best = candidates.OrderBy(c => c.Score).FirstOrDefault();
            return (best.Id, best.SequentialDistance);
        }


        public async Task UpdateDeliveryLocation(Guid uid, (decimal Lat, decimal Lng) loc, double? heading = null, double? speed = null, DateTime? capturedAtUtc = null)
        {
            var s = await GetDeliveryStatus(uid);
            var captured = capturedAtUtc ?? DateTime.UtcNow;
            captured = captured.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(captured, DateTimeKind.Utc) : captured.ToUniversalTime();
            // Out-of-order heartbeat requests must not move the courier backwards.
            if (s.LastLocationUpdatedAt.HasValue && captured < s.LastLocationUpdatedAt.Value) return;
            s.Loc = loc;
            if (heading.HasValue) s.Heading = heading.Value;
            if (speed.HasValue) s.Speed = speed.Value;
            s.LastLocationUpdatedAt = captured;
            SetDeliveryStatus(uid, s);

            try
            {
                var duty = await _uow.Context.DriverDuties.FirstOrDefaultAsync(x => x.DriverId == uid);
                if (duty == null)
                {
                    duty = new DeliveryDriverDuty
                    {
                        DriverId = uid,
                        IsOnline = s.IsOnline,
                        ShiftStartedAt = s.ShiftStartedAt,
                        Lat = loc.Lat,
                        Lng = loc.Lng,
                        Heading = heading,
                        Speed = speed,
                        LastLocationUpdatedAt = captured
                    };
                    _uow.Context.DriverDuties.Add(duty);
                }
                else
                {
                    duty.Lat = loc.Lat;
                    duty.Lng = loc.Lng;
                    duty.Heading = heading;
                    duty.Speed = speed;
                    duty.LastLocationUpdatedAt = captured;
                }
                await _uow.SaveChangesAsync();
            }
            catch
            {
                // Non-fatal if DB write fails during high-frequency live tracking
            }
        }

        public async Task AddOrder(Guid uid, int oid, ShippingOrderDto[] merchantLocations, ShippingOrderDto customerLoction)
        {
            var s = await GetDeliveryStatus(uid);

            // Idempotency: Check if stops already exist in DB for this order
            var existingStops = await _uow.Context.ShippingOrders
                .Where(x => x.OrderId == oid)
                .OrderBy(x => x.Index)
                .ToListAsync();

            if (existingStops.Any())
            {
                if (existingStops.Any(x => x.DriverId != uid))
                {
                    throw new InvalidOperationException($"Order #{oid} already has a route assigned to another driver.");
                }
                s.PendingOrders.RemoveAll(x => x.OrderId == oid);
                foreach (var st in existingStops.Where(x => !x.CompletedDate.HasValue))
                {
                    s.PendingOrders.Add(new ShippingOrderDto
                    {
                        Id = st.Id,
                        Index = st.Index,
                        OrderId = st.OrderId,
                        DriverId = st.DriverId,
                        MerchantId = st.MerchantId,
                        CustomerId = st.CustomerId,
                        Lat = st.Lat,
                        Lng = st.Lng,
                        StopType = st.StopType,
                        StopTitle = st.StopTitle,
                        IsDarkStore = st.IsDarkStore,
                        VerificationCode = st.VerificationCode,
                        Notes = st.Notes
                    });
                }
                SetDeliveryStatus(uid, s);
                return;
            }

            var bestTripPath = FindBestTrip(s.FreeOnStop, merchantLocations, customerLoction);

            s.PendingOrders.RemoveAll(x => x.OrderId == oid);

            // Store to DB
            int i = 0;
            foreach (var item in bestTripPath)
            {
                i += 1;
                item.Index = i;
                Insert(new ShippingOrder
                {
                    OrderId = oid,
                    Index = i,
                    DriverId = uid,
                    MerchantId = item.MerchantId,
                    CustomerId = item.CustomerId,
                    Lat = item.Lat,
                    Lng = item.Lng,
                    StopType = item.StopType,
                    StopTitle = item.StopTitle,
                    IsDarkStore = item.IsDarkStore,
                    VerificationCode = item.VerificationCode,
                    Notes = item.Notes
                });
            }

            s.PendingOrders.AddRange(bestTripPath);
            SetDeliveryStatus(uid, s);
            try
            {
                await _uow.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                // Only a route written by this same driver is an idempotent
                // retry. Never hide a conflicting route or unrelated DB error.
                var persisted = await _uow.Context.ShippingOrders
                    .Where(x => x.OrderId == oid)
                    .ToListAsync();
                if (!persisted.Any() || persisted.Any(x => x.DriverId != uid))
                {
                    throw;
                }
            }
        }

        public async Task CompensateOrderStops(Guid uid, int oid)
        {
            var s = await GetDeliveryStatus(uid);
            s.PendingOrders.RemoveAll(x => x.OrderId == oid);
            SetDeliveryStatus(uid, s);

            var uncompletedStops = await Queryable()
                .Where(x => x.OrderId == oid && x.DriverId == uid && !x.CompletedDate.HasValue)
                .ToListAsync();
            foreach (var stop in uncompletedStops)
            {
                Delete(stop);
            }
            await _uow.SaveChangesAsync();
        }

        public async Task RemoveOrder(Guid uid, int oid, int? mid = null)
        {
            var s = await GetDeliveryStatus(uid);
            if (!s.PendingOrders.Any(x => x.OrderId == oid))
                return;

            var mOrders = s.PendingOrders.Where(x => x.OrderId == oid && x.MerchantId == mid).ToList();
            if (mOrders.Any())
                s.Loc = mOrders.Last().Loc;

            s.PendingOrders.RemoveAll(x => x.OrderId == oid && x.MerchantId == mid);
            SetDeliveryStatus(uid, s);

            var completedStops = await Queryable()
                .Where(x => x.OrderId == oid && x.DriverId == uid && x.MerchantId == mid && !x.CompletedDate.HasValue)
                .ToArrayAsync();
            foreach (var stop in completedStops)
                stop.CompletedDate = DateTime.UtcNow;
            await _uow.SaveChangesAsync();
        }

        public async Task<List<ShippingOrderDto>> GetOrderStops(int orderId)
        {
            return await Queryable()
                .Where(x => x.OrderId == orderId)
                .OrderBy(x => x.Index)
                .Select(x => new ShippingOrderDto
                {
                    Id = x.Id,
                    Index = x.Index,
                    OrderId = x.OrderId,
                    DriverId = x.DriverId,
                    MerchantId = x.MerchantId,
                    CustomerId = x.CustomerId,
                    CompletedDate = x.CompletedDate,
                    Lat = x.Lat,
                    Lng = x.Lng,
                    StopType = x.StopType,
                    StopTitle = x.StopTitle,
                    IsDarkStore = x.IsDarkStore,
                    VerificationCode = x.VerificationCode,
                    Notes = x.Notes
                })
                .ToListAsync();
        }

        public List<ShippingOrderDto> FindBestTrip(ShippingOrderDto start, ShippingOrderDto[] stops, ShippingOrderDto end)
        {
            // Ensure customer drop-off is marked as Dropoff
            if (end != null)
            {
                end.StopType = ShippingStopType.Dropoff;
            }

            if (stops == null || stops.Length == 0)
                return end != null ? new List<ShippingOrderDto> { end } : new List<ShippingOrderDto>();

            foreach (var stop in stops)
            {
                stop.StopType = ShippingStopType.Pickup;
            }

            // Dark Store stops: Staged & pre-packed items can be prioritized first
            // If stops <= 6, evaluate full permutations
            List<List<ShippingOrderDto>> allPossibleTrips;
            if (stops.Length <= 6)
            {
                allPossibleTrips = GeoHelper.Permute(stops);
            }
            else
            {
                allPossibleTrips = new List<List<ShippingOrderDto>> { GeoHelper.GreedyRoute(start, stops) };
            }

            foreach (var trip in allPossibleTrips)
            {
                if (start != null)
                    trip.Insert(0, start);
                if (end != null)
                    trip.Add(end);
            }

            var bestTrip = allPossibleTrips.OrderBy(x => x.Distance()).FirstOrDefault();
            if (bestTrip == null)
                return end != null ? new List<ShippingOrderDto> { end } : new List<ShippingOrderDto>();

            return start != null ? bestTrip.Skip(1).ToList() : bestTrip;
        }

        private void SetDeliveryStatus(Guid uid, DeliveryStatus status) =>
            _cache.Set($"DeliveryStatus_{uid}", status);

        public async Task<Guid[]> GetOnlineDeliveryIds()
        {
            var drivers = await _userService.ListFromRoles(AppRoleName.Delivery.ToString());
            if (drivers == null) return Array.Empty<Guid>();

            var onlineIds = new List<Guid>();
            foreach (var driver in drivers.Where(x => x.IsActive))
            {
                if ((await GetDeliveryStatus(driver.Id)).IsOnline)
                    onlineIds.Add(driver.Id);
            }

            return onlineIds.ToArray();
        }

        public async Task SetDutyStatus(Guid uid, bool isOnline)
        {
            var s = await GetDeliveryStatus(uid);
            s.IsOnline = isOnline;
            if (isOnline)
            {
                s.ShiftStartedAt ??= DateTime.UtcNow;
            }
            else
            {
                s.ShiftStartedAt = null;
            }
            SetDeliveryStatus(uid, s);

            try
            {
                var duty = await _uow.Context.DriverDuties.FirstOrDefaultAsync(x => x.DriverId == uid);
                if (duty == null)
                {
                    duty = new DeliveryDriverDuty
                    {
                        DriverId = uid,
                        IsOnline = isOnline,
                        ShiftStartedAt = s.ShiftStartedAt,
                        Lat = s.Loc.Lat,
                        Lng = s.Loc.Lng
                    };
                    _uow.Context.DriverDuties.Add(duty);
                }
                else
                {
                    duty.IsOnline = isOnline;
                    duty.ShiftStartedAt = s.ShiftStartedAt;
                }
                await _uow.SaveChangesAsync();
            }
            catch
            {
                // Non-fatal if DB write encounters race condition
            }
        }

        public async Task<DeliveryStatus> GetDeliveryStatus(Guid uid)
        {
            if (_cache.TryGetValue($"DeliveryStatus_{uid}", out DeliveryStatus result))
                return result;

            // Reload from DB - safely defaults to offline if no duty record exists!
            DeliveryDriverDuty duty = null;
            try
            {
                duty = await _uow.Context.DriverDuties.AsNoTracking().FirstOrDefaultAsync(x => x.DriverId == uid);
            }
            catch
            {
                // Fallback for tests or unmigrated contexts
            }

            var shippingOrders = await Queryable().Where(x => x.DriverId == uid && !x.CompletedDate.HasValue)
                                                  .OrderBy(x => x.Index)
                                                  .Select(x => new ShippingOrderDto
                                                  {
                                                      Id = x.Id,
                                                      Index = x.Index,
                                                      OrderId = x.OrderId,
                                                      DriverId = x.DriverId,
                                                      MerchantId = x.MerchantId,
                                                      CustomerId = x.CustomerId,
                                                      CompletedDate = x.CompletedDate,
                                                      Lat = x.Lat,
                                                      Lng = x.Lng,
                                                      StopType = x.StopType,
                                                      StopTitle = x.StopTitle,
                                                      IsDarkStore = x.IsDarkStore,
                                                      VerificationCode = x.VerificationCode,
                                                      Notes = x.Notes
                                                  })
                                                  .ToListAsync();

            var s = new DeliveryStatus
            {
                IsOnline = duty?.IsOnline ?? false,
                ShiftStartedAt = duty?.ShiftStartedAt,
                Heading = duty?.Heading,
                Speed = duty?.Speed,
                LastLocationUpdatedAt = duty?.LastLocationUpdatedAt,
                // A merchant/customer stop is never the driver's GPS position.
                Loc = duty != null ? (duty.Lat, duty.Lng) : (0m, 0m),
                PendingOrders = shippingOrders
            };
            SetDeliveryStatus(uid, s);
            return s;
        }
    }

    public static class GeoHelper
    {
        public static List<ShippingOrderDto> GreedyRoute(ShippingOrderDto start, ShippingOrderDto[] stops)
        {
            var result = new List<ShippingOrderDto>();
            var unvisited = stops.ToList();
            var curr = start.Loc;
            while (unvisited.Count > 0)
            {
                var nearest = unvisited.OrderBy(s => curr.DistanceInMeters(s.Loc)).First();
                result.Add(nearest);
                curr = nearest.Loc;
                unvisited.Remove(nearest);
            }
            return result;
        }

        public static double Distance(this List<ShippingOrderDto> stops)
        {
            if (stops.Count <= 1)
                return 0;

            var distance = 0d;
            var prevStop = stops.FirstOrDefault();
            stops = stops.Skip(1).ToList();
            foreach (var stop in stops)
            {
                distance += prevStop.Loc.DistanceInMeters(stop.Loc);
                prevStop = stop;
            }
            return distance;
        }
        public static List<List<ShippingOrderDto>> Permute(ShippingOrderDto[] stops)
        {
            var list = new List<List<ShippingOrderDto>>();
            return DoPermute(stops, 0, stops.Length - 1, list);
        }

        static List<List<ShippingOrderDto>> DoPermute(ShippingOrderDto[] nums, int start, int end, List<List<ShippingOrderDto>> list)
        {
            if (start == end)
            {
                // We have one of our possible n! solutions,
                // add it to the list.
                list.Add(new List<ShippingOrderDto>(nums));
            }
            else
            {
                for (var i = start; i <= end; i++)
                {
                    Swap(ref nums[start], ref nums[i]);
                    DoPermute(nums, start + 1, end, list);
                    Swap(ref nums[start], ref nums[i]);
                }
            }

            return list;
        }

        static void Swap(ref ShippingOrderDto a, ref ShippingOrderDto b)
        {
            var temp = a;
            a = b;
            b = temp;
        }


        // Scaling Factor
        private const double sf = Math.PI / 180;
        // Earth Radius In Meteres
        private const int er = 6371000;
        public static double DistanceInMeters(this (decimal Lat, decimal Lng) thisloc, (decimal Lat, decimal Lng) loc) =>
            er * Math.Acos(Math.Sin((double)thisloc.Lat * sf) * Math.Sin((double)loc.Lat * sf) +
                 Math.Cos((double)thisloc.Lat * sf) * Math.Cos((double)loc.Lat * sf) * Math.Cos(((double)thisloc.Lng - (double)loc.Lng) * sf));
    }
}
