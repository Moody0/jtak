using App.Shared.Entities.Enums;

namespace App.Areas.Admin.Models
{
    public class UserPermission
    {
        public AppPermissionKey AppPermissionKey { get; set; }
        public UserPermissionValue UserPermissionValue { get; set; }
    }
}
