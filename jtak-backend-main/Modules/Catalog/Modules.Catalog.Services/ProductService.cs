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
        public ProductService(ICatalogUnitOfWork unitOfWork,
                                ITrackableRepository<Tag, CatalogDbContext> tagsRepo,
                                ITrackableRepository<ProductTag, CatalogDbContext> productTagRepo,
                                ITrackableRepository<Product, CatalogDbContext> r,
                                IMemoryCache cache) : base(r)
        {
            _tagsRepo = tagsRepo;
            _productTagRepo = productTagRepo;
            _unitOfWork = unitOfWork;
            _cache = cache;
        }

        public async Task<Product> FindAsync(int id) =>
            await Queryable().Include(x => x.ProductCategory)
                             .Include(x => x.Tags)
                             .ThenInclude(x => x.Tag)
                             .FirstOrDefaultAsync(x => x.Id == id);

        public async Task<ProductLiteDto> GetProduct(int pid) =>
            await _cache.GetValue($"Product-{pid}", null, async () => await LoadProduct(pid));

        private async Task<ProductLiteDto> LoadProduct(int pid) =>
            await Repository.Queryable()
                            .Where(x => x.Active && x.DeletionDate == null)
                            .Select(x => new ProductLiteDto
                            {
                                Id = x.Id,
                                Title = x.Title,
                                Description = x.Description,
                                Unit = x.Unit,
                                Photos = x.Photos
                            })
                            .FirstOrDefaultAsync(x => x.Id == pid);

        public override IQueryable<Product> Search(IQueryable<Product> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword) ||
                                    x.Id.ToString() == keyword ||
                                    x.ProductCategory.Title.ToLower().Contains(keyword));
        }

    }
}
