namespace App.Shared.Services.Helpers
{
    public static class AppDomainHelper
    {
        public static string BaseDomain => "jtak.app";
        public static string BaseUrl => $"https://{BaseDomain}";

        public static string ApiDomain => $"api.{BaseDomain}";
        public static string ApiUrl => $"https://{ApiDomain}";

        public static string FrontEndDomain => $"{BaseDomain}";
        public static string FrontEndUrl => $"https://{FrontEndDomain}";

        public static string DashboardDomain => $"dash.{BaseDomain}";
        public static string DashboardUrl => $"https://{DashboardDomain}";



        public static string InfoEmail => $"info@{BaseDomain}";
        public static string AdminEmail => $"admin@{BaseDomain}";
        public static string UserEmail => $"user@{BaseDomain}";
        public static string DeliveryEmail => $"delivery@{BaseDomain}";
        public static string MerchantEmail => $"merchant@{BaseDomain}";

        public static string SwaggerGuid => "2d55ef7d-1d57-4d5f-8741-90910d3f54f4";
    }
}
