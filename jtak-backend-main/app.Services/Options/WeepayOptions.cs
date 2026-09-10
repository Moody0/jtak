using System.Text.Json.Serialization;

namespace App.Shared.Services.Options
{
    public class WeepayOptions
    {
        [JsonPropertyName("bayiId")]
        public long BayiId { get; set; }

        [JsonPropertyName("apiKey")]
        public string ApiKey { get; set; }

        [JsonPropertyName("secretKey")]
        public string SecretKey { get; set; }
    }
}
