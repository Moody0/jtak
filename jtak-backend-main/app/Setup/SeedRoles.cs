using System;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Solf.Identity;

namespace App.Setup
{
    public class SeedRoles
    {
        private readonly RoleManager<SolRole> _roleManager;
        public SeedRoles(RoleManager<SolRole> roleManager)
        {
            _roleManager = roleManager;
        }

        public async Task Seed()
        {
            await CreateRole(nameof(AppRoleName.Admin), Enum.GetValues<AppPermissionKey>());
            await CreateRole(nameof(AppRoleName.Merchant), AppPermissionKey.MerchantPermission);
            await CreateRole(nameof(AppRoleName.Delivery), AppPermissionKey.DeliveryPermission);
            await CreateRole(nameof(AppRoleName.Customer), AppPermissionKey.CustomerPermission);
        }

        private async Task CreateRole(string role, params AppPermissionKey[] keys)
        {
            var dbrole = await _roleManager.Roles.Include(x=>x.RolePermissions).FirstOrDefaultAsync(r=>r.NormalizedName == role.ToUpper());
            if (dbrole == null)
            {
                var result = await _roleManager.CreateAsync(new SolRole() { Name = role });
                if (!result.Succeeded) return;
                dbrole = await _roleManager.FindByNameAsync(role);
            }
            if (dbrole.RolePermissions == null || !dbrole.RolePermissions.Any())
            {
                dbrole.RolePermissions = keys.Select(x => new RolePermission(dbrole.Id, (byte)x)).ToList();
                var result = await _roleManager.UpdateAsync(dbrole);
            }
        }
    }
}
