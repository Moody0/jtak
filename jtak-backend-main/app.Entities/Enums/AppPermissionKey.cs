using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.Shared.Entities.Enums
{
    public enum AppPermissionKey : byte
    {
        [Display(ResourceType = typeof(_PermissionKey), Name = "Admin")]
        AdminPermission = 1,

        [Display(ResourceType = typeof(_PermissionKey), Name = "Customer")]
        CustomerPermission = 2,

        [Display(ResourceType = typeof(_PermissionKey), Name = "Merchant")]
        MerchantPermission = 3,

        [Display(ResourceType = typeof(_PermissionKey), Name = "Delivery")]
        DeliveryPermission = 4,
    }
}
