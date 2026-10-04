using App.Shared.Data.MultiContext;

namespace App.Catalog.Data
{
    public interface ICatalogUnitOfWork : IUnitOfWork<CatalogDbContext>
    {
        CatalogDbContext Context { get; }
    }
    public class CatalogUnitOfWork : UnitOfWork<CatalogDbContext>, ICatalogUnitOfWork
    {
        public new CatalogDbContext Context => (CatalogDbContext)base.Context;
        public CatalogUnitOfWork(CatalogDbContext context) : base(context)
        {
        }
    }
}
