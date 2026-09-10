using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Rendering;
using App.Resources;
using App.Shared.Entities.Enums;
using App.Shared.Entities.Resources;

namespace App.ApiModels
{
    public class IndexViewModel
    {
        public bool HasPassword { get; set; }
        public IList<UserLoginInfo> Logins { get; set; }
        public string PhoneNumber { get; set; }
        public bool TwoFactor { get; set; }
        public bool BrowserRemembered { get; set; }
    }

    public class FactorViewModel
    {
        public string Purpose { get; set; }
    }

    public class SetPasswordModel
    {
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }

        [DataType(DataType.Password)]
        [Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        public string ConfirmPassword { get; set; }
    }
    /*
    public class ResetPasswordModel
    {
        public string UserId { get; set; }
        
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        public string NewPassword { get; set; }

        [DataType(DataType.Password)]
        [Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        public string ConfirmPassword { get; set; }
    }*/

    public class ChangePasswordViewModel
    {

        [DataType(DataType.Password)]
        [Display(Name = "Current password")]
        public string OldPassword { get; set; }


        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "NewPassword")]
        public string NewPassword { get; set; }

        [DataType(DataType.Password)]
        [Compare("NewPassword", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        public string ConfirmPassword { get; set; }
    }


    public class UserUpdateVm
    {
        //[Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        //[RegularExpression("^\\+?\\d{10,14}$", ErrorMessageResourceName = "PhoneFormat", ErrorMessageResourceType = typeof(_Errors))]
        [Display(Name = "Phone Number")]
        public string PhoneNumber { get; set; }

        [Display(Name = "CountryPhoneCode", ResourceType = typeof(_AppUser))]
        public string CountryPhoneCode { get; set; }
        /*
        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string FirstName { get; set; }

        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string LastName { get; set; }
        */

        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string FullName { get; set; }
        public string Email { get; set; }
        public string ProfilePhoto { get; set; }


        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime? Birthday { get; set; }
        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        public Gender? Gender { get; set; }


        [Display(Name = "InvitationCode", ResourceType = typeof(_AppUser))]
        public string OtherUserInvitationCode { get; set; }

    }

    public class VerifyPhoneNumberVm
    {
        [Display(Name = "Code")]
        public string Code { get; set; }


        [Phone]
        [Display(Name = "Phone Number")]
        public string PhoneNumber { get; set; }
    }

    public class ConfigureTwoFactorViewModel
    {
        public string SelectedProvider { get; set; }
        public ICollection<SelectListItem> Providers { get; set; }
    }
}