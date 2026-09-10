using System;
using System.ComponentModel.DataAnnotations;
using App.Resources;
using App.Shared.Entities.Enums;
using App.Shared.Entities.Resources;

namespace App.Models.AccountViewModels
{
    public class RegisterVm
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "Email", ResourceType = typeof(_AppUser))]
        public string Email { get; set; }

        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string PhoneNumber { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "FirstName", ResourceType = typeof(_AppUser))]
        public string FirstName { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "LastName", ResourceType = typeof(_AppUser))]
        public string LastName { get; set; }

        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        [UIHint("EnumRadio")]
        public Gender? Gender { get; set; }

        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime Birthday { get; set; } = new DateTime(1980, 1, 1);


        [Display(Name = "ProfilePhoto", ResourceType = typeof(_AppUser))]
        [UIHint("UploadSingle")]
        public string ProfilePhoto { get; set; }


        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(Name = "Password", ResourceType = typeof(_AppUser))]
        public string Password { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Compare("Password", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

    }


    public class RegisterVm2
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "Email", ResourceType = typeof(_AppUser))]
        public string Email { get; set; }

        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string PhoneNumber { get; set; }

        [Display(Name = "WhatsApp", ResourceType = typeof(_AppUser))]
        public string WhatsApp { get; set; }

        [Display(Name = "Skype", ResourceType = typeof(_AppUser))]
        public string Skype { get; set; }

        [UIHint("Multiline")]
        [Display(Name = "Address", ResourceType = typeof(_AppUser))]
        public string Address { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "FirstName", ResourceType = typeof(_AppUser))]
        public string FirstName { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "LastName", ResourceType = typeof(_AppUser))]
        public string LastName { get; set; }

        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        [UIHint("EnumRadio")]
        public Gender? Gender { get; set; }

        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime Birthday { get; set; } = new DateTime(1980, 1, 1);


        [Display(Name = "ProfilePhoto", ResourceType = typeof(_AppUser))]
        [UIHint("UploadSingle")]
        public string ProfilePhoto { get; set; }


        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(Name = "Password", ResourceType = typeof(_AppUser))]
        public string Password { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_Account), Name = "ConfirmPassword")]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Compare("Password", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }

    }
}
