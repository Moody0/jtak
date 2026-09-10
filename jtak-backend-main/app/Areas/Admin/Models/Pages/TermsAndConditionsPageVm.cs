using App.Shared.Entities;
using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.Models.Pages
{
    public class TermsAndConditionsPageVm : SeoPage
    {
        [Display(Name = "SubTitle", ResourceType = typeof(_Content))]
        public string SubTitle { get; set; }

        [Display(Name = "HeaderImage", ResourceType = typeof(_Content))]
        [UIHint("UploadSingle")]
        public string HeaderImage { get; set; }

        [Display(Name = "MobileHeaderImage", ResourceType = typeof(_Content))]
        [UIHint("UploadSingle")]
        public string MobileHeaderImage { get; set; }

        [UIHint("HtmlField")]
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        [Display(Name = "Body", ResourceType = typeof(_Content))]
        public string Body { get; set; }
    }
}
