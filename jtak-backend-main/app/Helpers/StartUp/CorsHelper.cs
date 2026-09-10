using App.Shared.Services.Helpers;
using Microsoft.Extensions.DependencyInjection;

namespace App.Helpers.StartUp
{
    public static class CorsHelper
    {
        public static IServiceCollection AddCommonCors(this IServiceCollection services)
        {
            services.AddCors(options =>
             {
                 options.AddDefaultPolicy(
                 builder =>
                 {
                     builder.AllowCredentials()
                            .WithOrigins("*",
                            "https://localhost:5001",
                            "https://localhost:4200",
                            "http://localhost:4200",
                            AppDomainHelper.BaseUrl,
                            AppDomainHelper.DashboardUrl)
                            .SetIsOriginAllowedToAllowWildcardSubdomains()
                            .AllowAnyHeader()
                            .AllowCredentials()
                            .AllowAnyMethod();

                 });
             });

            return services;
        }
    }
}
