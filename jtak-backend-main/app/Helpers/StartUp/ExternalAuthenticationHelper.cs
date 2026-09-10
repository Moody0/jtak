using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenIddict.Validation.AspNetCore;

namespace App.Helpers.StartUp
{
    public static class ExternalAuthenticationHelper
    {
        public static IServiceCollection AddExternalAuthentication(this IServiceCollection services, IConfiguration Configuration)
        {
            services.AddAuthentication(options =>
            {
                options.DefaultScheme = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme;
            });
            //.AddGoogle("Google", options =>
            //{
            //    options.ClientId = Configuration["GoogleAuthOptions:WebClientId"];
            //    options.ClientSecret = Configuration["GoogleAuthOptions:WebClientSecret"];
            //    options.AccessType = "offline";
            //
            //    //options.SignInScheme = Microsoft.AspNetCore.AuthentAication.Cookies.CookieAuthenticationDefaults.AuthenticationScheme;
            //    options.SaveTokens = true;
            //
            //    options.Scope.Add("profile");
            //    options.Scope.Add("email");
            //    options.Scope.Add("openid");
            //    options.ClaimActions.MapJsonSubKey("ProfileImage", "image", "url");
            //    options.Events.OnCreatingTicket = context =>
            //    {
            //        var token = new TokenResponse
            //        {
            //            AccessToken = context.AccessToken,
            //            RefreshToken = context.RefreshToken,
            //            TokenType = context.TokenType,
            //            Scope = context.TokenResponse.Response.RootElement.GetProperty("scope").ToString(),
            //            IdToken = context.TokenResponse.Response.RootElement.GetProperty("id_token").ToString(),
            //            ExpiresInSeconds = Convert.ToInt64(context.TokenResponse.ExpiresIn),
            //            IssuedUtc = DateTime.UtcNow
            //        };
            //        context.Identity.AddClaim(new Claim("ExternalTokenResponse", JsonSerializer.Serialize(token)));
            //        return Task.CompletedTask;
            //    };
            //    //options.ClaimActions.MapCustomJson("ProfileImage", claim => (string)claim.SelectToken("picture"));
            //})
            //.AddGoogle("Google2", options =>
            //{
            //    // Google sign in for drive syncing
            //    options.ClientId = Configuration["GoogleAuthOptions:WebClient2Id"];
            //    options.ClientSecret = Configuration["GoogleAuthOptions:WebClient2Secret"];
            //    options.AccessType = "offline";
            //
            //    options.SaveTokens = true;
            //    options.CallbackPath = "/signin-google-drive";
            //
            //    options.Scope.Add(DriveService.Scope.DriveReadonly);
            //    options.Scope.Add(DriveService.Scope.DriveFile);
            //
            //    options.Events.OnCreatingTicket = context =>
            //    {
            //        var token = new TokenResponse
            //        {
            //            AccessToken = context.AccessToken,
            //            TokenType = context.TokenType,
            //            ExpiresInSeconds = Convert.ToInt64(context.TokenResponse.ExpiresIn),
            //            RefreshToken = context.RefreshToken,
            //            Scope = context.TokenResponse.Response.RootElement.GetProperty("scope").ToString(),
            //            IdToken = context.TokenResponse.Response.RootElement.GetProperty("id_token").ToString(),
            //            IssuedUtc = DateTime.UtcNow
            //        };
            //        context.Identity.AddClaim(new Claim("ExternalTokenResponse", JsonSerializer.Serialize(token)));
            //        return Task.CompletedTask;
            //    };
            //})
            //.AddFacebook(options =>
            //{
            //    options.AppId = Configuration["FacebookAuthOptions:AppId"];
            //    options.AppSecret = Configuration["FacebookAuthOptions:AppSecret"];
            //    options.Scope.Add("email");
            //    options.Fields.Add("picture.width(512).height(512)");
            //    options.Fields.Add("email");
            //    //options.ClaimActions.MapCustomJson("ProfileImage", claim => (string)claim.SelectToken("picture.data.url"));
            //
            //    //options.Events.OnCreatingTicket = context =>
            //    //{
            //    //    var facebookClient = new FacebookClient();
            //    //    var longLivedToken = await facebookClient.GetLognLivedTokenAsync(context.AccessToken);
            //    //    context.Identity.AddClaim(new Claim("ExternalAccessToken", longLivedToken));
            //    //    context.Identity.AddClaim(new Claim("ProfileImage", (string)context.User["picture"]["data"]["url"]));
            //    //    return Task.CompletedTask;
            //    //};
            //    options.Events.OnCreatingTicket = c => Task.CompletedTask;
            //});
            return services;
        }
    }
}
