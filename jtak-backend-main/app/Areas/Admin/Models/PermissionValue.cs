using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Areas.Admin.Models
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum UserPermissionValue
    {
        NoChange = 0,
        Allow = 1,
        Deny = 2
    }
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum RolePermissionValue
    {
        [Display(Name = "Allow", ResourceType = typeof(_AppRole))]
        Allow = 1,
        [Display(Name = "Deny", ResourceType = typeof(_AppRole))]
        Deny = 2
    }
}
