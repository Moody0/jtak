using App.Shared.Entities.Enums;

namespace App.Areas.Admin.Models
{
    public class RolePermissionVm
    {
        public AppPermissionKey AppPermissionKey { get; set; }
        public bool IsAllowed { get; set; }
    }
}
