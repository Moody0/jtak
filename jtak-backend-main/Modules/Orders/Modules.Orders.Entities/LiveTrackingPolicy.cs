using System;

namespace Modules.Orders.Entities
{
    public static class LiveTrackingPolicy
    {
        public static bool HasCoordinates(decimal lat, decimal lng) =>
            lat >= -90m && lat <= 90m && lng >= -180m && lng <= 180m &&
            (lat != 0m || lng != 0m);

        public static bool IsFresh(DateTime? capturedAt, DateTime now)
        {
            if (!capturedAt.HasValue) return false;
            var utc = capturedAt.Value.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(capturedAt.Value, DateTimeKind.Utc)
                : capturedAt.Value.ToUniversalTime();
            var age = now.ToUniversalTime() - utc;
            return age >= TimeSpan.FromSeconds(-30) && age <= TimeSpan.FromSeconds(90);
        }

        // This is an estimate, not a road-routing promise. Unsupported regional
        // distances must be shown as unknown rather than a fabricated/capped ETA.
        public static int EstimateEta(bool isLive, int distanceMeters, int pendingStops)
        {
            if (!isLive || distanceMeters <= 0 || distanceMeters > 100000) return 0;
            var estimate = (int)Math.Ceiling(distanceMeters / 400.0) + Math.Max(0, pendingStops) * 2;
            return estimate <= 180 ? estimate : 0;
        }

        public static bool AcceptGpsUpdate(DeliveryLocationUpdate fix, DateTime now) =>
            fix != null && HasCoordinates(fix.Lat, fix.Lng) &&
            (!fix.Accuracy.HasValue || (double.IsFinite(fix.Accuracy.Value) &&
                fix.Accuracy.Value > 0 && fix.Accuracy.Value <= 100)) &&
            (!fix.CapturedAtUtc.HasValue || IsFresh(fix.CapturedAtUtc, now));
    }
}
