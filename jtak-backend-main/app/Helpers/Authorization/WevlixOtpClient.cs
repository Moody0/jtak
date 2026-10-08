using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace App.Helpers.Authorization
{
    public sealed class CustomerOtpException : Exception
    {
        public int StatusCode { get; }
        public CustomerOtpException(string message, int statusCode = 400) : base(message) => StatusCode = statusCode;
    }

    public sealed class WevlixOtpClient
    {
        private readonly HttpClient _http;
        private readonly IConfiguration _configuration;
        private readonly ILogger<WevlixOtpClient> _logger;
        public WevlixOtpClient(HttpClient http, IConfiguration configuration, ILogger<WevlixOtpClient> logger)
        {
            _http = http;
            _configuration = configuration;
            _logger = logger;
            _http.BaseAddress = new Uri("https://api.wevlix.com/");
            _http.Timeout = TimeSpan.FromSeconds(20);
        }

        public async Task<string> SendAsync(string phone, string code, Guid challengeId)
        {
            var data = await PostAsync("v1/otp/send", new
            {
                to = phone, otpMode = "provided", code,
                clientMessageId = "jtak_customer_" + challengeId.ToString("N"),
                locale = _configuration["Authentication:Wevlix:Locale"] ?? "ar",
                countryIso2 = "SY"
            });
            if (!data.TryGetProperty("messageId", out var id) || string.IsNullOrWhiteSpace(id.GetString()))
                throw Unavailable();
            // A production customer must never receive simulated delivery.
            if (data.TryGetProperty("simulated", out var simulated) && simulated.ValueKind == JsonValueKind.True)
                throw Unavailable();
            return id.GetString();
        }

        public async Task<bool> VerifyAsync(string messageId, string code)
        {
            var data = await PostAsync("v1/otp/verify", new { messageId, code }, verifying: true);
            return data.ValueKind == JsonValueKind.Object &&
                data.TryGetProperty("verified", out var verified) && verified.ValueKind == JsonValueKind.True;
        }

        private async Task<JsonElement> PostAsync(string path, object payload, bool verifying = false)
        {
            var key = _configuration["Authentication:Wevlix:ApiKey"];
            if (string.IsNullOrWhiteSpace(key)) throw Unavailable();
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, path);
                request.Headers.Add("X-API-Key", key);
                request.Content = JsonContent.Create(payload);
                using var response = await _http.SendAsync(request);
                if (verifying && (int)response.StatusCode == 400) return default;
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Wevlix OTP operation {Operation} returned HTTP {Status}", path, (int)response.StatusCode);
                    throw Unavailable();
                }
                using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
                var root = document.RootElement;
                if (!root.TryGetProperty("success", out var success) || success.ValueKind != JsonValueKind.True ||
                    !root.TryGetProperty("data", out var data) || data.ValueKind != JsonValueKind.Object)
                    throw Unavailable();
                return data.Clone();
            }
            catch (HttpRequestException) { throw Unavailable(); }
            catch (TaskCanceledException) { throw Unavailable(); }
            catch (JsonException) { throw Unavailable(); }
        }

        private static CustomerOtpException Unavailable() => new CustomerOtpException(
            "تعذر التواصل مع خدمة رمز التحقق. يرجى المحاولة لاحقاً.", 503);
    }
}
