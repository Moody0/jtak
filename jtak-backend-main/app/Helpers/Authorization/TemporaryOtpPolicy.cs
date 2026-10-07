using Microsoft.Extensions.Configuration;

namespace App.Helpers.Authorization
{
    // Until an OTP service is configured, challenge creation and token exchange
    // use this fixed code. Explicitly disable temporary mode to enable real OTP.
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
