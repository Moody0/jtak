using App.Shared.Entities.Resources;
using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace App.Shared.Entities
{
    public class SmsLog : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "User", ResourceType = typeof(_SmsLog))]
        public Guid UserId { get; set; }
        [ForeignKey("UserId")]
        [Display(Name = "User", ResourceType = typeof(_SmsLog))]
        public AppUser User { get; set; }

        [Display(Name = "Code", ResourceType = typeof(_SmsLog))]
        public string Code { get; set; }
        [Display(Name = "Text", ResourceType = typeof(_SmsLog))]
        public string Text { get; set; }
        [Display(Name = "Response", ResourceType = typeof(_SmsLog))]
        public string Response { get; set; }
    }
}
