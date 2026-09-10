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
    }
    public class GenericSettingService : Service<GenericSetting>, IGenericSettingService
    {
        private readonly IAppUnitOfWork _unitOfWork;
        private readonly IMemoryCache _cache;
        public GenericSettingService(ITrackableRepository<GenericSetting, AppDbContext> repository,
                                     IMemoryCache cache,
                                     IAppUnitOfWork unitOfWork) : base(repository)
        {
            _unitOfWork = unitOfWork;
            _cache = cache;
        }


        public async Task<T> GetValue<T>(string key, string lang)
        {
            key = lang == null ? key : $"{key}_{lang}";
            // Look for cache key.
            if (!_cache.TryGetValue(key, out T result))
            {
                var setting = await Repository.FindAsync(key);
                if (setting == null)
                {
                    _cache.Set<T>(key, default, TimeSpan.FromDays(1));
                }
                try
                {
                    if (setting?.Value != null)
                    {
                        _cache.Set(key, JsonSerializer.Deserialize<T>(setting.Value), TimeSpan.FromDays(1));
                    }
                }
                catch (Exception) { }
            }

            return result ?? default;
        }

        public async Task SetValue<T>(string key, T val, string lang)
        {
            key = lang == null ? key : $"{key}_{lang}";
            var value = val != null ? JsonSerializer.Serialize(val) : null;
            var setting = await Repository.FindAsync(key);
            if (setting == null)
            {
                setting = new GenericSetting { Key = key, Value = value };
                Repository.Insert(setting);
            }
            else
            {
                setting.Value = value;
            }
            await _unitOfWork.SaveChangesAsync();
            _cache.Set(key, JsonSerializer.Deserialize<T>(setting.Value), TimeSpan.FromDays(1));
        }

        public T GetCachedValue<T>(string key, string lang = null)
        {
            if (!_cache.TryGetValue(key, out T result))
            {
                _cache.Set<T>(key, default, TimeSpan.FromDays(1));
                return default;
            }
            return result;
        }
        public void SetCachedValue<T>(string key, T val, string lang = null)
        {
            var value = val != null ? JsonSerializer.Serialize(val) : null;
            _cache.Set(key, JsonSerializer.Deserialize<T>(value), TimeSpan.FromDays(1));
        }
    }
}
