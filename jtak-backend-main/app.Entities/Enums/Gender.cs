using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities.Enums
{
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum Gender
    {
        [Display(Name = "Male", ResourceType = typeof(_Gender))]
        Male = 0,

        [Display(Name = "Female", ResourceType = typeof(_Gender))]
        Female = 1
    }
}
