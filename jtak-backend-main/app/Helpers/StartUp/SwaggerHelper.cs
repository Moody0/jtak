using App.Resources;
using App.Shared.Services.Helpers;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerUI;
using System;
using System.Collections.Generic;
using System.Linq;
using static OpenIddict.Abstractions.OpenIddictConstants;

namespace App.Helpers.StartUp
{
    public static class SwaggerHelper
    {
        private static string[] BFFs = new[] { "admin", "customer", "warehouse", "delivery", "authorization", "services" };
        public static IServiceCollection AddOpenApiDocuments(this IServiceCollection services, params string[] versions)
        {
            services.AddSwaggerGen(c =>
            {
                foreach (var version in versions)
                {
                    foreach (var BFF in BFFs)
                    {
                        var docName = string.Join("-", version, BFF);
                        c.SwaggerDoc(docName, new OpenApiInfo
                        {

                            Version = version,
                            Title = $"{_Common.SiteName} API",
                            Description = $"{_Common.SiteName} API documentation",
                            Contact = new OpenApiContact { Name = "Speed of Light", Email = "info@sol-gr.com", Url = new System.Uri("https://sol-gr.com") }
                        });
                    }
                }
                c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
                {
                    Description = "OAuth",
                    Name = "Authorization",
                    In = ParameterLocation.Header,
                    Type = SecuritySchemeType.OAuth2,
                    Scheme = "Bearer",

                    Flows = new OpenApiOAuthFlows()
                    {
                        Password = new OpenApiOAuthFlow()
                        {
                            Scopes = new Dictionary<string, string>
                                    {
                                        {Scopes.OpenId, nameof(Scopes.OpenId) },
                                        {Scopes.Email, nameof(Scopes.Email)},
                                        {Scopes.Profile, nameof(Scopes.Profile) },
                                        {Scopes.Roles, nameof(Scopes.Roles) },
                                        {Scopes.Phone, nameof(Scopes.Phone) },
                                        {Scopes.OfflineAccess, nameof(Scopes.OfflineAccess) }
                                    },
                            TokenUrl = new Uri(AppDomainHelper.ApiUrl + "/connect/token"),
                        }
                    }
                });

                c.AddSecurityRequirement(new OpenApiSecurityRequirement()
                {
                    {
                        new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            },
                            Scheme = "oauth2",
                            Name = "Bearer",
                            In = ParameterLocation.Header,

                        },
                        new List<string>()
                    }
                });
                //c.EnableAnnotations();
                c.ResolveConflictingActions(apiDescriptions => apiDescriptions.First());
                c.DocInclusionPredicate((docName, description) => docName == description.GroupName);
            });
            return services;
        }
        public static IApplicationBuilder UseSwaggerWithConfiguration(this IApplicationBuilder app, params string[] versions)
        {
            app.UseSwagger(o =>
            {
                //o.PostProcess = (document, request) =>
                //{
                //    if (request.Headers.ContainsKey("X-Forwarded-Host"))
                //    {
                //        document.Host = request.Headers["X-Forwarded-Host"].First();
                //    }
                //};
                o.RouteTemplate = "/" + AppDomainHelper.SwaggerGuid + "/{documentname}/swagger.json";
            });
            app.UseSwaggerUI(o =>
            {
                // HACK: Temporary solution for working when behind reverse proxy
                //o.TransformToExternalPath = (internalUiRoute, request) =>
                //    {
                //        // HACK: Redirect from \swagger to \swagger\index.html
                //        if (request.PathBase + request.Path == internalUiRoute)
                //            return internalUiRoute;
                //
                //        // HACK: same as before for redirect
                //        var externalPath = request.Headers.ContainsKey("X-Forwarded-Path") ? request.Headers["X-Forwarded-Path"].First() : request.PathBase.Value;
                //
                //        return externalPath + internalUiRoute;
                //    };
                //

                o.RoutePrefix = AppDomainHelper.SwaggerGuid;
                foreach (var version in versions)
                {
                    foreach (var BFF in BFFs)
                    {
                        var docName = string.Join("-", version, BFF);
                        o.SwaggerEndpoint($"/{AppDomainHelper.SwaggerGuid}/{docName}/swagger.json", $"{docName}");
                    }
                }
                o.InjectStylesheet("/swagger-ui/custom.css");
                o.DocExpansion(DocExpansion.None);

                o.OAuthAppName("Demo API - Swagger");
                o.OAuthUsePkce();
            });
            return app;
        }
    }
}