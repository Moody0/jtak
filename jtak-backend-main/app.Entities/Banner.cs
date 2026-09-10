using App.Shared.Entities.Resources;
using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace App.Shared.Entities.Domain
{
    public class Banner : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "Title", ResourceType = typeof(_Entities))]
        public string Title { get; set; }
        [Display(Name = "Description", ResourceType = typeof(_Entities))]
        public string Description { get; set; }

        [Display(Name = "Order", ResourceType = typeof(_Banner))]
        public int Order { get; set; }

        [Display(Name = "Url", ResourceType = typeof(_Banner))]
        public string Url { get; set; }

        [Display(Name = "Active", ResourceType = typeof(_Entities))]
        public bool Active { get; set; }

        [UIHint("UploadSingle")]
        [Display(Name = "FeaturedImage", ResourceType = typeof(_Banner))]
        public string FeaturedImage { get; set; }

        [Display(Name = "BannerLocation", ResourceType = typeof(_Banner))]
        public BannerLocation BannerLocation { get; set; }
    }
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum BannerLocation
    {
        [Display(Name = "HomePage", ResourceType = typeof(_Banner))]
        HomePage = 0
    }

    public class BannerDto
    {
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "Title", ResourceType = typeof(_Entities))]
        public string Title { get; set; }
        [Display(Name = "Description", ResourceType = typeof(_Entities))]
        public string Description { get; set; }

        [Display(Name = "Order", ResourceType = typeof(_Banner))]
        public int Order { get; set; }

        [Display(Name = "Url", ResourceType = typeof(_Banner))]
        public string Url { get; set; }

        [Display(Name = "Active", ResourceType = typeof(_Entities))]
        public bool Active { get; set; } = true;

        [UIHint("UploadSingle")]
        [Display(Name = "FeaturedImage", ResourceType = typeof(_Banner))]
        public string FeaturedImage { get; set; }

        [Display(Name = "CreatedDate", ResourceType = typeof(_Entities))]
        public DateTime CreatedDate { get; set; }

        [UIHint("EnumDropDownList")]
        [Display(Name = "BannerLocation", ResourceType = typeof(_Banner))]
        public BannerLocation BannerLocation { get; set; }
    }

    public class BannerLiteDto
    {
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "Title", ResourceType = typeof(_Entities))]
        public string Title { get; set; }

        [Display(Name = "Description", ResourceType = typeof(_Entities))]
        public string Description { get; set; }

        [Display(Name = "Url", ResourceType = typeof(_Banner))]
        public string Url { get; set; }

        [Display(Name = "FeaturedImage", ResourceType = typeof(_Banner))]
        public string FeaturedImage { get; set; }
    }
}