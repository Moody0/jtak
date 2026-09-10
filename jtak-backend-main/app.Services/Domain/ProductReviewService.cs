using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Domain;
using Solf.Base;
using System.ComponentModel;
using System.Linq;

namespace App.Shared.Services.Domain
{
    public interface IProductReviewService : ISolService<ProductReview, ProductReviewDto>
    {
    }
    public class ProductReviewService : SolService<ProductReview, ProductReviewDto>, IProductReviewService
    {
        public ProductReviewService(ITrackableRepository<ProductReview, AppDbContext> r)
            : base(r)
        {
        }


        public override IQueryable<ProductReview> OrderBy(IQueryable<ProductReview> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            query = orderColumn switch
            {
                //"title" => base.OrderBy(query, orderColumn.Replace("title", "ProductReview.Title")),
                _ => base.OrderBy(query, orderColumn, dir)
            };
            return query;
        }

        public override IQueryable<ProductReview> Search(IQueryable<ProductReview> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.ProductTitle.ToLower().Contains(keyword));
        }
    }
}
