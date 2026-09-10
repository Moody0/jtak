using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;
using App.Shared.Entities.Resources;

namespace App.Shared.Entities
{
    public class NotificationMessage : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Display(Name = "Id", ResourceType = typeof(_Entities))]
        public int Id { get; set; }

        [Display(Name = "RecivedDate", ResourceType = typeof(_Notification))]
        public DateTime? RecivedDate { get; set; }

        [Display(Name = "ReadDate", ResourceType = typeof(_Notification))]
        public DateTime? ReadDate { get; set; }
        
        [Display(Name = "User", ResourceType = typeof(_Notification))]
        public Guid UserId { get; set; }

        [ForeignKey("UserId")]
        [Display(Name = "User", ResourceType = typeof(_Notification))]
        public virtual AppUser User { get; set; }
        
        [Display(Name = "Notification", ResourceType = typeof(_Notification))]
        public int NotificationId { get; set; }

        [JsonIgnore]
        [Display(Name = "Notification", ResourceType = typeof(_Notification))]
        public virtual Notification Notification { get; set; }
    }
}
