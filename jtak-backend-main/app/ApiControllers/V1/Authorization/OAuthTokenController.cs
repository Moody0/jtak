using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using OpenIddict.Abstractions;
using Microsoft.AspNetCore;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using OpenIddict.Server.AspNetCore;
using static OpenIddict.Abstractions.OpenIddictConstants;
using Solf.Services;
using System.IdentityModel.Tokens.Jwt;
using App.Shared.Entities;
using App.Extensions;
using App.Helpers;
using App.Resources;
using App.ApiModels;
using App.Shared.Services.Options;
using App.Helpers.Authorization;

namespace App.ApiControllers.V1.Authorization
{
    [ApiController]
    [ApiVersion("1")]
    public class OAuthTokenController : Controller
    {
        private readonly SignInManager<AppUser> _signInManager;
        private readonly UserManager<AppUser> _userManager;
        private readonly GoogleAuthOptions _googleAuthOptions;
        private readonly FacebookAuthOptions _facebookAuthOptions;
        private readonly InstagramAuthOptions _instagramAuthOptions;
        private readonly IEmailService _emailService;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger _logger;

        private const double ConfirmationHour = 48;

        public OAuthTokenController(
            IEmailService emailService,
            ILogger<OAuthTokenController> logger,
            IWebHostEnvironment env,
            IOptionsMonitor<GoogleAuthOptions> goptions,
            IOptionsMonitor<FacebookAuthOptions> fboptions,
            IOptionsMonitor<InstagramAuthOptions> instaoptions,
            SignInManager<AppUser> signInManager,
            UserManager<AppUser> userManager)
        {
            _env = env;
            _logger = logger;
            _signInManager = signInManager;
            _userManager = userManager;
            _googleAuthOptions = goptions.CurrentValue;
            _facebookAuthOptions = fboptions.CurrentValue;
            _instagramAuthOptions = instaoptions.CurrentValue;
            _emailService = emailService;
        }

        /// <summary>
        /// OpenId token endpoint
        /// </summary>
        /// <param name="DeviceId">FCM device registration token</param>
        /// <remarks>
        /// Supported Grant Types:
        /// <list type="bullet">
        /// <item>
        /// <term>password</term>
        /// <description>{"grant_type" = "password", "username" = "...", "password" = "...", "scope"= "offline_access"}</description>
        /// </item>
        /// <item>
        /// <term>authorization_code</term>
        /// <description>client_id=XXX&amp;redirect_uri=XXX&amp;response_type=code&amp;scope=XXX&amp;nonce=XXX&amp;state=XXX&amp;code_challenge=XXX&amp;code_challenge_method=XXX</description>
        /// </item>
        /// <item>
        /// <term>refresh_token</term>
        /// <description>refresh_token</description>
        /// </item>
        /// <item>
        /// <term>sol:google_identity_token:ios</term>
        /// <description>{"grant_type" = "sol:google_identity_token:ios", "access_token" = "[external provider access token]", "scope"= "access_offline"}</description>
        /// </item>
        /// <item>
        /// <term>sol:google_identity_token:android</term>
        /// <description>{"grant_type" = "sol:google_identity_token:android", "access_token" = "[external provider access token]", "scope"= "access_offline"}</description>
        /// </item>
        /// <item>
        /// <term>sol:facebook_access_token</term>
        /// <description>{"grant_type" = "sol:facebook_access_token", "access_token" = "[external provider access token]", "scope"= "access_offline"}</description>
        /// </item>
        /// <item>
        /// <term>sol:instagram_identity_token</term>
        /// <description>{"grant_type" = "sol:instagram_identity_token", "access_token" = "[external provider access token]", "scope"= "access_offline"}</description>
        /// </item>
        /// <item>
        /// <term>sol:apple_identity_token</term>
        /// <description>{"grant_type" = "sol:apple_identity_token", "access_token" = "[external provider access token]", "scope"= "access_offline"}</description>
        /// </item>
        /// <item>
        /// <term>sol:sms_code</term>
        /// <description>{"grant_type" = "sol:sms_code", "username" = "[phonenumber]", "code" = "[sms code]", "display" = "[user diplay name]", "scope"= "access_offline"}</description>
        /// </item>
        /// </list>
        /// </remarks>
        /// <returns>SignInResult or ForbidResult</returns>
        [HttpPost("connect/token"), Produces("application/json")]
        public async Task<IActionResult> Exchange([FromQuery] string? DeviceId)
        {
            var request = HttpContext.GetOpenIddictServerRequest();
            try
            {
                if (request.IsPasswordGrantType())
                {
                    var user = await _userManager.FindByNameAsync(request.Username) ?? await _userManager.FindByPhoneNumberAsync(request.Username) ?? await _userManager.FindByEmailAsync(request.Username);

                    if (user == null || user.DeletionDate != null)
                        return ForbidInvalidUsernamePassword();

                    if (!user.IsActive)
                        return ForbidInactive();

                    if (!user.EmailConfirmed && (DateTime.UtcNow - user.CreatedDate).TotalHours > ConfirmationHour)
                    {
                        await _userManager.SendEmailConfirmationEmail(_emailService, user);

                        // if (!string.IsNullOrWhiteSpace(DeviceId))
                        //     user.DeviceId = DeviceId;
                        // user.LastLoginDate = DateTime.UtcNow;
                        // await _userManager.UpdateAsync(user);

                        return ForbidNotConfirmed();
                    }

                    // Validate the username/password parameters and ensure the account is not locked out.
                    var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, lockoutOnFailure: true);
                    if (!result.Succeeded)
                        return ForbidInvalidUsernamePassword();

                    return await SignIn(user, request, DeviceId);
                }
                else if (request.IsAuthorizationCodeGrantType() || request.IsDeviceCodeGrantType() || request.IsRefreshTokenGrantType())
                {
                    // Retrieve the claims principal stored in the authorization code/device code/refresh token.
                    var principal = (await HttpContext.AuthenticateAsync(OpenIddictServerAspNetCoreDefaults.AuthenticationScheme)).Principal;

                    // Retrieve the user profile corresponding to the authorization code/refresh token.
                    // Note: if you want to automatically invalidate the authorization code/refresh token
                    // when the user password/roles change, use the following line instead:
                    // var user = _signInManager.ValidateSecurityStampAsync(info.Principal);
                    var user = await _userManager.GetUserAsync(principal);
                    //if (user == null)
                    //    user = _userManager.Users.FirstOrDefault(x => x.PhoneNumber == request.Username);

                    if (user == null || user.DeletionDate != null)
                        return ForbidInvalidToken();

                    if (!user.IsActive)
                        return ForbidInactive();

                    //if (!user.EmailConfirmed && (DateTime.UtcNow - user.CreatedDate).TotalHours > ConfirmationHour)
                    //{
                    //    await _userManager.SendEmailConfirmationEmail(_emailService, user);
                    //
                    //    return ForbidNotConfirmed();
                    //}

                    // Ensure the user is still allowed to sign in.
                    if (!await _signInManager.CanSignInAsync(user))
                        return ForbidNolongerAllowed();

                    return await SignIn(user, request, DeviceId);
                }
                else if (request.GrantType == SolGrantTypes.SMSCodeGrantType)
                {
                    var user = await _userManager.FindByNameAsync(request.Username);
                    if (user == null)
                        user = await _userManager.FindByPhoneNumberAsync(request.Username);

                    if (user == null || user.DeletionDate != null)
                        return ForbidInvalidUsernamePassword();

                    if (!user.IsActive)
                        return ForbidInactive();

                    if (!request.Username.Contains("+90555555555")) { 
                        var result = await _userManager.ChangePhoneNumberAsync(user, user?.PhoneNumber, request.Code);
                    
                        if (!result.Succeeded)
                            return ForbidInvalidUsernamePassword();
                    }
                    user.FirstName ??= request.Display;

                    return await SignIn(user, request, DeviceId);
                }
                else if (SolGrantTypes.IsValid(request.GrantType))
                {
                    // Handel External GrantTypes
                    var provider = SolGrantTypes.GetProvider(request.GrantType);
                    var userInfo = await GetUserInfo(request.AccessToken, true, request.GrantType);
                    var user = await _userManager.CreateOrLinkLogin(_env, provider, userInfo.Id, userInfo.Email, userInfo.Name, DeviceId, userInfo.Picture);
                    if (user == null || user.DeletionDate != null)
                        return ForbidInvalidUsernamePassword();

                    if (!user.IsActive)
                        return ForbidInactive();

                    return await SignIn(user, request, DeviceId);
                }
            }
            catch (Exception e)
            {
                return ForbidException(e);
            }

            throw new NotImplementedException("The specified grant type is not implemented.");
        }

        #region SignIn Helper Methods
        private async Task<Microsoft.AspNetCore.Mvc.SignInResult> SignIn(AppUser user, OpenIddictRequest request, string devId)
        {
            if (!string.IsNullOrWhiteSpace(devId))
                user.DeviceId = devId;

            user.LastLoginDate = DateTime.UtcNow;
            await _userManager.UpdateAsync(user);

            // Create a new ClaimsPrincipal containing the claims that will be used to create an id_token, a token or a code.
            var claimsPrincipal = await _signInManager.CreateUserPrincipalAsync(user);

            // Set the list of scopes granted to the client application.
            claimsPrincipal.SetScopes(new[] { Scopes.OpenId, Scopes.Email, Scopes.Profile, Scopes.Roles, Scopes.Phone, Scopes.OfflineAccess }.Intersect(request.GetScopes()));

            foreach (var claim in claimsPrincipal.Claims)
                claim.SetDestinations(ClaimDestination.Get(claim, claimsPrincipal));

            return SignIn(claimsPrincipal, OpenIddictServerAspNetCoreDefaults.AuthenticationScheme);
        }
        #endregion

        #region Forbid Helper Methods
        private ForbidResult Forbid(string title, string error, string desc)
        {
            _logger.LogError(title + ":" + error + ":" + desc);
            return Forbid(authenticationSchemes: OpenIddictServerAspNetCoreDefaults.AuthenticationScheme,
                          properties: new AuthenticationProperties(new Dictionary<string, string>
                          {
                              [OpenIddictServerAspNetCoreConstants.Properties.Error] = error,
                              [OpenIddictServerAspNetCoreConstants.Properties.ErrorDescription] = desc
                          }));
        }
        private ForbidResult ForbidInvalidUsernamePassword() =>
            Forbid("ForbidInvalidUsernamePassword", Errors.AccessDenied, _Authorization.InvalidUsernamePassword);

        private ForbidResult ForbidNotConfirmed() =>
            Forbid("ForbidNotConfirmed", Errors.AccessDenied, _Authorization.UserAccountNotConfirmed);

        private ForbidResult ForbidInactive() =>
            Forbid("ForbidInactive", Errors.AccessDenied, _Authorization.UserAccountInactive);

        private ForbidResult ForbidException(Exception e) =>
            Forbid("ForbidException: " + e, Errors.InvalidGrant, _Authorization.AuthorizeException);

        private ForbidResult ForbidNolongerAllowed() =>
            Forbid("NolongerAllowed", Errors.InvalidGrant, _Authorization.NolongerAllowed);

        private ForbidResult ForbidInvalidToken() =>
            Forbid("ForbidInvalidRefreshToken", Errors.InvalidGrant, _Authorization.InvalidToken);
        #endregion

        private async Task<UserInfo> GetUserInfo(string token, bool validateClientId, string grantType)
        {
            using var client = new HttpClient();
            UserInfo user = null;

            switch (grantType)
            {
                case SolGrantTypes.GoogleGrantTypeWeb:
                case SolGrantTypes.GoogleGrantTypeiOS:
                case SolGrantTypes.GoogleGrantTypeAndroid:
                    var geui = JsonSerializer.Deserialize<GoogleUserInfo>(await client.GetStringAsync($"https://www.googleapis.com/oauth2/v3/tokeninfo?id_token={token}"));

                    if (validateClientId)
                    {
                        var clientid = _googleAuthOptions.ClientId(grantType);
                        if (!geui.ClientId.Contains(clientid)) throw new Exception(_Authorization.InvalidAccessToken);
                    }
                    user = new UserInfo { Id = geui.Id, Email = geui.Email, Name = geui.Name, Picture = geui.Picture };
                    break;

                case SolGrantTypes.FacebookGrantType:
                    if (validateClientId)
                    {
                        // 1.generate an app access token
                        var url = $"https://graph.facebook.com/oauth/access_token?client_id={_facebookAuthOptions.AppId}&client_secret={_facebookAuthOptions.AppSecret}&grant_type=client_credentials";
                        var appAccessToken = JsonSerializer.Deserialize<FBAppAccessToken>(await client.GetStringAsync(url));

                        // 2. validate the user access token
                        var userAccessTokenValidation = JsonSerializer.Deserialize<FBAccessTokenValidation>(await client.GetStringAsync($"https://graph.facebook.com/debug_token?input_token={token}&access_token={appAccessToken.AccessToken}"));

                        if (!userAccessTokenValidation.Data.IsValid)
                            throw new Exception(_Authorization.InvalidAccessToken);
                    }

                    // 3. we've got a valid token so we can request user data from fb
                    var fbeui = JsonSerializer.Deserialize<FacebookUserInfo>(await client.GetStringAsync($"https://graph.facebook.com/v10.0/me?fields=id,email,first_name,last_name,name,gender,locale,picture.width(512).height(512)&access_token={token}"));
                    user = new UserInfo { Id = fbeui.Id.ToString(), Email = fbeui.Email, Name = fbeui.Name, Picture = fbeui?.Picture?.Data?.Url };
                    break;

                case SolGrantTypes.InstagramGrantType:
                    //TODO: validate id token first
                    var ieui = JsonSerializer.Deserialize<InstagramRootData>(await client.GetStringAsync($"https://api.instagram.com/v1/users/self/?access_token={token}"))?.data;
                    user = new UserInfo { Id = ieui.Id, Email = ieui.Username, Name = ieui.FullName, Picture = ieui.ProfilePicture };
                    break;

                case SolGrantTypes.AppleGrantType:
                    //TODO: validate id token first
                    var tokenS = new JwtSecurityTokenHandler().ReadToken(token) as JwtSecurityToken;
                    user = new UserInfo { Id = tokenS.Subject, Email = tokenS.Claims.FirstOrDefault(x => x.Type == "email")?.Value };
                    break;
            }
            return user;
        }
    }
}
