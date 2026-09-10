using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Models.AccountViewModels
{
    public class ExternalLoginViewModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [EmailAddress]
        public string Email { get; set; }
    }
}
