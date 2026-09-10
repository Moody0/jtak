using Microsoft.EntityFrameworkCore;
using URF.Core.Abstractions;
using URF.Core.EF;

namespace App.Repository.MultiContext
{
    public interface IRepository<TEntity, TDbContext> : IRepository<TEntity>
        where TEntity : class
    {
    }
    public class Repository<TEntity, TDbContext> : Repository<TEntity>, IRepository<TEntity, TDbContext>
        where TDbContext : DbContext
        where TEntity : class
    {
        public Repository(TDbContext context) : base(context)
        {
        }
    }
}
