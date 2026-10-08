using Microsoft.Extensions.Configuration;

namespace App.Helpers.Authorization
{
    // Legacy merchant/delivery OTP mode. Customer signup and token exchange
    // always use CustomerOtpService and never honor this global bypass.
    public static class TemporaryOtpPolicy
    {
        public const string Code = "123456";

        public static bool IsEnabled(IConfiguration configuration)
        {
            var setting = configuration?["Authentication:TemporaryOtpEnabled"];
            if (string.IsNullOrWhiteSpace(setting)) return true;
            return bool.TryParse(setting, out var enabled) && enabled;
        }
    }
}
