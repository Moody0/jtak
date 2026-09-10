using System;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities;
using App.Shared.Entities.Resources;
using App.Shared.Entities.Domain;

namespace App.ApiModels
{
    public class SearchVm
    {
    }

    public class InitData
    {
        public UserDto User { get; set; }
        public BannerLiteDto[] HowTos { get; set; }
        public string HeaderImage { get; set; }
        public int CartItemsCount { get; set; }
    }

    public class ContactMessageDto
    {
        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string DisplayName { get; set; }

        //[Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        //[RegularExpression("^\\+?\\d{10,14}$", ErrorMessageResourceName = "PhoneFormat", ErrorMessageResourceType = typeof(_Errors))]
        //[Display(Name = "Phone Number")]
        //public string PhoneNumber { get; set; }

        [Display(Name = "Title")]
        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string Title { get; set; }

        public string Email { get; set; }
        public string Message { get; set; }
    }

    public class NotificationMessageDto
    {
        public int Id { get; set; }

        public string Title { get; set; }

        public string Text { get; set; }

        public DateTime? ViewDate { get; set; }

        public DateTime CreatedDate { get; set; }
    }

}
