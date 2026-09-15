using App.Shared.Data.App;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using System;
using System.IO;
using System.Security.Cryptography;
using static OpenIddict.Abstractions.OpenIddictConstants;

namespace App.Helpers.StartUp
{
    public static class OpenIddictHelper
    {
        public static IServiceCollection AddAuthServerOpenIddict(this IServiceCollection services)
        {
            services.AddOpenIddict()
                .AddCore(o => o.UseEntityFrameworkCore().UseDbContext<AppDbContext>().ReplaceDefaultEntities<Guid>())
                // Register the OpenIddict server handler.
                .AddServer(options =>
                {
                    options.SetAuthorizationEndpointUris("/connect/authorize")
                           .SetDeviceEndpointUris("/connect/device")
                           .SetLogoutEndpointUris("/connect/logout")
                           .SetIntrospectionEndpointUris("/connect/introspect")
                           .SetTokenEndpointUris("/connect/token")
                           .SetUserinfoEndpointUris("/connect/userinfo")
                           .SetVerificationEndpointUris("/connect/verify");
                    
                    options.SetAccessTokenLifetime(TimeSpan.FromDays(1));

                    options.AllowAuthorizationCodeFlow().RequireProofKeyForCodeExchange() // Enable PKCE
                           .AllowPasswordFlow()
                           .AllowDeviceCodeFlow()
                           .AllowHybridFlow()
                           .AllowRefreshTokenFlow()
                           .AllowCustomFlow(SolGrantTypes.SMSCodeGrantType);
                    //.AllowCustomFlow(SolGrantTypes.FacebookGrantType);

                    // Accept anonymous clients (i.e clients that don't send a client_id).
                    options.AcceptAnonymousClients();

                    // Register scopes (permissions)
                    // Scope: a way of scoping Access Token to a limited set of claims or user data
                    options.RegisterScopes(Scopes.Email, Scopes.Phone, Scopes.Profile, Scopes.Roles, "4cityDataRecords");

                    options.UseDataProtection();

                    // Register the signing and encryption credentials.
                    //var certStore = new X509Store(StoreName.My, StoreLocation.LocalMachine);
                    //certStore.Open(OpenFlags.ReadOnly);
                    //var certCollection = certStore.Certificates.Find(X509FindType.FindBySubjectName, AppDomainHelper.BaseDomain, false);
                    //var array = new X509Certificate2[certCollection.Count];
                    //certCollection.CopyTo(array, 0);

                    // Find the required cert
                    // currently stopped bacause it needs manual work: allowing IIS_IUSRS to manage private key permission
                    // https://stackoverflow.com/questions/2609859/how-to-give-asp-net-access-to-a-private-key-in-a-certificate-in-the-certificate
                    //var cert = array.FirstOrDefault(x => x.Subject == /*"CN=" +*/ AppDomainHelper.BaseDomain);
                    //if (cert != null)
                    //{
                    //    //File.WriteAllText("c:\\inetpub\\vhosts\\rb.kuarkz.com\\httpdocs\\FileCenter\\cert.txt", "cert:" + cert?.Subject + ":" + cert?.Thumbprint);
                    //    options.AddEncryptionCertificate(cert);
                    //    options.AddSigningCertificate(cert);
                    //}
                    ConfigureSigningAndEncryptionKeys(options);

                    //options.AddDevelopmentEncryptionCertificate().AddDevelopmentSigningCertificate();

                    //options.AddEncryptionKey().AddEncryptionCertificate();
                    // Register the ASP.NET Core host and configure the ASP.NET Core-specific options.
                    options.UseAspNetCore()
                           .EnableTokenEndpointPassthrough()
                           .EnableAuthorizationEndpointPassthrough()
                           .EnableUserinfoEndpointPassthrough()
                           .EnableStatusCodePagesIntegration()
                           .EnableLogoutEndpointPassthrough()
                           .EnableVerificationEndpointPassthrough();
                })
                .AddValidation(options =>
                {
                    // Note: the validation handler uses OpenID Connect discovery
                    // to retrieve the address of the introspection endpoint.

                    // Audience: a way for the consuming party to validate if a token is meant for them or not.
                    //options.AddAudiences("rs_4cityDataRecordsApi");

                    // Register the System.Net.Http integration.
                    options.UseSystemNetHttp();

                    options.UseLocalServer();
                    options.UseAspNetCore();
                    options.UseDataProtection();
                });

            return services;
        }
        public static IServiceCollection AddSimpleServerOpenIddict(this IServiceCollection services, params string[] versions)
        {
            services.AddOpenIddict()
                .AddCore(o => o.UseEntityFrameworkCore().UseDbContext<AppDbContext>().ReplaceDefaultEntities<Guid>())
                // Register the OpenIddict server handler.
                .AddServer(options =>
                {
                    options.SetTokenEndpointUris("/connect/token")
                           .SetUserinfoEndpointUris("/connect/userinfo");

                    options.AllowPasswordFlow()
                           .AllowRefreshTokenFlow()
                           .AllowCustomFlow(SolGrantTypes.SMSCodeGrantType);
                    options.SetAccessTokenLifetime(TimeSpan.FromDays(180));
                    //.AllowCustomFlow(SolGrantTypes.FacebookGrantType);

                    // Accept anonymous clients (i.e clients that don't send a client_id).
                    options.AcceptAnonymousClients();

                    // Register scopes (permissions)
                    // Scope: a way of scoping Access Token to a limited set of claims or user data
                    options.RegisterScopes(Scopes.Email, Scopes.Phone, Scopes.Profile, Scopes.Roles, Scopes.OfflineAccess);

                    options.UseDataProtection();

                    // Register the signing and encryption credentials.
                    //var certStore = new X509Store(StoreName.My, StoreLocation.LocalMachine);
                    //certStore.Open(OpenFlags.ReadOnly);
                    //var certCollection = certStore.Certificates.Find(X509FindType.FindBySubjectName, AppDomainHelper.BaseDomain, false);
                    //var array = new X509Certificate2[certCollection.Count];
                    //certCollection.CopyTo(array, 0);

                    // Find the required cert
                    // currently stopped bacause it needs manual work: allowing IIS_IUSRS to manage private key permission
                    // https://stackoverflow.com/questions/2609859/how-to-give-asp-net-access-to-a-private-key-in-a-certificate-in-the-certificate
                    //var cert = array.FirstOrDefault(x => x.Subject == /*"CN=" +*/ AppDomainHelper.BaseDomain);
                    //if (cert != null)
                    //{
                    //    //File.WriteAllText("c:\\inetpub\\vhosts\\rb.kuarkz.com\\httpdocs\\FileCenter\\cert.txt", "cert:" + cert?.Subject + ":" + cert?.Thumbprint);
                    //    options.AddEncryptionCertificate(cert);
                    //    options.AddSigningCertificate(cert);
                    //}
                    ConfigureSigningAndEncryptionKeys(options);
                    //options.AddDevelopmentEncryptionCertificate().AddDevelopmentSigningCertificate();

                    //options.AddEncryptionKey().AddEncryptionCertificate();
                    // Register the ASP.NET Core host and configure the ASP.NET Core-specific options.
                    options.UseAspNetCore()
                           .EnableTokenEndpointPassthrough()
                           .EnableUserinfoEndpointPassthrough()
                           .EnableStatusCodePagesIntegration();
                })
                .AddValidation(options =>
                {
                    // Note: the validation handler uses OpenID Connect discovery
                    // to retrieve the address of the introspection endpoint.

                    // Audience: a way for the consuming party to validate if a token is meant for them or not.
                    // options.AddAudiences("rs_4cityDataRecordsApi");

                    // Register the System.Net.Http integration.
                    options.UseSystemNetHttp();

                    options.UseLocalServer();
                    options.UseAspNetCore();
                    options.UseDataProtection();
                });

            return services;
        }

        private static void ConfigureSigningAndEncryptionKeys(OpenIddictServerBuilder options)
        {
            try
            {
                var keysFolder = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "keys");
                if (!Directory.Exists(keysFolder))
                {
                    Directory.CreateDirectory(keysFolder);
                }
                var keyPath = Path.Combine(keysFolder, "openiddict-key.xml");
                RSA rsa;
                if (File.Exists(keyPath))
                {
                    rsa = RSA.Create();
                    rsa.FromXmlString(File.ReadAllText(keyPath));
                }
                else
                {
                    rsa = RSA.Create(2048);
                    File.WriteAllText(keyPath, rsa.ToXmlString(true));
                }
                var key = new RsaSecurityKey(rsa);
                options.AddSigningKey(key);
                options.AddEncryptionKey(key);
            }
            catch
            {
                options.AddEphemeralEncryptionKey();
                options.AddEphemeralSigningKey();
            }
        }
    }
}