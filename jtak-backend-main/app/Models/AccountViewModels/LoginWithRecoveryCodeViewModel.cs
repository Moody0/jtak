using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Models.AccountViewModels
{
    public class LoginWithRecoveryCodeViewModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [DataType(DataType.Text)]
        [Display(Name = "Recovery Code")]
        public string RecoveryCode { get; set; }
    }
}
