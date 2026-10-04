using Microsoft.EntityFrameworkCore;
using Modules.Catalog.Entities;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Catalog.Services
{
    public static class CatalogCategoryVisibility
    {
        // A category is visible only when its complete path to a root is active.
        // Orphaned and cyclic branches remain hidden.
        public static async Task<int[]> GetIdsAsync(IQueryable<ProductCategory> query)
        {
            var categories = await query.AsNoTracking()
                .Where(x => x.Active && x.DeletionDate == null)
                .Select(x => new { x.Id, x.ParentId }).ToArrayAsync();
            var ids = new HashSet<int>(categories.Where(x => !x.ParentId.HasValue).Select(x => x.Id));
            bool added;
            do {
                added = false;
                foreach (var category in categories)
                    if (category.ParentId.HasValue && ids.Contains(category.ParentId.Value))
                        added |= ids.Add(category.Id);
            } while (added);
            return ids.ToArray();
        }
    }
}
