using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;
using URF.Core.EF.Trackable;

namespace Modules.Catalog.Entities.EAV
{
    public class DynamicField : Entity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        // AKA: Related Entity ID
        public int ProductCategoryId { get; set; }
        // AKA: Related Entity
        [JsonIgnore]
        public ProductCategory ProductCategory { get; set; }
        public string DisplayName { get; set; }
        public DType ControlType { get; set; }
        public bool IsRequired { get; set; }
        public int DisplayOrder { get; set; }
        // DDL Values comma delimited "A+,A-,B+,B-,O+,O-,AB+,AB-"
        public string PotentialValues { get; set; }
    }

    public class DynamicFieldDto
    {
        public int Id { get; set; }
        public int ProductCategoryId { get; set; }
        public string DisplayName { get; set; }
        public DType ControlType { get; set; }
        public bool IsRequired { get; set; }
        public int DisplayOrder { get; set; }
        public string PotentialValues { get; set; }
    }

    public class DynamicFieldLite
    {
        public int Id { get; set; }
        public string DisplayName { get; set; }
        public DType ControlType { get; set; }
        public bool IsRequired { get; set; }
        public int DisplayOrder { get; set; }
        public string PotentialValues { get; set; }
    }

    public enum DType : byte
    {
        [Display(Name = "حقل نصي")]
        TextBox = 0,

        [Display(Name = "حقل نعم/لا")]
        CheckBox = 10,

        [Display(Name = "قائمة")]
        ListOption = 20,

        [Display(Name = "لون")]
        Color = 21,

        [Display(Name = "ملف")]
        File = 30,

        [Display(Name = "تاريخ")]
        DateTime = 40,

        [Display(Name = "رقم")]
        Number = 50,
    }
}
