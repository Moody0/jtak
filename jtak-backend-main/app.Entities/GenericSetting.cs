using Solf.Base;
using System.ComponentModel.DataAnnotations;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities
{
    public class GenericSetting : AuditableEntity
    {
        [Key]
        [Display(Name = "Key", ResourceType = typeof(_Entities))]
        public string Key { get; set; }

        [Display(Name = "Value", ResourceType = typeof(_Entities))]
        public string Value { get; set; }
    }
}
