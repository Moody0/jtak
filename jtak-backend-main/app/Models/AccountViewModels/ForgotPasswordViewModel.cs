using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using App.Resources;

namespace App.Models.AccountViewModels
{
    public class ForgotPasswordViewModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [EmailAddress]
        [Display(ResourceType = typeof(_Account), Name = "Email")]
        public string Email { get; set; }
    }
}
