using System;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Enums;
using Solf.Base;
using Solf.Identity;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities
{
    public class AppUser : SolUser, IAuditableEntity, ISoftDeleteEntity
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName { get; set; }
        public Gender? Gender { get; set; }
        public DateTime? Birthday { get; set; }

        public DateTime? LastLoginDate { get; set; }
        public DateTime? LastConfirmEmail { get; set; }
        public string ProfilePhoto { get; set; }
        public string DeviceId { get; set; }
        public string Lang { get; set; }
        public string CountryPhoneCode { get; set; }
        public string ExternalUserId { get; set; }
        public string ExternalTokenResponse { get; set; }
        public decimal DefaultLat { get; set; }
        public decimal DefaultLng { get; set; }


        public bool IsActive { get; set; } = true;
        public string Topics { get; set; }

        #region Auditable Entities

        [ScaffoldColumn(false)]
        public DateTime CreatedDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string CreatedBy { get; set; }

        [ScaffoldColumn(false)]
        public DateTime UpdatedDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string UpdatedBy { get; set; }

        [ScaffoldColumn(false)]
        public DateTime? DeletionDate { get; set; }

        [MaxLength(256)]
        [ScaffoldColumn(false)]
        public string DeletedBy { get; set; }
        #endregion
    }

    public class UserDto
    {
        [Display(Name = "Id", ResourceType = typeof(_AppUser))]
        public Guid Id { get; set; }

        [Display(Name = "Email", ResourceType = typeof(_AppUser))]
        public string? Email { get; set; }

        public string? Password { get; set; }

        public bool EmailConfirmed { get; set; }

        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string PhoneNumber { get; set; }


        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "FirstName", ResourceType = typeof(_AppUser))]
        public string FirstName { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "LastName", ResourceType = typeof(_AppUser))]
        public string LastName { get; set; }

        [Display(Name = "FullName", ResourceType = typeof(_AppUser))]
        public string FullName { get; set; }

        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        [UIHint("EnumRadio")]
        public Gender? Gender { get; set; }

        [Display(Name = "IsActive", ResourceType = typeof(_AppUser))]
        public bool IsActive { get; set; } = true;

        [Display(Name = "HasPassword", ResourceType = typeof(_AppUser))]
        public bool HasPassword { get; set; }

        [Display(Name = "ProfilePhoto", ResourceType = typeof(_AppUser))]
        [UIHint("UploadSingleProfile")]
        public string ProfilePhoto { get; set; }

        [Display(Name = "Topics", ResourceType = typeof(_AppUser))]
        public string Topics { get; set; }

        [Display(Name = "Role", ResourceType = typeof(_AppUser))]
        [UIHint("EnumDropDownList")]
        public AppRoleName Role { get; set; }

        [Display(Name = "CreatedDate", ResourceType = typeof(_Entities))]
        public DateTime CreatedDate { get; set; }

        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime? Birthday { get; set; } = new DateTime(1980, 1, 1);

        [Display(Name = "Lang", ResourceType = typeof(_AppUser))]
        public string Lang { get; set; }

        [Display(Name = "CountryPhoneCode", ResourceType = typeof(_AppUser))]
        public string CountryPhoneCode { get; set; }

        public decimal DefaultLat { get; set; } = 37.05637741088867m;
        public decimal DefaultLng { get; set; } = 37.33407211303711m;

        public Guid UserTopicId { get; set; }
    }

    public class CreateUserVm
    {
        [Display(Name = "Id", ResourceType = typeof(_AppUser))]
        public Guid Id { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "PhoneNumber", ResourceType = typeof(_AppUser))]
        public string PhoneNumber { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "CountryPhoneCode", ResourceType = typeof(_AppUser))]
        public string CountryPhoneCode { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "DisplayName", ResourceType = typeof(_AppUser))]
        public string DisplayName { get; set; }

        [Display(Name = "Birthday", ResourceType = typeof(_AppUser))]
        public DateTime? Birthday { get; set; }

        [Display(Name = "Gender", ResourceType = typeof(_AppUser))]
        [UIHint("EnumRadio")]
        public Gender? Gender { get; set; }

        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [StringLength(50, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "LengthRangeError", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_AppUser), Name = "Password")]
        public string Password { get; set; }

        [DataType(DataType.Password)]
        [Display(ResourceType = typeof(_AppUser), Name = "ConfirmPassword")]
        [Compare("Password", ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "ConfirmPasswordNotMatch")]
        public string ConfirmPassword { get; set; }
    }
}
