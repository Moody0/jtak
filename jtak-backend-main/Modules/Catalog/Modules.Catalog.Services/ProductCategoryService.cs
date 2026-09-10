using App.Catalog.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Modules.Catalog.Entities;
using Solf.Base;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Catalog.Services
{
    public interface IProductCategoryService : ISolService<ProductCategory, ProductCategoryDto>
    {
        Task<ProductCategory> FindAsync(int? id);
        Task<Dictionary<int, ProductCategoryDto>> GetProductCategories();
        Task<ProductCategoryDto[]> GetProductCategoriesTree();
    }
    public class ProductCategoryService : SolService<ProductCategory, ProductCategoryDto>, IProductCategoryService
    {
        private readonly IMemoryCache _cache;
        public ProductCategoryService(ITrackableRepository<ProductCategory, CatalogDbContext> r, IMemoryCache cache) : base(r)
        {
            _cache = cache;
        }

        public async Task<ProductCategory> FindAsync(int? id) =>
            await Queryable().FirstOrDefaultAsync(x => x.Id == id);


        public override IQueryable<ProductCategory> OrderBy(IQueryable<ProductCategory> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //"title" => base.OrderBy(query, orderColumn.Replace("title", "Category.Title")),
                _ => base.OrderBy(query, orderColumn, dir)
            };
            return query;
        }

        public override IQueryable<ProductCategory> Search(IQueryable<ProductCategory> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.Title.ToLower().Contains(keyword));
        }

        public async Task<Dictionary<int, ProductCategoryDto>> GetProductCategories() =>
            await _cache.GetValue("ProductCategories", null, async () => await LoadProductCategories());

        public async Task<ProductCategoryDto[]> GetProductCategoriesTree() =>
            await _cache.GetValue("ProductCategoriesTree", null, async () => await LoadProductCategoriesTree());

        #region Helpers
        private int ScanDepth = 1;
        private Dictionary<int, ProductCategoryDto> ProductCategories { get; set; }
        private async Task<Dictionary<int, ProductCategoryDto>> LoadProductCategories() =>
            await Repository.Queryable()
                            .Where(x => x.Active && x.DeletionDate == null)
                            .OrderBy(x => x.Order)
                            .Select(x => new ProductCategoryDto { Id = x.Id, Title = x.Title, Icon = x.Icon, ParentId = x.ParentId, Active = x.Active, Order = x.Order })
                            .ToDictionaryAsync(x => x.Id);

        private async Task<ProductCategoryDto[]> LoadProductCategoriesTree()
        {
            ProductCategories = await LoadProductCategories();
            var rootCats = ProductCategories.Values.Where(x => x.ParentId == null).OrderBy(x => x.Order).ToArray();
            for (int i = 0; i < rootCats.Length; i++)
            {
                LoadChildren(ref rootCats[i]);
            }
            return rootCats;
        }

        private void LoadChildren(ref ProductCategoryDto cat)
        {
            var pcatId = cat.Id;
            cat.SubCategories = ProductCategories.Values.Where(x => x.ParentId == pcatId).ToArray();
            if (ScanDepth < 10)
            {
                ScanDepth++;
                for (int i = 0; i < cat.SubCategories.Length; i++)
                {
                    cat.SubCategories[i].Parent = cat.Title;
                    LoadChildren(ref cat.SubCategories[i]);
                }
                ScanDepth--;
            }
        }
        #endregion
    }
}
