namespace App.Shared.Services
{
    /// <summary>
    /// The customer delivery area is defined by the selected map pin, never by address text
    /// or by an individual merchant's configured delivery radius.
    /// </summary>
    public static class HomsDeliveryArea
    {
        // A 25 km circle around central Homs defines the customer delivery area.
        public const decimal CenterLat = 34.7333m;
        public const decimal CenterLng = 36.7167m;
        public const double RadiusMeters = 25000.0;

        public static bool Contains(decimal lat, decimal lng)
        {
            if (lat < -90m || lat > 90m || lng < -180m || lng > 180m ||
                (lat == 0m && lng == 0m))
                return false;

            return GeoLocationHelper.CalculateDistanceInMeters(
                CenterLat, CenterLng, lat, lng) <= RadiusMeters;
        }
    }
}
