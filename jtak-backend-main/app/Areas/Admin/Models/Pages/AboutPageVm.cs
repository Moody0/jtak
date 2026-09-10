using App.Shared.Entities.Resources;
using App.Shared.Entities;
using System.ComponentModel.DataAnnotations;

namespace App.Areas.Content.Models.Pages
{
    public class AboutPageVm : SeoPage
    {
        [Display(Name = "SubTitle", ResourceType = typeof(_Content))]
        public string SubTitle { get; set; }

        [Display(Name = "HeaderImage", ResourceType = typeof(_Content))]
        [UIHint("UploadSingle")]
        public string HeaderImage { get; set; }

        [Display(Name = "MobileHeaderImage", ResourceType = typeof(_Content))]
        [UIHint("UploadSingle")]
        public string MobileHeaderImage { get; set; }
    }
}
