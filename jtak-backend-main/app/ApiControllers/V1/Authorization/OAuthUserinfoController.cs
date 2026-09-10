using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using OpenIddict.Abstractions;
using OpenIddict.Server.AspNetCore;
using static OpenIddict.Abstractions.OpenIddictConstants;
using App.Extensions;
using App.Shared.Entities;
using App.Shared.Services;
using System.Linq;
using App.Shared.Entities.Enums;

namespace App.ApiControllers.V1.Authorization
{
    [ApiController]
    [ApiVersion("1")]
    public class OAuthUserinfoController : Controller
    {
        private readonly INotificationService _notifService;
        private readonly UserManager<AppUser> _userManager;

        public OAuthUserinfoController(UserManager<AppUser> userManager, INotificationService notifService)
        {
            _userManager = userManager;
            _notifService = notifService;
        }

        [Authorize(AuthenticationSchemes = OpenIddictServerAspNetCoreDefaults.AuthenticationScheme)]
        [HttpGet("~/connect/userinfo"), HttpPost("~/connect/userinfo")]
        [IgnoreAntiforgeryToken, Produces("application/json")]
        public async Task<IActionResult> Userinfo()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user is null)
            {
                return Challenge(
                    authenticationSchemes: OpenIddictServerAspNetCoreDefaults.AuthenticationScheme,
                    properties: new AuthenticationProperties(new Dictionary<string, string>
                    {
                        [OpenIddictServerAspNetCoreConstants.Properties.Error] = Errors.InvalidToken,
                        [OpenIddictServerAspNetCoreConstants.Properties.ErrorDescription] = "The specified access token is bound to an account that no longer exists."
                    }));
            }

            var uid = await _userManager.GetUserIdAsync(user);

            var claims = new Dictionary<string, object>(StringComparer.Ordinal)
            {
                // Note: the "sub" claim is a mandatory claim and must be included in the JSON response.
                [Claims.Subject] = uid,
                ["Id"] = uid
            };

            if (User.HasScope(Scopes.Email))
            {
                claims[Claims.Email] = await _userManager.GetEmailAsync(user);
                claims[Claims.EmailVerified] = await _userManager.IsEmailConfirmedAsync(user);
            }

            if (User.HasScope(Scopes.Phone))
            {
                claims[Claims.PhoneNumber] = await _userManager.GetPhoneNumberAsync(user);
                claims[Claims.PhoneNumberVerified] = await _userManager.IsPhoneNumberConfirmedAsync(user);
            }

            if (User.HasScope(Scopes.Roles))
            {
                claims[Claims.Role] = (int)((await _userManager.GetRoleNamesAsync(user))?.FirstOrDefault() ?? AppRoleName.Customer);
            }

            if (User.HasScope(Scopes.Profile))
            {
                claims["firstName"] = user.FirstName;
                claims["lastName"] = user.LastName;
                claims["fullName"] = user.FullName;
                claims["birthday"] = user.Birthday?.ToString("O");
                claims[Claims.Picture] = Url.ImgHref(user.ProfilePhoto);
                claims["UserTopicId"] = _notifService.GetUserTopic(user.Id);
            }

            // Note: the complete list of standard claims supported by the OpenID Connect specification
            // can be found here: http://openid.net/specs/openid-connect-core-1_0.html#StandardClaims

            return Ok(claims);
        }
    }
}
