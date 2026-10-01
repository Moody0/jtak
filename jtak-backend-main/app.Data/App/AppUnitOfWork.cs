using App.Shared.Data.MultiContext;

namespace App.Shared.Data.App
{
    public interface IAppUnitOfWork : IUnitOfWork<AppDbContext>
    {
        AppDbContext Context { get; }
    }
    public class AppUnitOfWork : UnitOfWork<AppDbContext>, IAppUnitOfWork
    {
        public new AppDbContext Context => (AppDbContext)base.Context;
        public AppUnitOfWork(AppDbContext context) : base(context)
        {
        }
    }
}
