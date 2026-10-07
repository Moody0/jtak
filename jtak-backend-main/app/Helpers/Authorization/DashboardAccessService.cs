using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore;

namespace App.Helpers.Authorization
{
    public sealed class DashboardAccessInfo
    {
        public bool CanAccess { get; set; }
        public bool IsSuperAdmin { get; set; }
        public string[] RoleNames { get; set; } = Array.Empty<string>();
        public string[] Permissions { get; set; } = Array.Empty<string>();
        public bool Has(string permission) => CanAccess && (IsSuperAdmin || Permissions.Contains(permission));
    }

    public sealed class DashboardAccessService : App.Shared.Services.IDashboardAccessEvaluator
    {
        public const string Policy = "DashboardAccess";
        public const string RoleMarker = "jtak:dashboard-role";
        public const string AccountMarker = "jtak:dashboard-account";
        public const string LabelClaim = "jtak:dashboard-label";
        public const string DescriptionClaim = "jtak:dashboard-description";
        public const string PermissionClaim = "jtak:dashboard-permission";
        public const string SessionClaim = "jtak:dashboard-session";
        public static readonly string[] Sections = { "dashboard", "orders", "support", "catalog", "storefront", "finance", "users", "communications", "settings", "audit" };
        public static readonly string[] AllPermissions = Sections.SelectMany(s => new[] { s + ".view", s + ".manage" }).ToArray();
        private readonly AppDbContext _db;
        private Task<DashboardAccessInfo> _current;
        public DashboardAccessService(AppDbContext db) { _db = db; }

        public Task<DashboardAccessInfo> CurrentAsync(ClaimsPrincipal principal) => _current ??= LoadAsync(principal);
        public async Task<bool> HasAsync(ClaimsPrincipal principal, string permission) => (await CurrentAsync(principal)).Has(permission);
        public static string SessionFingerprint(string stamp) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(stamp ?? "")));

        private async Task<DashboardAccessInfo> LoadAsync(ClaimsPrincipal principal)
        {
            var result = new DashboardAccessInfo();
            if (principal?.Identity?.IsAuthenticated != true || !Guid.TryParse(principal.FindFirst("sub")?.Value ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id)) return result;
            var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id && u.IsActive && u.DeletionDate == null);
            if (user == null) return result;
            var roles = await (from ur in _db.UserRoles join r in _db.Roles on ur.RoleId equals r.Id where ur.UserId == id select r).AsNoTracking().ToListAsync();
            if (roles.Any(r => r.Name == "Admin"))
            {
                result.CanAccess = result.IsSuperAdmin = true;
                result.RoleNames = new[] { "مسؤول النظام" };
                result.Permissions = AllPermissions;
                return result;
            }
            // Dashboard staff sessions use password authentication and are invalidated by password reset/disable.
            if (principal.FindFirst(SessionClaim)?.Value != SessionFingerprint(user.SecurityStamp)) return result;
            var ids = roles.Select(r => r.Id).ToArray();
            var claims = await _db.RoleClaims.AsNoTracking().Where(c => ids.Contains(c.RoleId)).ToListAsync();
            var managedIds = claims.Where(c => c.ClaimType == RoleMarker && c.ClaimValue == "1").Select(c => c.RoleId).ToHashSet();
            result.CanAccess = managedIds.Count > 0;
            result.RoleNames = claims.Where(c => managedIds.Contains(c.RoleId) && c.ClaimType == LabelClaim).Select(c => c.ClaimValue).ToArray();
            result.Permissions = Normalize(claims.Where(c => managedIds.Contains(c.RoleId) && c.ClaimType == PermissionClaim).Select(c => c.ClaimValue));
            return result;
        }

        public static string[] Normalize(IEnumerable<string> permissions)
        {
            var values = (permissions ?? Array.Empty<string>()).Where(AllPermissions.Contains).ToHashSet();
            foreach (var p in values.Where(p => p.EndsWith(".manage")).ToArray()) values.Add(p.Replace(".manage", ".view"));
            return values.OrderBy(p => p).ToArray();
        }
    }
}
