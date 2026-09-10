using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.Models
{
    public class ContactMessageDto
    {
        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string Name { get; set; }

        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string Phone { get; set; }
        public string Email { get; set; }

        [Required(ErrorMessageResourceName = "FieldIsRequired", ErrorMessageResourceType = typeof(_Errors))]
        public string Message { get; set; }
    }
}
