using System.Collections.Generic;
using URF.Core.Abstractions;

namespace App.Shared.Services.Extentions
{
    public static class ServiceExtensions
    {
        public static void Insert<TEntity>(this IRepository<TEntity> repo, IEnumerable<TEntity> entities) where TEntity : class
        {
            foreach (var item in entities) repo.Insert(item);
        }
        public static void Insert<TEntity>(this IRepository<TEntity> repo, params TEntity[] entities) where TEntity : class
        {
            foreach (var item in entities) repo.Insert(item);            
        }
    }
}
