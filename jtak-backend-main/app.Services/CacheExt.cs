using Microsoft.Extensions.Caching.Memory;
using System;
using System.Threading.Tasks;

namespace App.Shared.Services
{
    public static class CacheExt
    {
        public static async Task<T> GetValue<T>(this IMemoryCache _cache, 
                                                string key,
                                                string lang, 
                                                Func<Task<T>> loadCache = null)
        {
            var lngkey = lang == null ? key : $"{key}_{lang}";
            // Look for cache key.
            if (_cache.TryGetValue(lngkey, out T result))
                return result;

            if (loadCache != null)
                _cache.Set(lngkey, await loadCache(), TimeSpan.FromDays(1));

            // reload the cache
            _cache.TryGetValue(key, out result);
            return result;
        }

        public static void SetValue<T>(this IMemoryCache _cache, string key, T val, string lang)
        {
            var lngkey = lang == null ? key : $"{key}_{lang}";
            _cache.Set(lngkey, val, TimeSpan.FromDays(1));
        }
    }
}
