using System.ComponentModel.DataAnnotations;
using System;
using App.Resources;
using App.Shared.Entities.Resources;
using App.Shared.Entities.Enums;

namespace App.ApiModels
{
    // Models used as parameters to AccountController actions.

    public class AddExternalLoginBindingModel
    {
        [Required]
        [Display(Name = "External access token")]
        public string ExternalAccessToken { get; set; }
    }

    public class ChangePasswordBindingModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "Current password")]
        public string OldPassword { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }

        [DataType(DataType.Password)]
        //[Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        public string ConfirmPassword { get; set; }
    }
    public class ResetPasswordBindingModel
    {

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        public string Email { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        public string Code { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }
    }
    public class ConfirmEmailBindingModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "Email")]
        public string Email { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "Code")]
        public string Code { get; set; }
    }

    public class ChangeEmailBindingModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "Email")]
        public string Email { get; set; }
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "NewEmail")]
        public string NewEmail { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "Code")]
        public string Code { get; set; }
    }

    public class RegisterBindingModel
    {
        /*
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "FirstName", ResourceType = typeof(_AppUser))]
        public string FirstName { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "LastName", ResourceType = typeof(_AppUser))]
        public string LastName { get; set; }
        */
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "FullName", ResourceType = typeof(_AppUser))]
        public string FullName { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_AppUser), Name = "Email")]
        public string Email { get; set; }

        [RegularExpression(@"^\+?[1-9]\d{1,14}$", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "InvalidNumber")]
        [Display(ResourceType = typeof(_AppUser), Name = "PhoneNumber")]
        public string PhoneNumber { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "CountryPhoneCode", ResourceType = typeof(_AppUser))]
        public string CountryPhoneCode { get; set; }


        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime? Birthday { get; set; }

        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        public Gender? Gender { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "Password")]
        public string Password { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        [Compare("Password", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

        [Display(Name = "InvitationCode", ResourceType = typeof(_AppUser))]
        public string OtherUserInvitationCode { get; set; }

        public string DeviceId { get; set; }
    }

    public class PhoneNumberUserDisplayNameModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_AppUser), Name = "DisplayName")]
        public string Name { get; set; }


        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [RegularExpression(@"^\+?[1-9]\d{1,14}$", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "InvalidNumber")]
        [Display(ResourceType = typeof(_AppUser), Name = "PhoneNumber")]
        public string PhoneNumber { get; set; }
    }

    public class PhoneNumberModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [RegularExpression(@"^\+?[1-9]\d{1,14}$", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "InvalidNumber")]
        [Display(ResourceType = typeof(_AppUser), Name = "PhoneNumber")]
        public string PhoneNumber { get; set; }
    }
    public class EmailModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(ResourceType = typeof(_Account), Name = "Email")]
        public string Email { get; set; }
    }


    public class VerifyPhoneNumber
    {
        [Display(ResourceType = typeof(_Account), Name = "Code")]
        [StringLength(6, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ExactLengthRequired", MinimumLength = 6)]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        public string Code { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Phone(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "PhoneFormat")]
        [Display(ResourceType = typeof(_Account), Name = "PhoneNumber")]
        public string PhoneNumber { get; set; }
    }

    public class InvitationCodeModel
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(6, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ExactLengthRequired", MinimumLength = 6)]
        [Display(ResourceType = typeof(_Account), Name = "Code")]
        public string Code { get; set; }
    }

    public class RemoveLoginBindingModel
    {
        [Required]
        [Display(Name = "Login provider")]
        public string LoginProvider { get; set; }

        [Required]
        [Display(Name = "Provider key")]
        public string ProviderKey { get; set; }
    }

    public class SetPasswordBindingModel
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
    }
}
