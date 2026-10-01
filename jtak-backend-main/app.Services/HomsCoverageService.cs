using System;
using System.Text.Json;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Entities;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;

namespace App.Shared.Services;

public sealed class HomsCoverageService
{
    private readonly IGenericSettingService _settings;
    private readonly AppDbContext _db;
    public HomsCoverageService(IGenericSettingService settings, AppDbContext db = null)
    { _settings = settings; _db = db; }

    public async Task<HomsCoverageSetting> GetSettingAsync()
    {
        HomsCoverageSetting setting;
        if (_db != null) {
            // Coverage changes must reach every API process immediately, rather
            // than using the generic settings' day-long per-process cache.
            var row = await _db.Set<GenericSetting>().AsNoTracking().FirstOrDefaultAsync(x => x.Key == HomsCoverageSetting.Key);
            try { setting = row == null ? new() : JsonSerializer.Deserialize<HomsCoverageSetting>(row.Value ?? "null"); }
            catch (JsonException) { throw new InvalidOperationException("إعدادات منطقة التوصيل غير صالحة. يرجى التواصل مع الإدارة."); }
        } else {
            setting = _settings == null ? new() : await _settings.GetValue<HomsCoverageSetting>(HomsCoverageSetting.Key) ?? new();
        }
        if (setting == null || !setting.IsValid)
            throw new InvalidOperationException("إعدادات منطقة التوصيل غير صالحة. يرجى التواصل مع الإدارة.");
        return setting;
    }

    public async Task<HomsCoverageSetting> SaveAsync(decimal radiusKm)
    {
        var setting = new HomsCoverageSetting { RadiusKm = radiusKm, Version = Guid.NewGuid() };
        if (!setting.IsValid) throw new InvalidOperationException("أدخل نصف قطر بين 0.1 و100 كم، حتى منزلتين عشريتين.");
        await _settings.SetValue(HomsCoverageSetting.Key, setting);
        return setting;
    }

    public async Task<string> ValidateAsync(decimal lat, decimal lng)
        => Validate(await GetSettingAsync(), lat, lng);

    public async Task<bool> ContainsDestinationAsync(decimal lat, decimal lng)
    {
        var setting = await GetSettingAsync();
        return ValidCoordinates(lat, lng) && Distance(setting, lat, lng) <= (double)setting.RadiusKm * 1000;
    }

    public static string Validate(HomsCoverageSetting setting, decimal lat, decimal lng)
    {
        if (!ValidCoordinates(lat, lng) || Distance(setting, lat, lng) > (double)setting.RadiusKm * 1000)
            return "عنوان التوصيل خارج منطقة التغطية في حمص. اختر عنواناً داخل منطقة التوصيل.";
        return null;
    }
    public static bool ValidCoordinates(decimal lat, decimal lng) => lat >= -90m && lat <= 90m &&
        lng >= -180m && lng <= 180m && (lat != 0m || lng != 0m);
    private static double Distance(HomsCoverageSetting setting, decimal lat, decimal lng) =>
        GeoLocationHelper.CalculateDistanceInMeters(setting.CenterLat, setting.CenterLng, lat, lng);
}
