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
        Task UpdateDeliveryLocation(Guid uid, (decimal Lat, decimal Lng) loc);
        Task<(Guid Id, int Distance)> PickBestDelivery((decimal Lat, decimal Lng, int MerchantId)[] allMerchantStops);
        Task AddOrder(Guid uid, int oid, ShippingOrderDto[] merchantLocations, ShippingOrderDto customerLoction);
        Task RemoveOrder(Guid uid, int oid, int? mid = null);

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
            // TODO: check correct loading of driver locations and default locations
            var deliveryUsers = (await _userService.ListFromRoles(AppRoleName.Delivery.ToString()))
                                                    .Where(x => x.IsActive)
                                                    .Select(x => new { x.Id, x.FullName })
                                                    .ToArray();
            var result = new List<(Guid Id, int Distance)>();
            foreach (var du in deliveryUsers)
            {
                var s = await GetDeliveryStatus(du.Id);
                if (!s.LastLocationUpdatedAt.HasValue ||
                    s.LastLocationUpdatedAt.Value < DateTime.UtcNow.AddMinutes(-2))
                    continue;

                var deliveryTrip = allMerchantStops.Select(t => new { Distance = s.FreeOnStop.Loc.DistanceInMeters((t.Lat, t.Lng)), Location = t }).ToArray();
                var totalDistance = deliveryTrip.Sum(x => x.Distance);
                result.Add((du.Id, (int)totalDistance));
            }

            return result.OrderBy(x => x.Distance).FirstOrDefault();
        }


        public async Task UpdateDeliveryLocation(Guid uid, (decimal Lat, decimal Lng) loc)
        {
            var s = await GetDeliveryStatus(uid);
            s.Loc = loc;
            s.LastLocationUpdatedAt = DateTime.UtcNow;
            SetDeliveryStatus(uid, s);
        }

        public async Task AddOrder(Guid uid, int oid, ShippingOrderDto[] merchantLocations, ShippingOrderDto customerLoction)
        {
            var s = await GetDeliveryStatus(uid);

            var bestTripPath = FindBestTrip(s.FreeOnStop, merchantLocations, customerLoction);
            //var bestTripPath = new List<ShippingOrderDto>();
            //bestTripPath.AddRange(merchantLocations);
            //bestTripPath.Add(customerLoction);

            s.PendingOrders.AddRange(bestTripPath);

            SetDeliveryStatus(uid, s);

            // Store to DB
            int i = 0;
            foreach (var item in bestTripPath)
            {
                i += 1;
                Insert(new ShippingOrder { OrderId = oid, Index = i, DriverId = uid, MerchantId = item.MerchantId, CustomerId = item.CustomerId, Lat = item.Lat, Lng = item.Lng });
            }
            await _uow.SaveChangesAsync();
        }
        public async Task RemoveOrder(Guid uid, int oid, int? mid = null)
        {
            var s = await GetDeliveryStatus(uid);
            if (!s.PendingOrders.Any(x => x.OrderId == oid))
                return;

            var mOrders = s.PendingOrders.Where(x => x.OrderId == oid && x.MerchantId == mid);
            if (mOrders.Any())
                s.Loc = mOrders.LastOrDefault().Loc;

            s.PendingOrders.RemoveAll(x => x.OrderId == oid && x.MerchantId == mid);
            SetDeliveryStatus(uid, s);

            var completedStops = await Queryable()
                .Where(x => x.OrderId == oid && x.DriverId == uid && x.MerchantId == mid && !x.CompletedDate.HasValue)
                .ToArrayAsync();
            foreach (var stop in completedStops)
                stop.CompletedDate = DateTime.UtcNow;
            await _uow.SaveChangesAsync();
        }


        public List<ShippingOrderDto> FindBestTrip(ShippingOrderDto start, ShippingOrderDto[] stops, ShippingOrderDto end)
        {
            var allPossibleTrips = GeoHelper.Permute(stops);

            foreach (var trip in allPossibleTrips)
            {
                trip.Insert(0, start);
                trip.Add(end);
            }

            var tripWithDistances = allPossibleTrips.OrderBy(x => x.Distance());

            return tripWithDistances.FirstOrDefault()
                                    .Skip(1) // Skip starting point (Free on location)
                                    .ToList();
        }

        private void SetDeliveryStatus(Guid uid, DeliveryStatus status) =>
            _cache.Set($"DeliveryStatus_{uid}", status);

        private async Task<DeliveryStatus> GetDeliveryStatus(Guid uid)
        {
            if (_cache.TryGetValue($"DeliveryStatus_{uid}", out DeliveryStatus result))
                return result;


            // Reload from DB
            var shippingOrders = await Queryable().Where(x => x.DriverId == uid && !x.CompletedDate.HasValue)
                                                  .OrderBy(x => x.Index)
                                                  .Select(x => new ShippingOrderDto
                                                  {
                                                      Id = x.Id,
                                                      OrderId = x.OrderId,
                                                      DriverId = x.DriverId,
                                                      MerchantId = x.MerchantId,
                                                      CustomerId = x.CustomerId,
                                                      Lat = x.Lat,
                                                      Lng = x.Lng,
                                                  })
                                                  .ToListAsync();

            var s = new DeliveryStatus
            {
                Loc = shippingOrders.FirstOrDefault()?.Loc ?? (37.05637741088867m, 37.33407211303711m),
                PendingOrders = shippingOrders
            };
            SetDeliveryStatus(uid, s);
            return s;
        }
    }

    public static class GeoHelper
    {
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
