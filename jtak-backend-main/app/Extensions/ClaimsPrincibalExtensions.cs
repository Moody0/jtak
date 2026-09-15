using System;
using System.Security.Claims;
using static OpenIddict.Abstractions.OpenIddictConstants;

namespace App.Extensions
{
    public static class ClaimsPrincibalExtensions
    {
        public static Guid? GetUserId(this ClaimsPrincipal claims)
        {
            if (claims?.Identity?.IsAuthenticated != true) return null;
            var raw = claims.FindFirst(Claims.Subject)?.Value ?? claims.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrWhiteSpace(raw) && Guid.TryParse(raw, out var guid))
            {
                return guid;
            }
            return null;
        }
        public static string GetUserEmail(this ClaimsPrincipal claims) =>
            claims?.FindFirst(Claims.Email)?.Value ?? claims?.FindFirst(ClaimTypes.Email)?.Value;
        public static string GetUserName(this ClaimsPrincipal claims) =>
            claims?.FindFirst(Claims.Name)?.Value ?? claims?.FindFirst(ClaimTypes.Name)?.Value;
        public static string GetRole(this ClaimsPrincipal claims) =>
            claims?.FindFirst(Claims.Role)?.Value ?? claims?.FindFirst(ClaimTypes.Role)?.Value;
        public static string GetUserPicture(this ClaimsPrincipal claims) =>
            claims?.FindFirst("ProfileImage")?.Value;
    }
}
