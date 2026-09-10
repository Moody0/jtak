using App.Shared.Entities.Resources;
using Solf.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using URF.Core.EF.Trackable;

namespace App.Shared.Entities
{
    public class City : Entity
    {
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Display(Name = "CityName", ResourceType = typeof(_City))]
        public string Title { get; set; }

        [UIHint("EnumDropDownList")]
        [Display(Name = "Country", ResourceType = typeof(_City))]
        public CountryEnum Country { get; set; }

        //public Point DefaultLocation { get; set; }
        public int? GeoNameId { get; set; }
    }
}
