using System.ComponentModel.DataAnnotations;
using App.Resources;
using App.Shared.Entities.Resources;

namespace App.Areas.Admin.Models
{
    public class ForceResetPasswordVm
    {
        //public string Id { get; set; }
        public string Email { get; set; }
        public string DisplayName { get; set; }

        [UIHint("Password")]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(100, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }

        [UIHint("Password")]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account),Name = "ConfirmPassword")]
        [Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

        public string StatusMessage { get; set; }
    }
}
