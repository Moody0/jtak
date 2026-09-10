using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;
using App.Resources;

namespace App.Models.AccountViewModels
{
    public class LoginViewModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [EmailAddress]
        [Display(ResourceType = typeof(_Account), Name = "Email")]
        public string Email { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "Password")]
        public string Password { get; set; }

        [Display(ResourceType =typeof(_Account), Name ="RememberMe")]
        public bool RememberMe { get; set; }
    }
}
