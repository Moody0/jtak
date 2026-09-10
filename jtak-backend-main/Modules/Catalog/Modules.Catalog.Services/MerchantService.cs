using App.Catalog.Data;
using App.Shared.Data.MultiContext;
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
        Task<(decimal Lat, decimal Lng)[]> GetMerchantLocations(int[] mids);
    }
    public class MerchantService : SolService<Merchant, MerchantDto>, IMerchantService
    {
        private readonly IMemoryCache _cache;
        private readonly ITrackableRepository<MerchantProduct, CatalogDbContext> _merchantProductRepo;
        private readonly ICatalogUnitOfWork _uow;
        public MerchantService(ITrackableRepository<Merchant, CatalogDbContext> r,
            ITrackableRepository<MerchantProduct, CatalogDbContext> merchantProductRepo,
            ICatalogUnitOfWork uow,
            IMemoryCache cache) : base(r)
        {
            _merchantProductRepo = merchantProductRepo;
            _uow = uow;
            _cache = cache;
        }
        public async Task<Merchant> FindAsync(int id) =>
            await Queryable().FirstOrDefaultAsync(x => x.Id == id);

        public async Task<int[]> GetValidMerchants(decimal lat, decimal lng) =>
            await Queryable().AsNoTracking()
                             .WhereInRange(lat, lng)
                             .Select(x => x.Id)
                             .ToArrayAsync();

        public async Task<Dictionary<int, MerchantProductDto>> GetActiveMerchantPrices(int mid) =>
            await _cache.GetValue($"ActiveMerchantPrices_{mid}", null,
                async () => await _merchantProductRepo.Queryable()
                                                      .AsNoTracking()
                                                      .Include(x => x.Merchant)
                                                      .Where(x => x.MerchantId == mid && x.Merchant.Active)
                                                      .Select(x => new MerchantProductDto { ProductId = x.ProductId, Product = x.Product.Title, ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent, MerchantPrice = x.MerchantPrice, Discount = x.Discount, AdditionalProfitPercent = x.AdditionalProfitPercent })
                                                      .ToDictionaryAsync(x => x.ProductId));

        public async Task<Dictionary<int, MerchantProductDto>> GetAllMerchantPrices(int mid) =>
            await _cache.GetValue($"AllMerchantPrices_{mid}", null,
                async () => await _merchantProductRepo.Queryable()
                                                      .AsNoTracking()
                                                      .Include(x => x.Merchant)
                                                      .Where(x => x.MerchantId == mid)
                                                      .Select(x => new MerchantProductDto { ProductId = x.ProductId, Product = x.Product.Title, ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent, MerchantPrice = x.MerchantPrice, Discount = x.Discount, AdditionalProfitPercent = x.AdditionalProfitPercent })
                                                      .ToDictionaryAsync(x => x.ProductId));

        public async Task<Dictionary<int, MerchantProductDto>> GetProductPrices(int pid) =>
            await _cache.GetValue($"ProductPrices_{pid}", null,
                async () => await _merchantProductRepo.Queryable()
                                                      .AsNoTracking()
                                                      .Include(x => x.Merchant)
                                                      .Where(x => x.ProductId == pid && x.Merchant.Active)
                                                      .OrderBy(x => x.MerchantPrice + (x.MerchantPrice * x.AdditionalProfitPercent / 100))
                                                      .Select(x => new MerchantProductDto
                                                      {
                                                          MerchantId = x.MerchantId,
                                                          ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent,
                                                          MerchantPrice = x.MerchantPrice,
                                                          Discount = x.Discount,
                                                          AdditionalProfitPercent = x.AdditionalProfitPercent
                                                      })
                                                      .ToDictionaryAsync(x => x.MerchantId));

        public async Task<MerchantProductDto> GetMerchantProductPrice(int mid, int pid) =>
            await _cache.GetValue($"MerchantProduct_{mid}_{pid}", null,
                async () => await _merchantProductRepo.Queryable()
                                                      .AsNoTracking()
                                                      .Include(x => x.Merchant)
                                                      .Where(x => x.MerchantId == mid && x.ProductId == pid && x.Merchant.Active)
                                                      .Select(x => new MerchantProductDto
                                                      {
                                                          MerchantId = x.MerchantId,
                                                          ProfitOutOfMerchantPricePercent = x.ProfitOutOfMerchantPricePercent,
                                                          MerchantPrice = x.MerchantPrice,
                                                          Discount = x.Discount,
                                                          AdditionalProfitPercent = x.AdditionalProfitPercent
                                                      })
                                                      .FirstOrDefaultAsync());

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

            foreach (var mid in mids)
            {
                var merchant = await Queryable().FirstOrDefaultAsync(x => x.Id == mid);

                var merchantProducts = await _merchantProductRepo.Queryable().Where(x => x.MerchantId == mid).ToArrayAsync();

                var toBeAdded = products.Where(p => !merchantProducts.Any(mp => mp.ProductId == p.ProductId)).ToArray();
                var toBeUpdated = products.Where(p => merchantProducts.Any(mp => mp.ProductId == p.ProductId && mp.AdditionalProfitPercent != p.AdditionalProfitPercent)).ToArray();
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
                        MerchantPrice = item.MerchantPrice,
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

            var toBeUpdated = merchantProducts.Where(p => newProducts.Any(np => np.ProductId == p.ProductId && np.MerchantPrice != p.MerchantPrice)).ToArray();

            foreach (var item in toBeUpdated)
            {
                item.MerchantPrice = newProducts.FirstOrDefault(x => x.ProductId == item.ProductId)?.MerchantPrice ?? 0;
                _cache.Remove($"ProductPrices_{item.ProductId}");
                _cache.Remove($"MerchantProduct_{item.MerchantId}_{item.ProductId}");
            }
            foreach (var mid in mids)
            {
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
