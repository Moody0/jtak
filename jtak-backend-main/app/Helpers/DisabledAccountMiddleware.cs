using System;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using App.Shared.Entities;
using App.Extensions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using OpenIddict.Validation.AspNetCore;

namespace App.Helpers
{
    /// <summary>
    /// Stops already-issued access tokens from being used after an administrator
    /// deactivates the account. Token validation alone cannot see IsActive because
    /// the access token remains valid until its normal expiry time.
    /// </summary>
    public sealed class DisabledAccountMiddleware
    {
        private const string DisabledMessage =
            "تم تعطيل حسابك. يرجى التواصل مع الدعم الفني على الرقم 0985 615 705 أو واتساب +963985615705.";

        private readonly RequestDelegate _next;

        public DisabledAccountMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context, UserManager<AppUser> userManager)
        {
            // Use the API bearer scheme explicitly. The default authentication
            // scheme can be the dashboard cookie and leave Context.User empty.
            var principal = context.User;
            if (context.Request.Headers.Authorization.ToString().StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var bearer = await context.AuthenticateAsync(OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme);
                if (bearer.Succeeded && bearer.Principal != null)
                    principal = bearer.Principal;
            }

            if (principal?.Identity?.IsAuthenticated == true)
            {
                var user = await userManager.GetUserAsync(principal)
                    ?? (principal.GetUserId() is Guid userId
                        ? await userManager.FindByIdAsync(userId.ToString())
                        : null);
                // A missing identity record means the account was physically
                // deleted. Do not let its still-valid JWT bypass the same
                // rejection used for soft-deleted and disabled accounts.
                if (user == null || user.DeletionDate != null || !user.IsActive)
                {
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    context.Response.ContentType = "application/json; charset=utf-8";
                    await context.Response.WriteAsync(JsonSerializer.Serialize(new
                    {
                        error = "ACCOUNT_DISABLED",
                        errorDescription = DisabledMessage
                    }));
                    return;
                }
                var tokenRoles=principal.Claims.Where(c=>c.Type==ClaimTypes.Role || c.Type==OpenIddict.Abstractions.OpenIddictConstants.Claims.Role).Select(c=>c.Value).Distinct().ToArray();
                if(tokenRoles.Length>0) {
                    var roles=await userManager.GetRolesAsync(user);
                    if(roles!=null && tokenRoles.Any(role=>!roles.Contains(role,StringComparer.OrdinalIgnoreCase))) {
                        context.Response.StatusCode=StatusCodes.Status401Unauthorized;
                        context.Response.ContentType="application/json; charset=utf-8";
                        await context.Response.WriteAsync(JsonSerializer.Serialize(new {error="ACCOUNT_ROLE_CHANGED",errorDescription="تغيّرت صلاحيات حسابك. حدّث تسجيل الدخول."}));
                        return;
                    }
                }
            }

            await _next(context);
        }
    }
}
