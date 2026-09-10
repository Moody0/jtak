using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Solf.Extensions;
using System;
using App.Shared.Entities.Enums;
using App.Shared.Entities;

namespace App.Extensions
{
    public static class SelectListServiceExtensions
    {
        public static List<SelectListItem> GetMemberRolesSelectList(AppRoleName? selectedRole) =>
            new List<AppRoleName> { AppRoleName.Customer }
                .Select(x => new SelectListItem() { Text = x.ToLocalizedName(), Value = ((int)x).ToString(), Selected = x == selectedRole })
                .ToList();

        /*
        public static List<SelectListItem> GetSelectList(this IUserService service, IEnumerable<Guid> selectedId = null, params string[] roleNames)
        {
            var l = roleNames.Any() ? service.ListFromRoles(roleNames) : service.Queryable().ToList();
            return l.Select(x => new { Name = x.FullName, x.Id })
                .ToList()
                .Select(x => new SelectListItem() { Text = x.Name, Value = x.Id.ToString(), Selected = selectedId != null && selectedId.Any(i => i == x.Id) })
                .ToList();
        }
        */
        public static async Task<List<SelectListItem>> GetSelectList(this UserManager<AppUser> service, IEnumerable<Guid> selectedId = null, params string[] roleNames)
        {
            var users = new List<AppUser>();
            if (roleNames?.Any() == true)
            {
                foreach (var roleName in roleNames)
                {
                    users.AddRange(await service.GetUsersInRoleAsync(roleName));
                }
            }
            else
            {
                users = await service.Users.AsNoTracking().ToListAsync();
            }
            return users.Select(x => new { Name = x.FullName, x.Id })
                .ToList()
                .Select(x => new SelectListItem() { Text = x.Name, Value = x.Id.ToString(), Selected = selectedId != null && selectedId.Any(i => i == x.Id) })
                .ToList();
        }

        public static List<SelectListItem> GetSelectList(this UserManager<AppUser> service, Guid? selectedId = null) =>
            selectedId.HasValue ? service.GetSelectList(selectedId.Value) : service.GetSelectList(new Guid[] { });

        public static List<SelectListItem> GetSelectList(this UserManager<AppUser> service, params Guid[] selectedIds) =>
            service.Users
                   .ToArray()
                   .Select(x => new SelectListItem() { Text = x.FirstName + " " + x.LastName, Value = x.Id.ToString(), Selected = selectedIds?.Contains(x.Id) == true })
                   .ToList();
        public static async Task<List<SelectListItem>> GetSelectList(this UserManager<AppUser> service, AppRoleName role, Guid? selectedId = null) =>
            selectedId.HasValue ? await service.GetSelectList(role, selectedId.Value) : await service.GetSelectList(role, new Guid[] { });
        public static async Task<List<SelectListItem>> GetSelectList(this UserManager<AppUser> service, AppRoleName role, params Guid[] selectedIds) =>
            (await service.GetUsersInRoleAsync(role.ToString()))
                   .Select(x => new SelectListItem() { Text = x.FirstName + " " + x.LastName, Value = x.Id.ToString(), Selected = selectedIds?.Contains(x.Id) == true })
                   .ToList();

        public static async Task<IEnumerable<T1>> SelectManyAsync<T, T1>(this IEnumerable<T> enumeration, Func<T, Task<IList<T1>>> func)
        {
            return (await Task.WhenAll(enumeration.Select(func))).SelectMany(s => s);
        }
    }

    public class Select2ListItem
    {
        public string id { get; set; }
        public string text { get; set; }
    }

    public class Select2List
    {
        public Select2ListItem[] results { get; set; }
    }
}
