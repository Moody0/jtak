using App.Shared.Entities.Resources;
using System.ComponentModel.DataAnnotations;

namespace App.ApiModels
{
    public class PageVm
    {
        [Required(ErrorMessageResourceType = typeof(_Errors), ErrorMessageResourceName = "FieldIsRequired")]
        public string Title { get; set; }

        public string SubTitle { get; set; }

        public string Body { get; set; }

        public string SeoTitle { get; set; }

        public string SeoDescription { get; set; }

        public string[] SeoKeywordsArr { get; set; }
        public string SeoKeywords => SeoKeywordsArr != null ? string.Join(",", SeoKeywordsArr) : null;

    }
}
