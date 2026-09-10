using Microsoft.EntityFrameworkCore;
using URF.Core.EF;
using URF.Core.Abstractions;

namespace App.Repository.MultiContext
{
    public interface IUnitOfWork<TDbContext> : IUnitOfWork
    {
    }
    public class UnitOfWork<TDbContext> : UnitOfWork, IUnitOfWork<TDbContext>
        where TDbContext : DbContext
    {
        public UnitOfWork(TDbContext context) : base(context)
        {
        }
    }
}
