using System;
using System.Text.Json.Serialization;

namespace Modules.Orders.Entities;

public sealed class HomsCoverageSetting
{
    public const string Key = "HomsDeliveryCoverage";
    [JsonRequired]
    public decimal RadiusKm { get; set; } = 25m;
    public Guid Version { get; set; }
    public decimal CenterLat => 34.7333m;
    public decimal CenterLng => 36.7167m;
    [JsonIgnore]
    public bool IsValid => RadiusKm >= 0.1m && RadiusKm <= 100m && Math.Round(RadiusKm, 2) == RadiusKm;
}

public sealed class CustomerDeviceLocation
{
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public decimal AccuracyMeters { get; set; }
    public DateTimeOffset CapturedAt { get; set; }
    public bool IsMocked { get; set; }
}
