using Microsoft.EntityFrameworkCore;
using TrackableEntities.Common.Core;
using URF.Core.Abstractions.Trackable;
using URF.Core.EF.Trackable;

namespace App.Shared.Data.MultiContext
{
    public interface ITrackableRepository<TEntity, TDbContext> : ITrackableRepository<TEntity>
        where TEntity : class, ITrackable
    {
    }
    public class TrackableRepository<TEntity, TDbContext> : TrackableRepository<TEntity>, ITrackableRepository<TEntity, TDbContext>
        where TDbContext : DbContext
        where TEntity : class, ITrackable
    {
        public TrackableRepository(TDbContext context) : base(context)
        {
        }
    }
}
