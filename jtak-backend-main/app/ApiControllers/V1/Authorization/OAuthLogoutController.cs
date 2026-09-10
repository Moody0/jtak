using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using OpenIddict.Server.AspNetCore;
using App.Shared.Entities;

namespace App.ApiControllers.V1.Authorization
{
    //[ApiVersion("1"), ApiVersion("2")]
    [ApiVersion("1"), ApiExplorerSettings(IgnoreApi = true)]
    public class OAuthLogoutController : Controller
    {
        private readonly SignInManager<AppUser> _signInManager;

        public OAuthLogoutController(SignInManager<AppUser> signInManager) =>
            _signInManager = signInManager;

        // Note: the logout action is only useful when implementing interactive
        // flows like the authorization code flow or the implicit flow.
        [HttpGet("~/connect/logout")]
        public IActionResult Logout() => View("~/Views/Authorization/Logout.cshtml");

        [ActionName(nameof(Logout)), HttpPost("~/connect/logout"), ValidateAntiForgeryToken]
        public async Task<IActionResult> LogoutPost()
        {
            // Ask ASP.NET Core Identity to delete the local and external cookies created
            // when the user agent is redirected from the external identity provider
            // after a successful authentication flow (e.g Google or Facebook).
            await _signInManager.SignOutAsync();

            // Returning a SignOutResult will ask OpenIddict to redirect the user agent
            // to the post_logout_redirect_uri specified by the client application or to
            // the RedirectUri specified in the authentication properties if none was set.
            return SignOut(authenticationSchemes: OpenIddictServerAspNetCoreDefaults.AuthenticationScheme, properties: new AuthenticationProperties { RedirectUri = "/" });
        }
    }
}
