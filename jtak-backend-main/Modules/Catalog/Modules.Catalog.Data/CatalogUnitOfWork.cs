using App.Shared.Data.MultiContext;

namespace App.Catalog.Data
{
    public interface ICatalogUnitOfWork : IUnitOfWork<CatalogDbContext>
    {
    }
    public class CatalogUnitOfWork : UnitOfWork<CatalogDbContext>, ICatalogUnitOfWork
    {
        public CatalogUnitOfWork(CatalogDbContext context) : base(context)
        {
        }
    }
}
