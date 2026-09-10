using System;
using System.Security.Claims;
using static OpenIddict.Abstractions.OpenIddictConstants;

namespace App.Extensions
{
    public static class ClaimsPrincibalExtensions
    {
        public static Guid? GetUserId(this ClaimsPrincipal claims) =>
            claims.Identity.IsAuthenticated ? Guid.Parse(claims?.FindFirst(Claims.Subject)?.Value ?? claims?.FindFirst(ClaimTypes.NameIdentifier)?.Value) : (Guid?)null;
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
