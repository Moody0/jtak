using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using Microsoft.Extensions.Caching.Memory;
using System;
using System.Text.Json;
using System.Threading.Tasks;
using URF.Core.Abstractions.Services;
using URF.Core.Services;

namespace App.Shared.Services
{
    public interface IGenericSettingService : IService<GenericSetting>
    {
        Task<T> GetValue<T>(string key, string lang = null);
        Task SetValue<T>(string key, T val, string lang = null);
        T GetCachedValue<T>(string key, string lang = null);
        void SetCachedValue<T>(string key, T val, string lang = null);
        void InvalidateCache(string key, string lang = null);
    }
    public class GenericSettingService : Service<GenericSetting>, IGenericSettingService
    {
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly IMemoryCache _cache;
        private static readonly object CacheGate = new object();
        private long Epoch(string key) => _cache.Get<long>(CacheKey(key) + ":epoch");
        public GenericSettingService(ITrackableRepository<GenericSetting, AppDbContext> repository, IMemoryCache cache, IAppUnitOfWork unitOfWork) : base(repository)
        { _unitOfWork = unitOfWork; _cache = cache; }
        private static string SettingKey(string key, string lang) => lang == null ? key : $"{key}_{lang}";
        private static string CacheKey(string key) => $"GenericSetting:json:{key}";
        private bool InTransaction => _unitOfWork.Context.Database.CurrentTransaction != null;
        private static readonly JsonSerializerOptions ReadOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        private static T Read<T>(string json)
        {
            if (json == null) return default;
            try { return JsonSerializer.Deserialize<T>(json, ReadOptions); }
            catch (JsonException) { return default; }
            catch (NotSupportedException) { return default; }
        }
        public async Task<T> GetValue<T>(string key, string lang = null)
        {
            key = SettingKey(key, lang);
            // Serialized values keep object/string readers coherent and return fresh instances.
            long epoch;
            lock (CacheGate)
            {
                epoch = Epoch(key);
                if (!InTransaction && _cache.TryGetValue(CacheKey(key), out string cached)) return Read<T>(cached);
            }
            var setting = await Repository.FindAsync(key);
            var json = setting?.Value;
            lock (CacheGate)
                if (!InTransaction && Epoch(key) == epoch) _cache.Set(CacheKey(key), json, TimeSpan.FromDays(1));
            return Read<T>(json);
        }
        public async Task SetValue<T>(string key, T val, string lang = null)
        {
            key = SettingKey(key, lang);
            var json = val == null ? null : JsonSerializer.Serialize(val);
            var setting = await Repository.FindAsync(key);
            if (setting == null) Repository.Insert(new GenericSetting { Key = key, Value = json });
            else setting.Value = json;
            await _unitOfWork.SaveChangesAsync();
            InvalidateCache(key);
            // An outer transaction must commit before its new settings become visible.
            lock (CacheGate)
                if (!InTransaction) _cache.Set(CacheKey(key), json, TimeSpan.FromDays(1));
        }
        public void InvalidateCache(string key, string lang = null)
        {
            key = SettingKey(key, lang);
            lock (CacheGate) { _cache.Set(CacheKey(key) + ":epoch", Epoch(key) + 1); _cache.Remove(CacheKey(key)); }
        }

        public T GetCachedValue<T>(string key, string lang = null) =>
            !InTransaction && _cache.TryGetValue(CacheKey(SettingKey(key, lang)), out string json) ? Read<T>(json) : default;
        public void SetCachedValue<T>(string key, T val, string lang = null)
        {
            var cacheKey = CacheKey(SettingKey(key, lang));
            lock (CacheGate)
            {
                InvalidateCache(key, lang);
                if (!InTransaction) _cache.Set(cacheKey, val == null ? null : JsonSerializer.Serialize(val), TimeSpan.FromDays(1));
            }
        }
    }
}
