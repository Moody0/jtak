using System.Reflection;
using System.Security.Claims;
using App.ApiControllers.V1.Admin;
using App.Helpers.Authorization;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Solf.Identity;
using Xunit;

namespace Modules.Accounting.Tests;

public class DashboardStaffAccessTests
{
    private sealed class Fixture : IAsyncDisposable
    {
        public SqliteConnection Connection = new("Data Source=:memory:");
        public ServiceProvider Services;
        public AppDbContext Db => Services.GetRequiredService<AppDbContext>();
        public UserManager<AppUser> Users => Services.GetRequiredService<UserManager<AppUser>>();
        public RoleManager<SolRole> Roles => Services.GetRequiredService<RoleManager<SolRole>>();
        public Mock<IAdminAuditService> Audit = new();
        public async Task Initialize()
        {
            await Connection.OpenAsync();
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddSingleton<Microsoft.AspNetCore.DataProtection.IDataProtectionProvider>(
                new Microsoft.AspNetCore.DataProtection.EphemeralDataProtectionProvider());
            services.AddDbContext<AppDbContext>(o => o.UseSqlite(Connection));
            services.AddIdentityCore<AppUser>(o => {
                o.ClaimsIdentity.UserIdClaimType = "sub";
                o.Password.RequireDigit = o.Password.RequireLowercase =
                    o.Password.RequireUppercase = o.Password.RequireNonAlphanumeric = false;
            }).AddRoles<SolRole>()
                .AddUserStore<UserStore<AppUser, SolRole, AppDbContext, Guid, SolUserClaim, SolUserRole, AppUserLogin, SolUserToken, SolRoleClaim>>()
                .AddRoleStore<RoleStore<SolRole, AppDbContext, Guid, SolUserRole, SolRoleClaim>>()
                .AddDefaultTokenProviders();
            services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();
            Services = services.BuildServiceProvider();
            await Db.Database.EnsureCreatedAsync();
            Audit.Setup(a => a.LogAsync(It.IsAny<AdminAuditLogEntry>())).Returns(Task.CompletedTask);
        }
        public ClaimsPrincipal Principal(AppUser user, string stamp = null) => new(new ClaimsIdentity(new[] {
            new Claim("sub", user.Id.ToString()),
            new Claim(DashboardAccessService.AccountMarker, "1"),
            new Claim(DashboardAccessService.SessionClaim, DashboardAccessService.SessionFingerprint(stamp ?? user.SecurityStamp))
        }, "TestPasswordLogin"));
        public StaffController Controller() => new(Db, Roles, Users, new DashboardAccessService(Db), Audit.Object) {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };
        public async Task<SolRole> Role(string permission)
        {
            var response = await Controller().CreateRole(new DashboardRoleRequest {
                Name = Guid.NewGuid().ToString(), Permissions = new[] { permission }
            });
            Assert.IsType<OkObjectResult>(response);
            return await Db.Roles.OrderByDescending(r => r.Id).FirstAsync();
        }
        public async Task<AppUser> Account(SolRole role)
        {
            var email = Guid.NewGuid().ToString("N") + "@example.test";
            Assert.IsType<OkObjectResult>(await Controller().CreateAccount(new DashboardAccountRequest {
                FullName = "Test Staff", Email = email, Password = "staff-test-password", RoleId = role.Id
            }));
            return await Users.FindByEmailAsync(email);
        }
        public async Task<bool> Allowed(AppUser user, string controller, string action, string verb, Dictionary<string, object> args = null)
        {
            var type = typeof(StaffController).Assembly.GetTypes().Single(t =>
                t.Name == controller + "Controller" && t.Namespace?.StartsWith("App.ApiControllers.V1.Admin") == true);
            var descriptor = new ControllerActionDescriptor {
                ControllerName = controller, ActionName = action, ControllerTypeInfo = type.GetTypeInfo(),
                MethodInfo = type.GetMethods().First(m => m.Name == action)
            };
            var http = new DefaultHttpContext { User = Principal(user) };
            http.Request.Method = verb;
            var context = new ActionExecutingContext(new ActionContext(http, new RouteData(), descriptor, new ModelStateDictionary()),
                new List<IFilterMetadata>(), args ?? new(), new object());
            var reached = false;
            await new DashboardPermissionFilter(new DashboardAccessService(Db), Db).OnActionExecutionAsync(context, () => {
                reached = true;
                return Task.FromResult(new ActionExecutedContext(context, new List<IFilterMetadata>(), new object()));
            });
            return reached;
        }
        public async ValueTask DisposeAsync() { if (Services != null) await Services.DisposeAsync(); await Connection.DisposeAsync(); }
    }

    [Theory]
    [InlineData("orders.manage", "Orders", "DataTable", "POST", true)]
    [InlineData("orders.manage", "Orders", "Ready", "POST", true)]
    [InlineData("orders.manage", "Payments", "Create", "POST", false)]
    [InlineData("orders.manage", "Users", "GetDeliveries", "GET", true)]
    [InlineData("orders.manage", "Staff", "List", "GET", false)]
    [InlineData("finance.manage", "Payments", "Create", "POST", true)]
    [InlineData("finance.manage", "Orders", "Ready", "POST", false)]
    [InlineData("finance.manage", "Staff", "UpdateRole", "PUT", false)]
    [InlineData("finance.view", "Payments", "DataTable", "POST", true)]
    [InlineData("finance.view", "Payments", "Create", "POST", false)]
    [InlineData("support.view", "SupportMessages", "DataTable", "POST", true)]
    [InlineData("support.view", "SupportMessages", "Delete", "DELETE", false)]
    [InlineData("catalog.manage", "Staff", "CreateAccount", "POST", false)]
    public async Task SectionAccessIsEnforcedOnServer(string permission, string controller, string action, string verb, bool expected)
    {
        await using var f = new Fixture(); await f.Initialize();
        var user = await f.Account(await f.Role(permission));
        Assert.True(await f.Users.CheckPasswordAsync(user, "staff-test-password"));
        Assert.False(await f.Users.CheckPasswordAsync(user, "123456"));
        Assert.Equal(expected, await f.Allowed(user, controller, action, verb));
    }

    [Fact]
    public async Task RoleChangesTakeEffectOnNextRequestAndUsedRolesCannotBeDeleted()
    {
        await using var f = new Fixture(); await f.Initialize();
        var role = await f.Role("orders.manage"); var user = await f.Account(role);
        Assert.True(await f.Allowed(user, "Orders", "Ready", "POST"));
        Assert.IsType<BadRequestObjectResult>(await f.Controller().DeleteRole(role.Id));
        Assert.IsType<OkObjectResult>(await f.Controller().UpdateRole(role.Id, new DashboardRoleRequest {
            Name = "Accountant", Permissions = new[] { "finance.manage" }
        }));
        Assert.False(await f.Allowed(user, "Orders", "Ready", "POST"));
        Assert.True(await f.Allowed(user, "Payments", "Create", "POST"));
        var access = await new DashboardAccessService(f.Db).CurrentAsync(f.Principal(user));
        Assert.Contains("finance.view", access.Permissions);
        Assert.DoesNotContain("orders.view", access.Permissions);
    }

    [Fact]
    public async Task DisableAndPasswordResetRevokeOldSessionsEvenAfterReactivation()
    {
        await using var f = new Fixture(); await f.Initialize();
        var role = await f.Role("finance.manage"); var user = await f.Account(role);
        var original = user.SecurityStamp;
        var request = new DashboardAccountRequest {
            FullName = user.FullName, Email = user.Email, RoleId = role.Id, IsActive = false
        };
        Assert.IsType<OkObjectResult>(await f.Controller().UpdateAccount(user.Id, request));
        Assert.False((await new DashboardAccessService(f.Db).CurrentAsync(f.Principal(user, original))).CanAccess);
        request.IsActive = true;
        Assert.IsType<OkObjectResult>(await f.Controller().UpdateAccount(user.Id, request));
        Assert.False((await new DashboardAccessService(f.Db).CurrentAsync(f.Principal(user, original))).CanAccess);
        var beforeReset = user.SecurityStamp;
        request.Password = "staff-reset-password";
        Assert.IsType<OkObjectResult>(await f.Controller().UpdateAccount(user.Id, request));
        Assert.False((await new DashboardAccessService(f.Db).CurrentAsync(f.Principal(user, beforeReset))).CanAccess);
        Assert.True(await f.Users.CheckPasswordAsync(user, "staff-reset-password"));
        Assert.False(await f.Users.CheckPasswordAsync(user, "staff-test-password"));
    }

    [Fact]
    public async Task DashboardAccountsCannotBeChangedThroughMobileUserMaintenance()
    {
        await using var f = new Fixture(); await f.Initialize();
        var role = await f.Role("users.manage"); var staff = await f.Account(role);
        Assert.False(await f.Allowed(staff, "Users", "Disable", "POST", new() { ["id"] = staff.Id }));
        Assert.IsType<BadRequestObjectResult>(await f.Controller().CreateAccount(new DashboardAccountRequest {
            FullName = "Duplicate", Email = staff.Email, Password = "staff-test-password", RoleId = role.Id
        }));
    }
}
