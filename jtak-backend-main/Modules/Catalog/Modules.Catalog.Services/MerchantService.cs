using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Catalog.Entities;
using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Catalog.Services
{
    public interface IMerchantService : ISolService<Merchant, MerchantDto>
    {
        Task<Merchant> FindAsync(int id);
        Task<int[]> GetValidMerchants(decimal lat, decimal lng);
        Task<int[]> GetSearchableMerchants(decimal lat, decimal lng);
        Task<Dictionary<int, int>> GetMerchantCountsByCategory(int[] categoryIds);
        Task<Guid> GetOwnerId(int id);
        Task<int[]> GetMerchantIds(Guid id);
        Task<(decimal Lat, decimal Lng, int MerchantId)[]> GetMerchantStops(params int[] mids);
        Task<Dictionary<int, MerchantProductDto>> GetActiveMerchantPrices(int mid);
        Task<Dictionary<int, MerchantProductDto>> GetAllMerchantPrices(int mid);
        Task<MerchantProductDto> GetMerchantProductPrice(int mid, int pid);
        Task<bool> SetMerchantPercent(int mid, decimal percent);
        Task<MerchantProductDto> GetBestProductPrice(int pid, int[] mids);
        Task<MerchantProductDto> GetBestProductPrice(int pid, decimal lat, decimal lng);
        Task<MerchantProductDto> GetBestProductPrice(int pid, int[] mids, decimal lat, decimal lng);
        Task<MerchantProductDto> GetBestAlternativeProductPrice(int pid, int[] excludeMids, decimal lat, decimal lng);
        Task<MerchantProductDto[]> GetBestAlternativeProductsPrice(int[] pids, int[] excludeMids, decimal lat, decimal lng);
        Task<Dictionary<int, MerchantProductDto>> GetProductPrices(int pid);
        Task<int> AssignMerchantProducts(int[] mid, MerchantProductAssignDto[] mps);
        Task<int> SetMerchantProductPrices(int[] mid, MerchantProductPriceDto[] mps);
        Task<int> RepriceUsdDenominatedProducts(decimal usdRate);
        Task<(decimal Lat, decimal Lng)[]> GetMerchantLocations(int[] mids);
        Task<decimal> GetUsdRate();
    }
    public class MerchantService : SolService<Merchant, MerchantDto>, IMerchantService
    {
        private readonly IMemoryCache _cache;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepo;
        private readonly ICatalogUnitOfWork _uow;
        private readonly IGenericSettingService _genericSetting;
        public MerchantService(ITrackableRepository<Merchant, CatalogDbContext> r,
            ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepo,
            ICatalogUnitOfWork uow,
            IGenericSettingService genericSetting,
            IMemoryCache cache) : base(r)
        {
            _merchantProductRepo = merchantProductRepo;
            _uow = uow;
            _genericSetting = genericSetting;
            _cache = cache;
        }

        /// <summary>
        /// Current USD rate, with a default fallback of 15,000 SYP when the administrator has not set one yet.
        /// </summary>
        public async Task<decimal> GetUsdRate()
        {
            var setting = await _genericSetting.GetValue<UsdExchangeRateSetting>(UsdExchangeRateSetting.Key);
            var rate = setting?.Rate ?? 0;
            return rate > 0 ? rate : 15000m;
        }

        /// <summary>
        /// Dollar prices carry more precision than the local currency is quoted
        /// in, so a converted figure is rounded to whole units to match the
        /// products that are priced locally by hand.
        /// </summary>
        private static decimal ToLocalPrice(decimal priceUsd, decimal usdRate) =>
            Math.Round(priceUsd * usdRate, 0, MidpointRounding.AwayFromZero);

        public async Task<Merchant> FindAsync(int id) =>
            await Queryable().FirstOrDefaultAsync(x => x.Id == id);

        public async Task<int[]> GetValidMerchants(decimal lat, decimal lng) =>
            await Queryable().AsNoTracking()
                             .WhereInRange(lat, lng)
                             .Select(x => x.Id)
                             .ToArrayAsync();

        /// <summary>
        /// Merchants a customer at this location is allowed to find by searching.
        /// A restaurant sells hot food and stays confined to its delivery
        /// coverage, but a market ships goods and is already browsable from
        /// anywhere in the app, so search must not be the one place that hides
        /// it. Anything that is not a restaurant is therefore searchable
        /// regardless of distance.
        /// </summary>
        public async Task<int[]> GetSearchableMerchants(decimal lat, decimal lng)
        {
            var inRange = await GetValidMerchants(lat, lng);
            var shipsAnywhere = await Queryable().AsNoTracking()
                                                 .Where(x => x.Active &&
                                                             x.DeletionDate == null &&
                                                             x.MerchantKind != MerchantKind.Restaurant)
                                                 .Select(x => x.Id)
                                                 .ToArrayAsync();
            return inRange.Union(shipsAnywhere).ToArray();
        }

        /// <summary>
        /// How many merchants actually sell something in each of the given
        /// categories, counting a category's subcategories as part of it. A
        /// merchant only counts where it has a priced product, because an
        /// unpriced row means it does not really stock the item.
        /// </summary>
        public async Task<Dictionary<int, int>> GetMerchantCountsByCategory(int[] categoryIds)
        {
            var counts = new Dictionary<int, int>();
            if (categoryIds == null || categoryIds.Length == 0)
                return counts;

            var offers = await _merchantProductRepo.Queryable().AsNoTracking()
                                                   .Where(x => x.MerchantPrice > 0 &&
                                                               x.Merchant.Active &&
                                                               x.Merchant.DeletionDate == null &&
                                                               x.Product.Active &&
                                                               x.Product.DeletionDate == null)
                                                   .Select(x => new
                                                   {
                                                       x.MerchantId,
                                                       CategoryId = x.Product.ProductCategoryId,
                                                       ParentId = x.Product.ProductCategory.ParentId
                                                   })
                                                   .ToArrayAsync();

            foreach (var id in categoryIds.Distinct())
            {
                counts[id] = offers.Where(x => x.CategoryId == id || x.ParentId == id)
                                   .Select(x => x.MerchantId)
                                   .Distinct()
                                   .Count();
            }
            return counts;
        }

        public async Task<Dictionary<int, MerchantProductDto>> GetActiveMerchantPrices(int mid) =>
            await _cache.GetValue($"ActiveMerchantPrices_{mid}", null,
                async () =>
                {
                    var usdRate = await GetUsdRate();
                    var list = await _merchantProductRepo.Queryable()
                                                         .AsNoTracking()
                                                         .Include(x => x.Merchant)
                                                         .Where(x => x.MerchantId == mid && x.Merchant.Active)
                                                         .Select(x => new MerchantProductDto { ProductId = x.ProductId, Product = x.Product.Title, ProductBarcode = x.Product.Barcode, ProductBrand = x.Product.Brand, ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent, MerchantPrice = x.MerchantPrice, PriceUsd = x.PriceUsd, Discount = x.Discount, AdditionalProfitPercent = x.AdditionalProfitPercent })
                                                         .ToListAsync();
                    foreach (var item in list)
                    {
                        if (item.PriceUsd.HasValue && item.PriceUsd.Value > 0 && usdRate > 0)
                        {
                            item.MerchantPrice = ToLocalPrice(item.PriceUsd.Value, usdRate);
                        }
                    }
                    return list.ToDictionary(x => x.ProductId);
                });

        public async Task<Dictionary<int, MerchantProductDto>> GetAllMerchantPrices(int mid) =>
            await _cache.GetValue($"AllMerchantPrices_{mid}", null,
                async () =>
                {
                    var usdRate = await GetUsdRate();
                    var list = await _merchantProductRepo.Queryable()
                                                         .AsNoTracking()
                                                         .Include(x => x.Merchant)
                                                         .Where(x => x.MerchantId == mid)
                                                         .Select(x => new MerchantProductDto { ProductId = x.ProductId, Product = x.Product.Title, ProductBarcode = x.Product.Barcode, ProductBrand = x.Product.Brand, ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent, MerchantPrice = x.MerchantPrice, PriceUsd = x.PriceUsd, Discount = x.Discount, AdditionalProfitPercent = x.AdditionalProfitPercent })
                                                         .ToListAsync();
                    foreach (var item in list)
                    {
                        if (item.PriceUsd.HasValue && item.PriceUsd.Value > 0 && usdRate > 0)
                        {
                            item.MerchantPrice = ToLocalPrice(item.PriceUsd.Value, usdRate);
                        }
                    }
                    return list.ToDictionary(x => x.ProductId);
                });

        public async Task<Dictionary<int, MerchantProductDto>> GetProductPrices(int pid) =>
            await _cache.GetValue($"ProductPrices_{pid}", null,
                async () =>
                {
                    var usdRate = await GetUsdRate();
                    var list = await _merchantProductRepo.Queryable()
                                                         .AsNoTracking()
                                                         .Include(x => x.Merchant)
                                                         .Where(x => x.ProductId == pid && x.Merchant.Active && x.MerchantPrice > 0)
                                                         .Select(x => new MerchantProductDto
                                                         {
                                                             MerchantId = x.MerchantId,
                                                             ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent,
                                                             MerchantPrice = x.MerchantPrice,
                                                             PriceUsd = x.PriceUsd,
                                                             Discount = x.Discount,
                                                             AdditionalProfitPercent = x.AdditionalProfitPercent
                                                         })
                                                         .ToListAsync();
                    foreach (var item in list)
                    {
                        if (item.PriceUsd.HasValue && item.PriceUsd.Value > 0 && usdRate > 0)
                        {
                            item.MerchantPrice = ToLocalPrice(item.PriceUsd.Value, usdRate);
                        }
                    }
                    return list.OrderBy(x => x.MerchantPrice + (x.MerchantPrice * x.AdditionalProfitPercent / 100))
                               .ToDictionary(x => x.MerchantId);
                });

        public async Task<MerchantProductDto> GetMerchantProductPrice(int mid, int pid) =>
            await _cache.GetValue($"MerchantProduct_{mid}_{pid}", null,
                async () =>
                {
                    var usdRate = await GetUsdRate();
                    var item = await _merchantProductRepo.Queryable()
                                                         .AsNoTracking()
                                                         .Include(x => x.Merchant)
                                                         .Where(x => x.MerchantId == mid && x.ProductId == pid && x.Merchant.Active)
                                                         .Select(x => new MerchantProductDto
                                                         {
                                                             MerchantId = x.MerchantId,
                                                             ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent,
                                                             MerchantPrice = x.MerchantPrice,
                                                             PriceUsd = x.PriceUsd,
                                                             Discount = x.Discount,
                                                             AdditionalProfitPercent = x.AdditionalProfitPercent
                                                         })
                                                         .FirstOrDefaultAsync();
                    if (item != null && item.PriceUsd.HasValue && item.PriceUsd.Value > 0 && usdRate > 0)
                    {
                        item.MerchantPrice = ToLocalPrice(item.PriceUsd.Value, usdRate);
                    }
                    return item;
                });

        public async Task<MerchantProductDto> GetBestProductPrice(int pid, int[] mids)
        {
            var mps = await GetProductPrices(pid);
            if (mids == null)
            {
                if (mps.Count > 0)
                    return mps.First().Value;
            }
            return mps?.FirstOrDefault(x => mids.Contains(x.Key)).Value;
        }

        public async Task<int> AssignMerchantProducts(int[] mids, MerchantProductAssignDto[] products)
        {
            if (products == null)
                products = Array.Empty<MerchantProductAssignDto>();

            var usdRate = await GetUsdRate();

            foreach (var mid in mids)
            {
                var merchant = await Queryable().FirstOrDefaultAsync(x => x.Id == mid);

                var merchantProducts = await _merchantProductRepo.Queryable().Where(x => x.MerchantId == mid).ToArrayAsync();

                var toBeAdded = products.Where(p => !merchantProducts.Any(mp => mp.ProductId == p.ProductId)).ToArray();
                var toBeUpdated = products.Where(p => merchantProducts.Any(mp => mp.ProductId == p.ProductId && (mp.AdditionalProfitPercent != p.AdditionalProfitPercent || mp.MerchantPrice != p.MerchantPrice || mp.PriceUsd != p.PriceUsd))).ToArray();
                var toBeRemoved = merchantProducts.Where(mp => !products.Any(p => p.ProductId == mp.ProductId)).ToArray();

                foreach (var item in toBeAdded)
                {
                    var profitOutOfMerchantPricePercent = item?.ProfitOutOfMerchantPricePercent ?? 0;
                    // if no product profit percent specified, use global profit percent
                    if (profitOutOfMerchantPricePercent == 0)
                        profitOutOfMerchantPricePercent = merchant.ProfitOutOfMerchantPricePercent;

                    _merchantProductRepo.Insert(new MerchantProduct
                    {
                        MerchantId = mid,
                        ProductId = item.ProductId,
                        // A dollar-quoted product derives its selling price from
                        // the rate; anything else is priced locally as supplied.
                        MerchantPrice = item.PriceUsd.HasValue && usdRate > 0
                                            ? ToLocalPrice(item.PriceUsd.Value, usdRate)
                                            : item.MerchantPrice,
                        PriceUsd = item.PriceUsd,
                        ProfitOutOfMerchantPricePercent = profitOutOfMerchantPricePercent,
                        AdditionalProfitPercent = item.AdditionalProfitPercent
                    });
                    _cache.Remove($"ProductPrices_{item.ProductId}");
                    _cache.Remove($"MerchantProduct_{mid}_{item.ProductId}");
                }
                foreach (var item in toBeUpdated)
                {
                    var mp = merchantProducts.FirstOrDefault(x => x.ProductId == item.ProductId);
                    var profitOutOfMerchantPricePercent = item?.ProfitOutOfMerchantPricePercent ?? 0;
                    // if no product profit percent specified, use global profit percent
                    if (profitOutOfMerchantPricePercent == 0)
                        profitOutOfMerchantPricePercent = merchant.ProfitOutOfMerchantPricePercent;

                    mp.ProfitOutOfMerchantPricePercent = profitOutOfMerchantPricePercent;
                    mp.AdditionalProfitPercent = item?.AdditionalProfitPercent ?? 0;
                    mp.MerchantPrice = item?.MerchantPrice ?? 0;
                    ApplyUsdPricing(mp, item?.PriceUsd, usdRate);
                    _cache.Remove($"ProductPrices_{item.ProductId}");
                    _cache.Remove($"MerchantProduct_{mid}_{item.ProductId}");
                }
                foreach (var item in toBeRemoved)
                {
                    await _merchantProductRepo.DeleteAsync(new object[] { mid, item.ProductId });
                    _cache.Remove($"ProductPrices_{item.ProductId}");
                    _cache.Remove($"MerchantProduct_{mid}_{item.ProductId}");
                }
                await _uow.SaveChangesAsync();
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");

                //await SetMerchantPercent(mid, merchant.ProfitOutOfMerchantPricePercent);
            }
            return products.Length;
        }


        /// <summary>
        /// Reconciles a row's dollar base with its stored local price after a
        /// write. A caller that supplies a dollar price is quoting in dollars,
        /// so the local price is derived from it. A caller that only supplies a
        /// local price for a row that was already dollar-quoted is overriding it
        /// by hand, and the base is recomputed from that figure so the next
        /// exchange rate change does not silently undo the override.
        /// </summary>
        private static void ApplyUsdPricing(MerchantProduct mp, decimal? priceUsd, decimal usdRate)
        {
            if (usdRate <= 0)
                return;

            if (priceUsd.HasValue)
            {
                mp.PriceUsd = priceUsd;
                mp.MerchantPrice = ToLocalPrice(priceUsd.Value, usdRate);
            }
            else if (mp.PriceUsd.HasValue)
            {
                mp.PriceUsd = mp.MerchantPrice / usdRate;
            }
        }

        /// <summary>
        /// Recalculates the stored selling price of every dollar-quoted product
        /// from its USD base and the given rate. Products priced directly in the
        /// local currency carry no USD base and are deliberately left alone.
        /// </summary>
        public async Task<int> RepriceUsdDenominatedProducts(decimal usdRate)
        {
            if (usdRate <= 0)
                return 0;

            var usdProducts = await _merchantProductRepo.Queryable()
                                                        .Where(x => x.PriceUsd != null)
                                                        .ToArrayAsync();

            var repriced = 0;
            foreach (var mp in usdProducts)
            {
                var price = ToLocalPrice(mp.PriceUsd.Value, usdRate);
                if (mp.MerchantPrice == price)
                    continue;

                mp.MerchantPrice = price;
                _cache.Remove($"ProductPrices_{mp.ProductId}");
                _cache.Remove($"MerchantProduct_{mp.MerchantId}_{mp.ProductId}");
                repriced++;
            }

            if (repriced > 0)
            {
                await _uow.SaveChangesAsync();
            }

            foreach (var mid in usdProducts.Select(x => x.MerchantId).Distinct())
            {
                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }
            return repriced;
        }

        public async Task<bool> SetMerchantPercent(int mid, decimal percent)
        {
            var merchant = await Queryable().FirstOrDefaultAsync(x => x.Id == mid);

            var merchantProducts = await _merchantProductRepo.Queryable().Where(x => x.MerchantId == mid).ToArrayAsync();

            foreach (var item in merchantProducts)
            {
                var mp = merchantProducts.FirstOrDefault(x => x.ProductId == item.ProductId);
                mp.ProfitOutOfMerchantPricePercent = percent;
                _cache.Remove($"ProductPrices_{item.ProductId}");
                _cache.Remove($"MerchantProduct_{mid}_{item.ProductId}");
            }
            await _uow.SaveChangesAsync();
            _cache.Remove($"ActiveMerchantPrices_{mid}");
            _cache.Remove($"AllMerchantPrices_{mid}");
            return true;
        }

        public async Task<int> SetMerchantProductPrices(int[] mids, MerchantProductPriceDto[] newProducts)
        {
            if (newProducts == null)
                newProducts = Array.Empty<MerchantProductPriceDto>();

            var merchantProducts = await _merchantProductRepo.Queryable().Where(x => mids.Contains(x.MerchantId)).ToArrayAsync();
            var usdRate = await GetUsdRate();

            foreach (var mid in mids)
            {
                var merchant = await Queryable().FirstOrDefaultAsync(x => x.Id == mid);
                var midMerchantProducts = merchantProducts.Where(x => x.MerchantId == mid).ToList();

                foreach (var np in newProducts)
                {
                    var existing = midMerchantProducts.FirstOrDefault(x => x.ProductId == np.ProductId);
                    if (existing != null)
                    {
                        if (existing.MerchantPrice != np.MerchantPrice)
                        {
                            existing.MerchantPrice = np.MerchantPrice;
                            ApplyUsdPricing(existing, null, usdRate);
                            _cache.Remove($"ProductPrices_{np.ProductId}");
                            _cache.Remove($"MerchantProduct_{mid}_{np.ProductId}");
                        }
                    }
                    else
                    {
                        var profitOutOfMerchantPricePercent = merchant?.ProfitOutOfMerchantPricePercent ?? 0;

                        _merchantProductRepo.Insert(new MerchantProduct
                        {
                            MerchantId = mid,
                            ProductId = np.ProductId,
                            MerchantPrice = np.MerchantPrice,
                            ProfitOutOfMerchantPricePercent = profitOutOfMerchantPricePercent,
                            AdditionalProfitPercent = 0
                        });
                        _cache.Remove($"ProductPrices_{np.ProductId}");
                        _cache.Remove($"MerchantProduct_{mid}_{np.ProductId}");
                    }
                }

                _cache.Remove($"ActiveMerchantPrices_{mid}");
                _cache.Remove($"AllMerchantPrices_{mid}");
            }

            await _uow.SaveChangesAsync();
            return newProducts.Length;
        }

        public async Task<MerchantProductDto> GetBestProductPrice(int pid, decimal lat, decimal lng)
        {
            var mids = await GetValidMerchants(lat, lng);
            return await GetBestProductPrice(pid, mids);
        }

        public async Task<MerchantProductDto> GetBestProductPrice(int pid, int[] mids, decimal lat, decimal lng)
        {
            var mids2 = await GetValidMerchants(lat, lng);
            mids = mids.Where(x => mids2.Contains(x)).ToArray();
            return await GetBestProductPrice(pid, mids);
        }
        public async Task<MerchantProductDto> GetBestAlternativeProductPrice(int pid, int[] excludeMids, decimal lat, decimal lng)
        {
            var mids = await GetValidMerchants(lat, lng);
            mids = mids.Where(x => !excludeMids.Contains(x)).ToArray();
            return await GetBestProductPrice(pid, mids);
        }
        public async Task<MerchantProductDto[]> GetBestAlternativeProductsPrice(int[] pids, int[] excludeMids, decimal lat, decimal lng)
        {
            var result = new List<MerchantProductDto>();
            foreach (var pid in pids)
            {
                var mp = await GetBestAlternativeProductPrice(pid, excludeMids, lat, lng);
                result.Add(mp);
            }
            return result.ToArray();
        }

        public async Task<Guid> GetOwnerId(int id) =>
            await Queryable().Where(x => x.Id == id).Select(x => x.OwnerId).FirstOrDefaultAsync();

        public async Task<int[]> GetMerchantIds(Guid id) =>
            await Queryable().Where(x => x.OwnerId == id).Select(x => x.Id).ToArrayAsync();

        public async Task<(decimal Lat, decimal Lng)[]> GetMerchantLocations(int[] mids) =>
            (await Queryable().Where(x => mids.Contains(x.Id))
                              .Select(x => new Tuple<decimal, decimal>(x.Lat, x.Lng))
                              .ToArrayAsync())
                        .Select(x => x.ToValueTuple())
                        .ToArray();

        public override IQueryable<Merchant> OrderBy(IQueryable<Merchant> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            var isAsc = dir == ListSortDirection.Ascending;
            orderColumn = orderColumn.Trim().ToLower();

            query = orderColumn switch
            {
                "title" => isAsc ? query.OrderBy(x => x.Title) : query.OrderByDescending(x => x.Title),
                _ => isAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id)
            };
            return query;
        }
        public override IQueryable<MerchantDto> OrderBy(IQueryable<MerchantDto> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            var isAsc = dir == ListSortDirection.Ascending;
            orderColumn = orderColumn.Trim().ToLower();

            query = orderColumn switch
            {
                "title" => isAsc ? query.OrderBy(x => x.Title) : query.OrderByDescending(x => x.Title),
                _ => isAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id)
            };
            return query;
        }


        public override IQueryable<Merchant> Search(IQueryable<Merchant> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword) || x.ShortDescription.ToLower().Contains(keyword) || x.Phone1.ToLower().Contains(keyword) || x.Phone2.ToLower().Contains(keyword));
        }
        public override IQueryable<MerchantDto> Search(IQueryable<MerchantDto> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword) || x.ShortDescription.ToLower().Contains(keyword) || x.Phone1.ToLower().Contains(keyword) || x.Phone2.ToLower().Contains(keyword));
        }

        public async Task<(decimal Lat, decimal Lng, int MerchantId)[]> GetMerchantStops(params int[] mids) =>
            (await Queryable().AsNoTracking()
                                    .Where(x => mids.Contains(x.Id))
                                    .Select(x => new { x.Id, x.Lat, x.Lng })
                                    .ToArrayAsync())
                            .Select(x => (x.Lat, x.Lng, x.Id))
                            .ToArray();

    }
    public static class MerchantExt
    {
        // Scaling Factor
        private const double sf = Math.PI / 180;
        // Earth Radius In Meteres
        private const int er = 6371000;
        public static IQueryable<Merchant> WhereInRange(this IQueryable<Merchant> source, decimal lat, decimal lng) =>
            source.Where(x => x.Active && x.ShippingCoverageInMeters >= er *
            Math.Acos(Math.Sin((double)x.Lat * sf) * Math.Sin((double)lat * sf) +
                Math.Cos((double)x.Lat * sf) * Math.Cos((double)lat * sf) * Math.Cos(((double)x.Lng - (double)lng) * sf)));


        public static IOrderedQueryable<Merchant> OrderByDistance(this IQueryable<Merchant> source, decimal lat, decimal lng) =>
            source.OrderBy(x => er * Math.Acos(Math.Sin((double)x.Lat * sf) * Math.Sin((double)lat * sf) + Math.Cos((double)x.Lat * sf) * Math.Cos((double)lat * sf) * Math.Cos(((double)x.Lng - (double)lng) * sf)));

        public static IOrderedQueryable<Merchant> OrderByDistanceDescending(this IQueryable<Merchant> source, decimal lat, decimal lng) =>
            source.OrderByDescending(x => er * Math.Acos(Math.Sin((double)x.Lat * sf) * Math.Sin((double)lat * sf) + Math.Cos((double)x.Lat * sf) * Math.Cos((double)lat * sf) * Math.Cos(((double)x.Lng - (double)lng) * sf)));

    }
}
