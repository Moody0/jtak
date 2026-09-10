using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using App.Resources;

namespace App.Models.ManageViewModels
{
    public class SetPasswordVm
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        [Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

        public string StatusMessage { get; set; }
    }
}
