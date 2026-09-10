using App.Shared.Data.MultiContext;

namespace App.Shared.Data.App
{
    public interface IAppUnitOfWork : IUnitOfWork<AppDbContext>
    {
    }
    public class AppUnitOfWork : UnitOfWork<AppDbContext>, IAppUnitOfWork
    {
        public AppUnitOfWork(AppDbContext context) : base(context)
        {
        }
    }
}
