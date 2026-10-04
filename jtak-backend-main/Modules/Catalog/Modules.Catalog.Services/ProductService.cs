using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Catalog.Entities;
using Solf.Base;
using System.Linq;
using System.Threading.Tasks;
using URF.Core.Abstractions.Trackable;

namespace Modules.Catalog.Services
{
    public interface IProductService : ISolService<Product, ProductDto>
    {
        Task<Product> FindAsync(int id);
        Task<ProductLiteDto> GetProduct(int pid);
    }
    public class ProductService : SolService<Product, ProductDto>, IProductService
    {
        ITrackableRepository<Tag> _tagsRepo;
        ITrackableRepository<ProductTag> _productTagRepo;
        ICatalogUnitOfWork _unitOfWork;
        private readonly IMemoryCache _cache;
        private readonly ITrackableRepository<ProductCategory, CatalogDbContext> _categories;
        public ProductService(ICatalogUnitOfWork unitOfWork,
                                ITrackableRepository<Tag, CatalogDbContext> tagsRepo,
                                ITrackableRepository<ProductTag, CatalogDbContext> productTagRepo,
                                ITrackableRepository<Product, CatalogDbContext> r,
                                IMemoryCache cache, ITrackableRepository<ProductCategory, CatalogDbContext> categories = null) : base(r)
        {
            _tagsRepo = tagsRepo;
            _productTagRepo = productTagRepo;
            _unitOfWork = unitOfWork;
            _cache = cache;
            _categories = categories;
        }

        public async Task<Product> FindAsync(int id) =>
            await Queryable().Include(x => x.ProductCategory)
                             .Include(x => x.Tags)
                             .ThenInclude(x => x.Tag)
                             .Include(x => x.MerchantProducts)
                             .ThenInclude(x => x.Merchant)
                             .FirstOrDefaultAsync(x => x.Id == id);

        public async Task<ProductLiteDto> GetProduct(int pid) =>
            await _cache.GetValue($"Product-{pid}", null, async () => await LoadProduct(pid));

        public override IQueryable<Product> OrderBy(IQueryable<Product> query, string orderColumn, System.ComponentModel.ListSortDirection dir) =>
            base.OrderBy(query, orderColumn == "productCategory" ? "ProductCategory.Title" : orderColumn, dir);

        private async Task<ProductLiteDto> LoadProduct(int pid)
        {
            var visibleIds = _categories == null ? null : await _cache.GetValue("VisibleProductCategoryIds", null, async () => await CatalogCategoryVisibility.GetIdsAsync(_categories.Queryable()));
            return await Repository.Queryable()
                            .Where(x => x.Active && x.DeletionDate == null && (visibleIds == null || !x.ProductCategoryId.HasValue || visibleIds.Contains(x.ProductCategoryId.Value)))
                            .Select(x => new ProductLiteDto
                            {
                                Id = x.Id,
                                Title = x.Title,
                                Description = x.Description,
                                Unit = x.Unit,
                                Photos = x.Photos
                            })
                            .FirstOrDefaultAsync(x => x.Id == pid);
        }

        public override IQueryable<Product> Search(IQueryable<Product> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword) ||
                                    (x.TitleEn != null && x.TitleEn.ToLower().Contains(keyword)) ||
                                    (x.Unit != null && x.Unit.ToLower().Contains(keyword)) ||
                                    (x.Description != null && x.Description.ToLower().Contains(keyword)) ||
                                    (x.DescriptionEn != null && x.DescriptionEn.ToLower().Contains(keyword)) ||
                                    (x.Barcode != null && x.Barcode.ToLower().Contains(keyword)) ||
                                    (x.Brand != null && x.Brand.ToLower().Contains(keyword)) ||
                                    (x.ProductCategory != null && x.ProductCategory.Title.ToLower().Contains(keyword)) ||
                                    (x.MerchantProducts.Any(mp => mp.Merchant != null && mp.Merchant.Title.ToLower().Contains(keyword))) ||
                                    x.Id.ToString() == keyword);
        }

    }
}
