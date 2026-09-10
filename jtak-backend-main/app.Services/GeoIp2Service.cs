namespace App.Services
{

    //public static class GeoIp2Service
    //{
    //    public static LocationInfo GetLocationInfo(this Microsoft.AspNetCore.Hosting.IWebHostEnvironment _env, string ipAddress)
    //    {
    //        using var reader = new DatabaseReader(_env.ContentRootPath + "\\MindMax\\GeoLite2-City.mmdb");
    //        var ok = reader.TryCity(ipAddress, out CityResponse city);
    //        return (ok ? new LocationInfo
    //        {
    //            CountryCode = city.Country.IsoCode,
    //            Country = city.Country.Name,
    //            City = city.City.Name,
    //            Latitude = city.Location.Latitude,
    //            Longitude = city.Location.Longitude,
    //        } : null);
    //    }
    //
    //
    //    public class LocationInfo
    //    {
    //        public string CountryCode { get; set; }
    //        public double? Latitude { get; set; }
    //        public double? Longitude { get; set; }
    //        public string Country { get; set; }
    //        public string City { get; set; }
    //        public string PostalCode { get; set; }
    //    }
    //}
}
