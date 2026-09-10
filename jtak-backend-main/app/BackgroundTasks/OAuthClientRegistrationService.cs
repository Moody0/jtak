using Microsoft.Extensions.DependencyInjection;
using OpenIddict.Abstractions;
using System;
using System.Globalization;
using System.Threading.Tasks;
using static OpenIddict.Abstractions.OpenIddictConstants;

namespace App.BackgroundTasks
{
    public class OAuthClientRegistrationService
    {
        public static async Task RegisterApplicationsAsync(IServiceProvider provider)
        {
            var manager = provider.GetRequiredService<IOpenIddictApplicationManager>();

            // Angular UI client
            if (await manager.FindByClientIdAsync("4city-client") is null)
            {
                await manager.CreateAsync(new OpenIddictApplicationDescriptor
                {
                    ClientId = "4city-client",
                    ConsentType = ConsentTypes.Explicit,
                    DisplayName = "4city client PKCE",
                    DisplayNames =
                        {
                            [CultureInfo.GetCultureInfo("fr-FR")] = "4city client MVC"
                        },
                    PostLogoutRedirectUris = { new Uri("https://localhost:5005") },
                    RedirectUris = { new Uri("https://localhost:5005") },
                    Permissions =
                        {
                            Permissions.Endpoints.Authorization,
                            Permissions.Endpoints.Logout,
                            Permissions.Endpoints.Token,
                            Permissions.Endpoints.Revocation,
                            Permissions.GrantTypes.AuthorizationCode,
                            Permissions.GrantTypes.RefreshToken,
                            Permissions.ResponseTypes.Code,
                            Permissions.Scopes.Phone,
                            Permissions.Scopes.Email,
                            Permissions.Scopes.Profile,
                            Permissions.Scopes.Roles,
                            Permissions.Prefixes.Scope + "4cityDataRecords"
                        },
                    Requirements =
                        {
                            Requirements.Features.ProofKeyForCodeExchange
                        }
                });
            }

            // API
            if (await manager.FindByClientIdAsync("rs_4cityDataRecordsApi") == null)
            {
                await manager.CreateAsync(new OpenIddictApplicationDescriptor
                {
                    ClientId = "rs_4cityDataRecordsApi",
                    ClientSecret = "4cityDataRecordsSecret",
                    Permissions = { Permissions.Endpoints.Introspection }
                });
            }
        }

        public static async Task RegisterScopesAsync(IServiceProvider provider)
        {
            var manager = provider.GetRequiredService<IOpenIddictScopeManager>();

            if (await manager.FindByNameAsync("4cityDataRecords") is null)
            {
                await manager.CreateAsync(new OpenIddictScopeDescriptor
                {
                    DisplayName = "4cityDataRecords API access",
                    DisplayNames =
                        {
                            [CultureInfo.GetCultureInfo("fr-FR")] = "Accès à l'API de démo"
                        },
                    Name = "4cityDataRecords",
                    Resources =
                        {
                            "rs_4cityDataRecordsApi"
                        }
                });
            }
        }
    }
}
