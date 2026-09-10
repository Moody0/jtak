using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using TrackableEntities.Common.Core;
using URF.Core.Abstractions.Trackable;
using URF.Core.EF.Trackable;

namespace App.Repository
{
    // Example: extending IRepository<TEntity> and/or ITrackableRepository<TEntity>, scope: application-wide
    public interface IRepositoryX<TEntity> : ITrackableRepository<TEntity> where TEntity : class, ITrackable
    {
        // Example: adding synchronous Find, scope: application wide for all repositories
        //TEntity Find(object[] keyValues, CancellationToken cancellationToken = default);
    }
    public class RepositoryX<TEntity> : TrackableRepository<TEntity>, IRepositoryX<TEntity> where TEntity : class, ITrackable
    {
        public RepositoryX(DbContext context) : base(context)
        {

        }

        // Example: adding synchronous Find, scope: application-wide
        //public TEntity Find(object[] keyValues, CancellationToken cancellationToken = default)
        //{
        //    return this.Context.Find<TEntity>(keyValues) as TEntity;
        //}
    }
}
