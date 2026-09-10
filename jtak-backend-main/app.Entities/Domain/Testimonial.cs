using App.Shared.Entities.Resources;
using Solf.Base;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;
using System.Threading;
using URF.Core.EF.Trackable;

namespace App.Shared.Entities.Domain
{
    public class Testimonial : AuditableEntity, IMultiLingualEntity<TestimonialTranslation>
    {
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [JsonIgnore]
        public virtual ICollection<TestimonialTranslation> Translations { get; set; }
    }
    public class TestimonialTranslation : Entity, IEntityTranslation<Testimonial>
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public string Name { get; set; }
        public string Photo { get; set; }
        public string Text { get; set; }

        public Testimonial Core { get; set; }
        public int CoreId { get; set; }
        public string Language { get; set; } = Thread.CurrentThread.CurrentCulture.TwoLetterISOLanguageName;
    }
    public class TestimonialDto
    {
        public int Id { get; set; }

        public string Name { get; set; }
        public string Photo { get; set; }
        public string Text { get; set; }
    }
}
