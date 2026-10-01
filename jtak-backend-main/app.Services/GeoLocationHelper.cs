using System;

namespace App.Shared.Services
{
    public static class GeoLocationHelper
    {
        private const double DegToRad = Math.PI / 180.0;
        private const double EarthRadiusMeters = 6371000.0;

        /// <summary>
        /// Calculates the great-circle distance between two decimal coordinates in meters using the Haversine formula.
        /// </summary>
        public static double CalculateDistanceInMeters(decimal lat1, decimal lng1, decimal lat2, decimal lng2)
        {
            if (lat1 == 0 && lng1 == 0) return 0;
            if (lat2 == 0 && lng2 == 0) return 0;

            double phi1 = (double)lat1 * DegToRad;
            double phi2 = (double)lat2 * DegToRad;
            double deltaPhi = ((double)lat2 - (double)lat1) * DegToRad;
            double deltaLambda = ((double)lng2 - (double)lng1) * DegToRad;

            double a = Math.Sin(deltaPhi / 2.0) * Math.Sin(deltaPhi / 2.0) +
                       Math.Cos(phi1) * Math.Cos(phi2) *
                       Math.Sin(deltaLambda / 2.0) * Math.Sin(deltaLambda / 2.0);

            // Guard against floating-point precision domain errors for Math.Sqrt
            a = Math.Max(0.0, Math.Min(1.0, a));

            double c = 2.0 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1.0 - a));
            return EarthRadiusMeters * c;
        }

        /// <summary>
        /// Validates whether a customer coordinate is within a merchant's declared delivery coverage radius in meters.
        /// If coverageInMeters is 0 or negative, it indicates unlimited/unconstrained delivery radius.
        /// </summary>
        public static bool IsWithinRadius(decimal merchantLat, decimal merchantLng, decimal customerLat, decimal customerLng, int coverageInMeters)
        {
            if (coverageInMeters <= 0) return true;
            if (customerLat == 0 && customerLng == 0) return true;

            var distance = CalculateDistanceInMeters(merchantLat, merchantLng, customerLat, customerLng);
            return distance <= coverageInMeters;
        }
    }
}
