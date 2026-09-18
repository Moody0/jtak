using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace App.Shared.Services
{
    public static class AuditSanitizer
    {
        private static readonly HashSet<string> SensitiveKeyWords = new(StringComparer.OrdinalIgnoreCase)
        {
            "password", "pwd", "pass", "secret", "token", "accesstoken", "access_token",
            "refreshtoken", "refresh_token", "apikey", "api_key", "key", "authorization",
            "bearer", "auth", "otp", "otpcode", "pin", "cvv", "cvc", "cookie", "cookies",
            "session", "privatekey", "private_key"
        };

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

        private static readonly Regex BearerTokenRegex = new(
            @"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*",
            RegexOptions.Compiled);

        private static readonly Regex KeyValueSecretRegex = new(
            @"(?i)(password|secret|token|otp|pin|apikey|api_key|auth|bearer|cookie|session)\s*[:=]\s*([^\s,;""']+)",
            RegexOptions.Compiled);

        public static string SanitizeText(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return text;
            var result = BearerTokenRegex.Replace(text, "Bearer [REDACTED]");
            result = KeyValueSecretRegex.Replace(result, "$1: [REDACTED]");
            return result;
        }

        public static string Sanitize(object value)
        {
            if (value == null) return null;

            if (value is string str)
            {
                if (string.IsNullOrWhiteSpace(str)) return str;
                try
                {
                    var parsedNode = JsonNode.Parse(str);
                    if (parsedNode != null)
                    {
                        SanitizeNode(parsedNode);
                        return parsedNode.ToJsonString(JsonOptions);
                    }
                    return SanitizeText(str);
                }
                catch
                {
                    return SanitizeText(str);
                }
            }

            try
            {
                var jsonNode = JsonSerializer.SerializeToNode(value, JsonOptions);
                if (jsonNode != null)
                {
                    SanitizeNode(jsonNode);
                    return jsonNode.ToJsonString(JsonOptions);
                }
            }
            catch (Exception)
            {
                return SanitizeText(value.ToString());
            }

            return null;
        }

        private static void SanitizeNode(JsonNode node)
        {
            if (node is JsonObject obj)
            {
                var keys = new List<string>();
                foreach (var kvp in obj)
                {
                    keys.Add(kvp.Key);
                }

                foreach (var key in keys)
                {
                    if (IsSensitiveKey(key))
                    {
                        obj[key] = "[REDACTED]";
                    }
                    else if (obj[key] != null)
                    {
                        SanitizeNode(obj[key]);
                    }
                }
            }
            else if (node is JsonArray arr)
            {
                foreach (var item in arr)
                {
                    if (item != null)
                    {
                        SanitizeNode(item);
                    }
                }
            }
        }

        private static bool IsSensitiveKey(string key)
        {
            if (string.IsNullOrWhiteSpace(key)) return false;
            var lower = key.ToLowerInvariant();

            foreach (var word in SensitiveKeyWords)
            {
                if (lower.Contains(word))
                    return true;
            }
            return false;
        }
    }
}
