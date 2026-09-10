using System;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using URF.Core.EF.Trackable;

namespace Modules.Catalog.Entities.EAV
{
    public class DynamicFieldValue : Entity
    {
        public int DynamicFieldId { get; set; }
        public virtual DynamicField DynamicField { get; set; }

        public long ProductId { set; get; }
        [JsonIgnore]
        public virtual Product Product { set; get; }

        public DType ControlType { get; set; }
        [StringLength(maximumLength: 255)]
        public string StringVal { get; set; }
        public decimal? NumberVal { get; set; }
        public DateTime? DateTimeVal { get; set; }
        public bool? BoolVal { get; set; }
    }

    public class DynamicFieldValueDto
    {
        public int DynamicFieldId { get; set; }
        public int ProductId { get; set; }
        public DType ControlType { get; set; }
        //public bool IsRequired { get; set; }
        //public int DisplayOrder { get; set; }
        //public string PotentialValues { get; set; }

        public string DynamicFieldDisplayName { get; set; }

        public string StringVal { get; set; }

        [JsonIgnore]
        public bool? BoolVal { get; set; }

        [JsonIgnore]
        public DateTime? DateTimeVal { get; set; }

        [JsonIgnore]
        public decimal? NumberVal { get; set; }
    }
    public class DynamicFieldValueLiteDto
    {
        public string DynamicFieldDisplayName { get; set; }
        public DType ControlType { get; set; }
        //public string Value => ControlType switch
        //{
        //    ControlType.CheckBox => BoolVal.ToString(),
        //    ControlType.DateTime => DateTimeVal.ToString(),
        //    ControlType.Number => NumberVal.ToString(),
        //    _ => StringVal
        //};

        public string StringVal { get; set; }

        [JsonIgnore]
        public bool? BoolVal { get; set; }

        [JsonIgnore]
        public DateTime? DateTimeVal { get; set; }

        [JsonIgnore]
        public decimal? NumberVal { get; set; }
    }
}
