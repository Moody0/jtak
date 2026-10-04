using Microsoft.Extensions.Caching.Memory;
using System;
using System.Threading.Tasks;

namespace App.Shared.Services
{
    public static class CacheExt
    {
        private static readonly object Gate = new object();
        public static async Task<T> GetValue<T>(this IMemoryCache _cache, 
                                                string key,
                                                string lang, 
                                                Func<Task<T>> loadCache = null)
        {
            var lngkey = lang == null ? key : $"{key}_{lang}";
            long revision;
            lock (Gate)
            {
                revision = _cache.Get<long>("revision:" + lngkey);
                if (_cache.TryGetValue(lngkey, out T cached)) return cached;
            }
            if (loadCache == null) return default;
            var result = await loadCache();
            lock (Gate)
                if (_cache.Get<long>("revision:" + lngkey) == revision)
                    _cache.Set(lngkey, result, TimeSpan.FromDays(1));
            return result;
        }

        public static void InvalidateValue(this IMemoryCache cache, string key, string lang = null)
        {
            var cacheKey = lang == null ? key : $"{key}_{lang}";
            lock (Gate)
            {
                cache.Set("revision:" + cacheKey, cache.Get<long>("revision:" + cacheKey) + 1);
                cache.Remove(cacheKey);
            }
        }

        public static void SetValue<T>(this IMemoryCache _cache, string key, T val, string lang)
        {
            var lngkey = lang == null ? key : $"{key}_{lang}";
            lock (Gate)
            {
                _cache.InvalidateValue(key, lang);
                _cache.Set(lngkey, val, TimeSpan.FromDays(1));
            }
        }
    }
}
