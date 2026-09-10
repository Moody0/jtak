using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Areas.Admin.Models
{
    public class RoleVm
    {
        [Display(Name = "Id", ResourceType = typeof(_AppRole))]
        public string Id { get; set; }
        [Display(Name = "Name", ResourceType = typeof(_AppRole))]
        public string Name { get; set; }
        [Display(Name = "RolePermissions", ResourceType = typeof(_AppRole))]

        public List<RolePermissionVm> RolePermissions;
    }
}
