using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Domain;
using Solf.Base;
using System.ComponentModel;
using System.Linq;

namespace App.Shared.Services.Domain
{
    public interface IFavoriteProductService : ISolService<FavoriteProduct, FavoriteProductDto>
    {
    }
    public class FavoriteProductService : SolService<FavoriteProduct, FavoriteProductDto>, IFavoriteProductService
    {
        public FavoriteProductService(ITrackableRepository<FavoriteProduct, AppDbContext> r)
            : base(r)
        {
        }


        public override IQueryable<FavoriteProduct> OrderBy(IQueryable<FavoriteProduct> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //"title" => base.OrderBy(query, orderColumn.Replace("title", "FavoriteProduct.Title")),
                _ => base.OrderBy(query, orderColumn, dir)
            };
            return query;
        }

        public override IQueryable<FavoriteProduct> Search(IQueryable<FavoriteProduct> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.ProductTitle.ToLower().Contains(keyword));
        }
    }
}
