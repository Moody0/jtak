using System;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using App.Helpers.Authorization;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OpenIddict.Validation.AspNetCore;
using Solf.Identity;

namespace App.ApiControllers.V1.Admin
{
    [ApiController]
    [ApiVersion("1")]
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = DashboardAccessService.Policy)]
    public sealed class StaffController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly RoleManager<SolRole> _roles;
        private readonly UserManager<AppUser> _users;
        private readonly DashboardAccessService _access;
        private readonly IAdminAuditService _audit;
        public StaffController(AppDbContext db, RoleManager<SolRole> roles, UserManager<AppUser> users, DashboardAccessService access, IAdminAuditService audit)
        { _db = db; _roles = roles; _users = users; _access = access; _audit = audit; }

        [HttpGet("Access")]
        public Task<DashboardAccessInfo> Access() => _access.CurrentAsync(User);

        [HttpGet]
        public async Task<IActionResult> List()
        {
            var claims = await _db.RoleClaims.AsNoTracking().ToListAsync();
            var roleIds = claims.Where(c => c.ClaimType == DashboardAccessService.RoleMarker && c.ClaimValue == "1").Select(c => c.RoleId).ToArray();
            var roles = await _db.Roles.AsNoTracking().Where(r => roleIds.Contains(r.Id)).ToListAsync();
            var adminId = await _db.Roles.Where(r => r.Name == "Admin").Select(r => r.Id).FirstOrDefaultAsync();
            var memberships = await _db.UserRoles.AsNoTracking().Where(m => roleIds.Contains(m.RoleId) || m.RoleId == adminId).ToListAsync();
            var staffIds = await _db.UserClaims.Where(c => c.ClaimType == DashboardAccessService.AccountMarker && c.ClaimValue == "1").Select(c => c.UserId).ToListAsync();
            staffIds.AddRange(memberships.Where(m => m.RoleId == adminId).Select(m => m.UserId));
            var accounts = await _db.Users.AsNoTracking().Where(u => staffIds.Contains(u.Id) && u.DeletionDate == null).OrderBy(u => u.FullName).ToListAsync();
            return Ok(new
            {
                sections = DashboardAccessService.Sections,
                roles = roles.Select(r => new
                {
                    r.Id,
                    name = claims.FirstOrDefault(c => c.RoleId == r.Id && c.ClaimType == DashboardAccessService.LabelClaim)?.ClaimValue ?? r.Name,
                    description = claims.FirstOrDefault(c => c.RoleId == r.Id && c.ClaimType == DashboardAccessService.DescriptionClaim)?.ClaimValue ?? "",
                    permissions = DashboardAccessService.Normalize(claims.Where(c => c.RoleId == r.Id && c.ClaimType == DashboardAccessService.PermissionClaim).Select(c => c.ClaimValue)),
                    accountCount = accounts.Count(u => memberships.Any(m => m.UserId == u.Id && m.RoleId == r.Id))
                }),
                accounts = accounts.Select(u => new
                {
                    u.Id, u.FullName, u.Email, u.IsActive, u.CreatedDate, u.LastLoginDate,
                    roleId = memberships.FirstOrDefault(m => m.UserId == u.Id && roleIds.Contains(m.RoleId))?.RoleId,
                    isSuperAdmin = memberships.Any(m => m.UserId == u.Id && m.RoleId == adminId)
                })
            });
        }

        [HttpPost("Roles")]
        public Task<IActionResult> CreateRole([FromBody] DashboardRoleRequest request) => SaveRole(null, request);
        [HttpPut("Roles/{id:guid}")]
        public Task<IActionResult> UpdateRole(Guid id, [FromBody] DashboardRoleRequest request) => SaveRole(id, request);

        private async Task<IActionResult> SaveRole(Guid? id, DashboardRoleRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            var name = request.Name?.Trim();
            if (string.IsNullOrWhiteSpace(name)) return Error("اسم الدور مطلوب.");
            if ((request.Permissions ?? Array.Empty<string>()).Any(p => !DashboardAccessService.AllPermissions.Contains(p))) return Error("صلاحيات الدور غير صالحة.");
            var permissions = DashboardAccessService.Normalize(request.Permissions);
            if (!permissions.Any(p => p.EndsWith(".view"))) return Error("حدد صلاحية عرض لقسم واحد على الأقل.");
            if (await _db.RoleClaims.AnyAsync(c => c.ClaimType == DashboardAccessService.LabelClaim && c.ClaimValue == name && (!id.HasValue || c.RoleId != id.Value))) return Error("يوجد دور بنفس الاسم.");
            using var transaction = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            SolRole role;
            if (id.HasValue)
            {
                role = await ManagedRole(id.Value);
                if (role == null) return NotFound();
                foreach (var claim in await _roles.GetClaimsAsync(role))
                {
                    var removed = await _roles.RemoveClaimAsync(role, claim);
                    if (!removed.Succeeded) return IdentityError(removed);
                }
            }
            else
            {
                role = new SolRole { Name = "Dashboard:" + Guid.NewGuid().ToString("N") };
                var created = await _roles.CreateAsync(role);
                if (!created.Succeeded) return IdentityError(created);
            }
            var newClaims = new[] { new Claim(DashboardAccessService.RoleMarker, "1"), new Claim(DashboardAccessService.LabelClaim, name), new Claim(DashboardAccessService.DescriptionClaim, request.Description?.Trim() ?? "") }
                .Concat(permissions.Select(p => new Claim(DashboardAccessService.PermissionClaim, p)));
            foreach (var claim in newClaims)
            {
                var added = await _roles.AddClaimAsync(role, claim);
                if (!added.Succeeded) return IdentityError(added);
            }
            await Audit(id.HasValue ? "UpdateRole" : "CreateRole", role.Id, new { name, permissions });
            await transaction.CommitAsync();
            return Ok(new { role.Id });
        }

        [HttpDelete("Roles/{id:guid}")]
        public async Task<IActionResult> DeleteRole(Guid id)
        {
            // Serialize account assignments and deletion through the role row.
            using var transaction = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var role = await ManagedRole(id);
            if (role == null) return NotFound();
            if (await _db.UserRoles.AnyAsync(ur => ur.RoleId == id)) return Error("غيّر دور الموظفين المرتبطين بهذا الدور قبل حذفه.");
            var result = await _roles.DeleteAsync(role);
            if (!result.Succeeded) return IdentityError(result);
            await Audit("DeleteRole", id, null);
            await transaction.CommitAsync();
            return Ok(true);
        }

        [HttpPost("Accounts")]
        public Task<IActionResult> CreateAccount([FromBody] DashboardAccountRequest request) => SaveAccount(null, request);
        [HttpPut("Accounts/{id:guid}")]
        public Task<IActionResult> UpdateAccount(Guid id, [FromBody] DashboardAccountRequest request) => SaveAccount(id, request);

        private async Task<IActionResult> SaveAccount(Guid? id, DashboardAccountRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            var email = request.Email?.Trim();
            var fullName = request.FullName?.Trim();
            if (string.IsNullOrWhiteSpace(fullName) || string.IsNullOrWhiteSpace(email)) return Error("الاسم والبريد الإلكتروني مطلوبان.");
            if (!id.HasValue && string.IsNullOrEmpty(request.Password)) return Error("كلمة المرور مطلوبة للحساب الجديد.");
            if (!string.IsNullOrEmpty(request.Password) && (request.Password.Length < 10 || request.Password.Length > 100)) return Error("كلمة المرور يجب أن تكون من 10 إلى 100 حرف.");
            using var transaction = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var role = await ManagedRole(request.RoleId);
            if (role == null) return Error("اختر دوراً صالحاً للموظف.");
            var normalized = _users.NormalizeEmail(email);
            if (await _db.Users.AnyAsync(u => (u.NormalizedEmail == normalized || u.NormalizedUserName == normalized) && (!id.HasValue || u.Id != id.Value))) return Error("البريد الإلكتروني مرتبط بحساب آخر.");
            AppUser user;
            if (id.HasValue)
            {
                user = await _users.FindByIdAsync(id.Value.ToString());
                if (user == null || user.DeletionDate != null) return NotFound();
                if (await _users.IsInRoleAsync(user, "Admin") || !(await _users.GetClaimsAsync(user)).Any(c => c.Type == DashboardAccessService.AccountMarker && c.Value == "1")) return Error("لا يمكن تعديل حساب مسؤول النظام أو حساب التطبيق من هنا.");
                user.FullName = fullName;
                user.Email = user.UserName = email;
                user.EmailConfirmed = true;
                var disabling = user.IsActive && !request.IsActive;
                user.IsActive = request.IsActive;
                user.UpdatedDate = DateTime.UtcNow;
                var result = await _users.UpdateAsync(user);
                if (!result.Succeeded) return IdentityError(result);
                if (disabling)
                {
                    result = await _users.UpdateSecurityStampAsync(user);
                    if (!result.Succeeded) return IdentityError(result);
                }
                if (!string.IsNullOrEmpty(request.Password))
                {
                    result = await _users.ResetPasswordAsync(user, await _users.GeneratePasswordResetTokenAsync(user), request.Password);
                    if (!result.Succeeded) return IdentityError(result);
                }
                result = await _users.RemoveFromRolesAsync(user, await _users.GetRolesAsync(user));
                if (!result.Succeeded) return IdentityError(result);
            }
            else
            {
                user = new AppUser { UserName = email, Email = email, EmailConfirmed = true, FullName = fullName, FirstName = fullName, LastName = "", IsActive = request.IsActive, CreatedDate = DateTime.UtcNow, UpdatedDate = DateTime.UtcNow };
                var result = await _users.CreateAsync(user, request.Password);
                if (!result.Succeeded) return IdentityError(result);
                result = await _users.AddClaimAsync(user, new Claim(DashboardAccessService.AccountMarker, "1"));
                if (!result.Succeeded) return IdentityError(result);
            }
            var assigned = await _users.AddToRoleAsync(user, role.Name);
            if (!assigned.Succeeded) return IdentityError(assigned);
            await Audit(id.HasValue ? "UpdateAccount" : "CreateAccount", user.Id, new { fullName, email, request.IsActive, request.RoleId, passwordChanged = !string.IsNullOrEmpty(request.Password) });
            await transaction.CommitAsync();
            return Ok(new { user.Id });
        }

        private async Task<SolRole> ManagedRole(Guid id)
        {
            if (!await _db.RoleClaims.AnyAsync(c => c.RoleId == id && c.ClaimType == DashboardAccessService.RoleMarker && c.ClaimValue == "1")) return null;
            return await _roles.FindByIdAsync(id.ToString());
        }
        private IActionResult Error(string message) => BadRequest(new { message });
        private IActionResult IdentityError(IdentityResult result) => BadRequest(new { errors = result.Errors.Select(e => e.Description).ToArray() });
        private Task Audit(string action, Guid id, object after) => _audit.LogAsync(new AdminAuditLogEntry { Module = "Staff", Action = action, EntityType = "DashboardAccess", EntityId = id.ToString(), Description = "إدارة حسابات وصلاحيات لوحة التحكم", AfterState = after });
    }

    public sealed class DashboardRoleRequest
    {
        [Required, StringLength(80)] public string Name { get; set; }
        [StringLength(300)] public string Description { get; set; }
        public string[] Permissions { get; set; } = Array.Empty<string>();
    }
    public sealed class DashboardAccountRequest
    {
        [Required, StringLength(120)] public string FullName { get; set; }
        [Required, EmailAddress, StringLength(254)] public string Email { get; set; }
        [StringLength(100)] public string Password { get; set; }
        public Guid RoleId { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
