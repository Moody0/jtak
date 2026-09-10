using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace App.Shared.Entities
{
    public interface ISeoPage
    {
        string SeoTitle { get; set; }
        string SeoDescription { get; set; }
        string SeoKeywords { get; set; }
        string SeoFeaturedImage { get; set; }
    }
    public class SeoPage : ISeoPage
    {
        public void SetSeo(string seoTitle = null, string seoDescription = null, string seoKeywords = null, string seoFeaturedImage = null)
        {
            SeoTitle = seoTitle;
            SeoDescription = seoDescription;
            SeoKeywords = seoKeywords;
            SeoFeaturedImage = seoFeaturedImage;
        }

        [Display(Name = "SeoTitle", ResourceType = typeof(_Entities))]
        public string SeoTitle { get; set; }

        [StringLength(160, ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "MaximumLengthIs")]
        [Display(Name = "SeoDescription", ResourceType = typeof(_Entities))]
        public string SeoDescription { get; set; }

        [Display(Name = "SeoKeywords", ResourceType = typeof(_Entities))]
        public string SeoKeywords { get; set; }

        [NotMapped]
        [UIHint("DropDownList")]
        [Display(Name = "SeoKeywords", ResourceType = typeof(_Entities))]
        public string[] SeoKeywordsArr { get; set; }

        [UIHint("UploadSingle")]
        [Display(Name = "SeoFeaturedImage", ResourceType = typeof(_Entities))]
        public string SeoFeaturedImage { get; set; }
    }
}
