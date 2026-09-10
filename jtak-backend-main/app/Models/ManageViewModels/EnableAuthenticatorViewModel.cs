using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Models.ManageViewModels
{
    public class EnableAuthenticatorViewModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(7, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Text)]
        [Display(Name = "Verification Code")]
        public string Code { get; set; }

        [ReadOnly(true)]
        public string SharedKey { get; set; }

        public string AuthenticatorUri { get; set; }
    }
}
