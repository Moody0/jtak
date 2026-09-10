using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using App.Resources;

namespace App.Models.AccountViewModels
{
    public class ResetPasswordVm
    {
        //public Guid UserId { get; set; }
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [EmailAddress]
        public string Email { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        public string Password { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        [Compare("Password", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

        public string Code { get; set; }
    }
}
