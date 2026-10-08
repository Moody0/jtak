using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
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
            // Fail before starting API endpoints/background workers if the
            // deployment is missing database configuration. Otherwise the
            // application starts and emits recurring HTTP 500/worker errors.
            DatabaseConnectionConfiguration.ValidateRequired(Configuration);

            services.AddCommonCors();
            services.AddRazorPages()
                    .AddRazorRuntimeCompilation();

            services.AddScoped<App.Helpers.Authorization.DashboardAccessService>();
            services.AddScoped<IDashboardAccessEvaluator>(provider => provider.GetRequiredService<App.Helpers.Authorization.DashboardAccessService>());
            services.AddScoped<App.Helpers.Authorization.DashboardPermissionFilter>();
            services.AddHttpClient<App.Helpers.Authorization.WevlixOtpClient>();
            services.AddScoped<App.Helpers.Authorization.CustomerOtpService>();
            services.AddScoped<App.Helpers.Authorization.CustomerOtpSendLimiter>();
            services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = 429;
                options.AddPolicy("customer-otp-send", context =>
                    System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
                        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                        _ => new System.Threading.RateLimiting.FixedWindowRateLimiterOptions
                        {
                            PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0
                        }));
                options.OnRejected = async (context, cancellationToken) =>
                {
                    context.HttpContext.Response.StatusCode = 429;
                    await context.HttpContext.Response.WriteAsJsonAsync(new
                    {
                        error = "OTP_RATE_LIMITED",
                        errorDescription = "تم إرسال طلبات كثيرة لرمز التحقق. يرجى الانتظار دقيقة والمحاولة مجدداً."
                    }, cancellationToken);
                };
            });
            services.AddControllersWithViews(options =>
            {
                options.Filters.AddService<App.Helpers.Authorization.DashboardPermissionFilter>(-3000);
                options.Filters.Add(new App.Helpers.Authorization.CustomerOtpExceptionFilter());
            })
                    .AddJsonOptions(o =>
                    {
                        o.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
                        o.JsonSerializerOptions.Converters.Add(new DateTimeConverter());
                    });

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
                options.AddPolicy(App.Helpers.Authorization.DashboardAccessService.Policy, policy => policy.RequireAuthenticatedUser());
                foreach (var permission in Enum.GetValues<AppPermissionKey>())
                {
                    if (permission == AppPermissionKey.CustomerPermission)
                    {
                        options.AddPolicy(permission.ToString(), policy => policy.RequireAuthenticatedUser());
                    }
                    else
                    {
                        options.AddPolicy(permission.ToString(), policy => policy.Requirements.Add(new PermissionRequirement((int)permission)));
                    }
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
            // Plesk's local reverse proxy must not collapse all OTP senders into
            // one IP bucket. Keep the framework's trusted-proxy defaults.
            app.UseForwardedHeaders(new Microsoft.AspNetCore.Builder.ForwardedHeadersOptions
            {
                ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor |
                    Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto
            });
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
            app.UseMiddleware<CorrelationIdMiddleware>();
            app.UseMiddleware<ExceptionMiddleware>();

            using (var serviceScope = app.ApplicationServices.GetRequiredService<IServiceScopeFactory>().CreateScope())
            {
                var logger = serviceScope.ServiceProvider.GetService<ILogger<Startup>>();
                try
                {
                    var appDbContext = serviceScope.ServiceProvider.GetRequiredService<AppDbContext>();
                    ReconcileExistingCashFloatColumn(appDbContext);
                    ReconcileCaptainCompensationColumns(appDbContext);
                    var ordersDbContext = serviceScope.ServiceProvider.GetRequiredService<OrdersDbContext>();
                    ReconcileOrderCaptainSnapshotColumns(ordersDbContext);
                    appDbContext.Database.Migrate();
                    serviceScope.ServiceProvider.GetRequiredService<CatalogDbContext>().Database.Migrate();
                    serviceScope.ServiceProvider.GetRequiredService<OrdersDbContext>().Database.Migrate();
                    serviceScope.ServiceProvider.GetRequiredService<AccountingDbContext>().Database.Migrate();
                    serviceScope.ServiceProvider.GetRequiredService<ShippingDbContext>().Database.Migrate();
                }
                catch (Exception ex)
                {
                    logger?.LogCritical(ex, "Database migration failed. Application startup has been stopped to prevent schema drift.");
                    throw;
                }
                try { serviceScope.ServiceProvider.EnsureSeedData().Wait(); } catch (Exception ex) { logger?.LogError(ex, "Failed to execute EnsureSeedData"); }
                try
                {
                    serviceScope.ServiceProvider.GetRequiredService<App.Helpers.Authorization.CustomerOtpService>()
                        .EnsureReviewAccountAsync(App.Helpers.Authorization.CustomerOtpService.ReviewPhone)
                        .GetAwaiter().GetResult();
                }
                catch (App.Helpers.Authorization.CustomerOtpException ex)
                {
                    logger?.LogError("Google Play review account setup failed: {Reason}", ex.Message);
                }
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseRouting();
            app.UseRateLimiter();

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
            // Re-check IsActive on every authenticated request so disabling an
            // account immediately invalidates already-issued access tokens.
            app.UseMiddleware<DisabledAccountMiddleware>();
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

        private static void ReconcileExistingCashFloatColumn(AppDbContext context)
        {
            const string migrationId = "20260919093000_AddDeliveryDriverCashFloatLimit";
            if (context.Database.GetAppliedMigrations().Contains(migrationId)) return;

            context.Database.OpenConnection();
            try
            {
                var connection = context.Database.GetDbConnection();
                using (var table = connection.CreateCommand())
                {
                    table.CommandText = "SHOW TABLES LIKE 'AspNetUsers'";
                    if (table.ExecuteScalar() == null) return;
                }

                string columnType;
                string nullable;
                using (var column = connection.CreateCommand())
                {
                    column.CommandText = "SHOW COLUMNS FROM `AspNetUsers` LIKE 'MaxCashFloat'";
                    using var reader = column.ExecuteReader();
                    if (!reader.Read()) return;
                    columnType = reader.GetString(reader.GetOrdinal("Type"));
                    nullable = reader.GetString(reader.GetOrdinal("Null"));
                }

                if (!string.Equals(columnType, "decimal(65,30)", StringComparison.OrdinalIgnoreCase) ||
                    !string.Equals(nullable, "NO", StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(
                        $"AspNetUsers.MaxCashFloat exists with type {columnType} and nullable={nullable}; expected decimal(65,30) NOT NULL.");
                }

                using (var historyTable = connection.CreateCommand())
                {
                    historyTable.CommandText = "SHOW TABLES LIKE '__EFMigrationsHistory'";
                    if (historyTable.ExecuteScalar() == null)
                    {
                        throw new InvalidOperationException("AspNetUsers.MaxCashFloat exists but __EFMigrationsHistory is missing.");
                    }
                }

                using var insert = connection.CreateCommand();
                insert.CommandText = @"
INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
SELECT '20260919093000_AddDeliveryDriverCashFloatLimit', '8.0.31'
WHERE NOT EXISTS (
    SELECT 1 FROM `__EFMigrationsHistory`
    WHERE `MigrationId` = '20260919093000_AddDeliveryDriverCashFloatLimit'
);";
                insert.ExecuteNonQuery();
            }
            finally
            {
                context.Database.CloseConnection();
            }
        }

        private static void ReconcileOrderCaptainSnapshotColumns(OrdersDbContext context)
        {
            try
            {
                context.Database.OpenConnection();
                var connection = context.Database.GetDbConnection();
                using (var table = connection.CreateCommand())
                {
                    table.CommandText = "SHOW TABLES LIKE 'Orders_Orders'";
                    if (table.ExecuteScalar() == null) return;
                }

                var columns = new[]
                {
                    ("DistanceInKm", "decimal(10,2) NULL DEFAULT NULL"),
                    ("CustomerRatePerKm", "decimal(18,2) NULL DEFAULT NULL"),
                    ("OriginalDeliveryFee", "decimal(18,2) NULL DEFAULT NULL"),
                    ("CaptainCompensationType", "int NULL DEFAULT NULL"),
                    ("CaptainRate", "decimal(65,30) NULL DEFAULT NULL")
                };

                foreach (var (colName, colDef) in columns)
                {
                    using var checkCol = connection.CreateCommand();
                    checkCol.CommandText = $"SHOW COLUMNS FROM `Orders_Orders` LIKE '{colName}'";
                    if (checkCol.ExecuteScalar() == null)
                    {
                        using var addCol = connection.CreateCommand();
                        addCol.CommandText = $"ALTER TABLE `Orders_Orders` ADD COLUMN `{colName}` {colDef};";
                        addCol.ExecuteNonQuery();
                    }
                }
            }
            catch
            {
                // In SQLite/InMemory testing contexts, ignore raw MySQL commands.
            }
            finally
            {
                try { context.Database.CloseConnection(); } catch { }
            }
        }

        private static void ReconcileCaptainCompensationColumns(AppDbContext context)
        {
            try
            {
                context.Database.OpenConnection();
                var connection = context.Database.GetDbConnection();
                using (var table = connection.CreateCommand())
                {
                    table.CommandText = "SHOW TABLES LIKE 'AspNetUsers'";
                    if (table.ExecuteScalar() == null) return;
                }

                using (var checkCol = connection.CreateCommand())
                {
                    checkCol.CommandText = "SHOW COLUMNS FROM `AspNetUsers` LIKE 'CaptainCompensationType'";
                    if (checkCol.ExecuteScalar() == null)
                    {
                        using var addCol = connection.CreateCommand();
                        addCol.CommandText = "ALTER TABLE `AspNetUsers` ADD COLUMN `CaptainCompensationType` int NOT NULL DEFAULT 0;";
                        addCol.ExecuteNonQuery();
                    }
                }

                using (var checkCol = connection.CreateCommand())
                {
                    checkCol.CommandText = "SHOW COLUMNS FROM `AspNetUsers` LIKE 'CaptainRate'";
                    if (checkCol.ExecuteScalar() == null)
                    {
                        using var addCol = connection.CreateCommand();
                        addCol.CommandText = "ALTER TABLE `AspNetUsers` ADD COLUMN `CaptainRate` decimal(65,30) NOT NULL DEFAULT 0;";
                        addCol.ExecuteNonQuery();
                    }
                }
            }
            catch
            {
                // In SQLite/InMemory testing contexts, ignore raw MySQL commands.
            }
            finally
            {
                try { context.Database.CloseConnection(); } catch { }
            }
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
