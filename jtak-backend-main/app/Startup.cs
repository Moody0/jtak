using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using App.Shared.Entities;
using Solf.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.DataProtection;
using Solf.Permissions;
using System.IO;
using App.Shared.Services;
using App.Helpers;
using AutoMapper;
using Solf.Services;
using App.Shared.Services.Options;
using Solf.Helpers;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.AspNetCore.Mvc.Razor;
using App.Shared.Entities.Resources;
using App.ApiModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using App.Setup;
using static OpenIddict.Abstractions.OpenIddictConstants;
using Microsoft.AspNetCore.SignalR;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Mvc.ApplicationModels;
using App.Helpers.StartUp;
using Modules.Accounting.Data;
using App.Shipping.Data;

namespace App
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddCommonCors();
            services.AddRazorPages()
                    .AddRazorRuntimeCompilation();

            services.AddControllersWithViews()
                    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new DateTimeConverter()));

            services.AddApiVersioning(options =>
            {
                options.DefaultApiVersion = new ApiVersion(1, 0);
                options.AssumeDefaultVersionWhenUnspecified = true;
                options.ReportApiVersions = true;
            });
            services.AddVersionedApiExplorer(options =>
            {
                options.GroupNameFormat = "VVV";
                options.SubstituteApiVersionInUrl = true;
            });
            services.AddAutoMapper(typeof(Startup));
            services.AddSingleton<IActionContextAccessor, ActionContextAccessor>();

            ServerVersion version;
            try
            {
                version = ServerVersion.AutoDetect(Configuration.GetConnectionString("DefaultConnection"));
            }
            catch
            {
                version = new MySqlServerVersion(new Version(8, 0, 28));
            }
            services.AddDbContext<AppDbContext>(o =>
            {
                o.UseMySql(Configuration.GetConnectionString("DefaultConnection"), version);
                o.UseOpenIddict<Guid>();
            });
            services.AddDbContext<CatalogDbContext>(o =>
            {
                o.UseMySql(Configuration.GetConnectionString("CatalogDbConnection"), version);
            });
            services.AddDbContext<OrdersDbContext>(o =>
            {
                o.UseMySql(Configuration.GetConnectionString("OrdersDbConnection"), version);
            });
            services.AddDbContext<AccountingDbContext>(o =>
            {
                o.UseMySql(Configuration.GetConnectionString("AccountingDbConnection"), version);
                o.AddInterceptors(new LedgerImmutabilityInterceptor());
            });
            services.AddDbContext<ShippingDbContext>(o =>
            {
                o.UseMySql(Configuration.GetConnectionString("ShippingDbConnection"), version);
            });

            // Register the Identity services.
            services.AddIdentity<AppUser, SolRole>(/*config => config.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultPhoneProvider*/)
                    .AddUserStore<UserStore<AppUser, SolRole, AppDbContext, Guid, SolUserClaim, SolUserRole, AppUserLogin, SolUserToken, SolRoleClaim>>()
                    .AddRoleStore<RoleStore<SolRole, AppDbContext, Guid, SolUserRole, SolRoleClaim>>()
                    .AddDefaultTokenProviders()
                    .AddErrorDescriber<LocalizedIdentityErrorDescriber>();

            // Configure Identity to use the same JWT claims as OpenIddict instead
            // of the legacy WS-Federation claims it uses by default (ClaimTypes),
            // which saves you from doing the mapping in your authorization controller.
            services.Configure<IdentityOptions>(options =>
            {
                options.ClaimsIdentity.UserNameClaimType = Claims.Name;
                options.ClaimsIdentity.UserIdClaimType = Claims.Subject;
                options.ClaimsIdentity.RoleClaimType = Claims.Role;

                // Default Password settings.
                options.Password.RequireDigit = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireNonAlphanumeric = false;
                options.Password.RequireUppercase = false;
                options.Password.RequiredLength = 6;
                options.Password.RequiredUniqueChars = 1;
            });

            services.AddSimpleServerOpenIddict();

            services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo("keys"));

            services.AddAuthorization(options =>
            {
                foreach (var permission in Enum.GetValues<AppPermissionKey>())
                {
                    options.AddPolicy(permission.ToString(), policy => policy.Requirements.Add(new PermissionRequirement((int)permission)));
                }
            });


            services.AddScoped(typeof(UserManager<AppUser>));
            services.AddScoped(typeof(SignInManager<AppUser>));
            services.AddScoped(typeof(RoleManager<SolRole>));
            services.AddScoped(typeof(SeedRoles));
            services.AddScoped(typeof(SeedUsers));
            services.AddScoped(typeof(SeedContent));

            services.ConfigureSolf();

            // Configure Application services
            services.AddApplicationServices();

            #region Configure Services / Options
            services.AddOptions();
            services.Configure<SmtpOptions>(Configuration.GetSection("SmtpOptions"));
            services.AddTransient<IEmailService, SendGridEmailService>();

            services.Configure<SolAppOptions>(Configuration.GetSection("SolAppOptions"));
            services.Configure<SendGridOptions>(Configuration.GetSection("SendGridOptions"));
            services.Configure<NotificationOptions>(Configuration.GetSection("NotificationOptions"));
            services.Configure<FacebookAuthOptions>(Configuration.GetSection("FacebookAuthOptions"));
            services.Configure<InstagramAuthOptions>(Configuration.GetSection("InstagramAuthOptions"));
            services.Configure<GoogleAuthOptions>(Configuration.GetSection("GoogleAuthOptions"));
            services.Configure<WeepayOptions>(Configuration.GetSection("WeepayOptions"));

            services.TryAdd(ServiceDescriptor.Singleton(typeof(IOptionsMonitor<>), typeof(OptionsMonitor<>)));

            #endregion

            #region Configure Localization
            // We will put our translations in a folder called Resources
            services.AddLocalization(options => options.ResourcesPath = "Resources");

            services.AddMvc(c => c.Conventions.Add(new ApiExplorerGroupSolConvention()))
                    .AddViewLocalization(LanguageViewLocationExpanderFormat.Suffix, o => { o.ResourcesPath = "Resources"; })
                    .AddDataAnnotationsLocalization(o => { o.DataAnnotationLocalizerProvider = (type, factory) => factory.Create(typeof(_Errors)); })
                    .ConfigureApiBehaviorOptions(options =>
                    {
                        // Unified response to model validation response
                        options.InvalidModelStateResponseFactory = context =>
                        {
                            var response = ApiErr.Create(context.ModelState);
                            return new BadRequestObjectResult(response);
                        };
                    });

            // Register the Swagger services
            //services.AddSwaggerDocument();

            services.Configure<RouteOptions>(o => o.ConstraintMap.Add("culturecode", typeof(CultureRouteConstraint)));
            #endregion

            #region SignalR
            services.AddSignalR()
                    .AddJsonProtocol(o => o.PayloadSerializerOptions.Converters.Add(new DateTimeConverter()));
            services.AddSingleton<IUserIdProvider, CustomUserIdProvider>(); // Use UserId instead of Username for SignalR
            #endregion

            services.AddExternalAuthentication(Configuration);
            services.AddOpenApiDocuments("v1");
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env, IOptions<SolAppOptions> solAppOptions)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            app.UseMiddleware<ExceptionMiddleware>();

            using (var serviceScope = app.ApplicationServices.GetRequiredService<IServiceScopeFactory>().CreateScope())
            {
                try { serviceScope.ServiceProvider.GetService<AppDbContext>()?.Database.Migrate(); } catch { }
                try { serviceScope.ServiceProvider.GetService<CatalogDbContext>()?.Database.Migrate(); } catch { }
                try { serviceScope.ServiceProvider.GetService<OrdersDbContext>()?.Database.Migrate(); } catch { }
                try { serviceScope.ServiceProvider.GetService<AccountingDbContext>()?.Database.Migrate(); } catch { }
                try { serviceScope.ServiceProvider.GetService<ShippingDbContext>()?.Database.Migrate(); } catch { }
                try { serviceScope.ServiceProvider.EnsureSeedData().Wait(); } catch { }
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseRouting();

            //Best place to call UserCors
            app.UseCors();
            app.UseRequestLocalization(o =>
            {
                o.DefaultRequestCulture = solAppOptions.Value.DefaultRequestCulture;
                o.SupportedCultures = solAppOptions.Value.SupportedCultures;
                o.SupportedUICultures = solAppOptions.Value.SupportedCultures;
                o.RequestCultureProviders.Insert(0, new SolCultureProvider());
            });

            // Register the Swagger generator and the Swagger UI middlewares
            app.UseSwaggerWithConfiguration("v1");

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(name: "areadefault", pattern: "{culture:culturecode=ar}/{area:exists}/{controller=Home}/{action=Index}/{id?}");
                endpoints.MapControllerRoute(name: "default", pattern: "{culture:culturecode=ar}/{controller=Home}/{action=Index}/{id?}");
                //endpoints.MapHealthChecks("/health");
                //endpoints.MapHub<NotificationHub>("/chat");
                endpoints.MapHub<App.Shared.Services.Hubs.TrackingHub>("/hubs/tracking");
            });
        }
    }


    public class ApiExplorerGroupPerVersionConvention : IControllerModelConvention
    {
        public void Apply(ControllerModel controller)
        {
            var controllerNamespace = controller.ControllerType.Namespace; // e.g. "Controllers.V1"
            var apiVersion = controllerNamespace.Split('.').Last().ToLower();

            controller.ApiExplorer.GroupName = apiVersion;
        }
    }

    public class ApiExplorerGroupSolConvention : IControllerModelConvention
    {
        public void Apply(ControllerModel controller)
        {
            var apiNamespaceParts = controller.ControllerType.Namespace.TrimStart("App.ApiControllers.".ToCharArray()).Split('.');

            var apiVersion = apiNamespaceParts?.FirstOrDefault()?.ToLower();
            var apiBFF = apiNamespaceParts?.Skip(1)?.FirstOrDefault()?.ToLower()??"services";

            controller.ApiExplorer.GroupName = string.Join("-", apiVersion, apiBFF);
        }
    }
}
