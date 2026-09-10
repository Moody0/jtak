using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities.Enums
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum RequestStatus
    {
        [Display(Name = "Pending", ResourceType = typeof(_RequestStatus))]
        Pending = 0,

        [Display(Name = "Rejected", ResourceType = typeof(_RequestStatus))]
        Rejected = 1,

        [Display(Name = "Approved", ResourceType = typeof(_RequestStatus))]
        Approved = 2
    }
}
