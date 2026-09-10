using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities.Enums
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum AppRoleName
    {
        [Display(Name = "Admin", ResourceType = typeof(_AppRoleName))]
        Admin = 0,
        [Display(Name = "Customer", ResourceType = typeof(_AppRoleName))]
        Customer = 1,
        [Display(Name = "Merchant", ResourceType = typeof(_AppRoleName))]
        Merchant = 2,
        [Display(Name = "Delivery", ResourceType = typeof(_AppRoleName))]
        Delivery = 3
    }
}
