using Solf.Base;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Globalization;
using System.Text.Json.Serialization;

namespace Modules.Catalog.Entities
{
    public class Tag : AuditableEntity
    {
        //[Display(Name = "Id", ResourceType = typeof(_Entities))]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        //[Display(Name = "NameAr", ResourceType = typeof(_Tag))]
        public string NameAr { get; set; }
        //[Display(Name = "NameEn", ResourceType = typeof(_Tag))]
        public string NameEn { get; set; }
        //[Display(Name = "NameTr", ResourceType = typeof(_Tag))]
        public string NameTr { get; set; }

        public string Name => CultureInfo.CurrentCulture.TwoLetterISOLanguageName switch
        {
            "ar" => NameAr,
            "en" => NameEn,
            "tr" => NameTr,
            _ => NameAr,
        };


        //[Display(Name = "Photo", ResourceType = typeof(_Tag))]
        public string Photo { get; set; }
        public virtual ICollection<ProductTag> Tags { get; set; }
    }

    public class TagDto
    {
        public int Id { get; set; }
        [JsonIgnore]
        public string NameAr { get; set; }
        [JsonIgnore]
        public string NameEn { get; set; }
        [JsonIgnore]
        public string NameTr { get; set; }
        public string Name => CultureInfo.CurrentCulture.TwoLetterISOLanguageName switch
        {
            "ar" => NameAr,
            "en" => NameEn,
            "tr" => NameTr,
            _ => NameAr,
        };

        public string Photo { get; set; }
    }

    public class ProductTag : AuditableEntity
    {
        public int ProductId { get; set; }
        public Product Product { get; set; }
        public int TagId { get; set; }
        public Tag Tag { get; set; }
    }
}
