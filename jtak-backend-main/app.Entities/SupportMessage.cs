using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace App.Shared.Entities.Domain
{
    public enum SupportMessageStatus
    {
        New = 0,       // جديدة
        Read = 1,      // قيد المتابعة / مقروءة
        Resolved = 2   // تمت المعالجة
    }

    public class SupportMessage : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public Guid? UserId { get; set; }

        [MaxLength(150)]
        public string SenderName { get; set; }

        [MaxLength(50)]
        public string SenderPhone { get; set; }

        [MaxLength(150)]
        public string SenderEmail { get; set; }

        [MaxLength(200)]
        public string Title { get; set; }

        public string Message { get; set; }

        public SupportMessageStatus Status { get; set; } = SupportMessageStatus.New;

        public string AdminNotes { get; set; }

        public DateTime? ResolvedDate { get; set; }
    }

    public class SupportMessageDto
    {
        public int Id { get; set; }
        public Guid? UserId { get; set; }
        public string SenderName { get; set; }
        public string SenderPhone { get; set; }
        public string SenderEmail { get; set; }
        public string Title { get; set; }
        public string Message { get; set; }
        public SupportMessageStatus Status { get; set; }
        public string AdminNotes { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? ResolvedDate { get; set; }
    }

    public class SupportMessageStatsDto
    {
        public int TotalCount { get; set; }
        public int NewCount { get; set; }
        public int InProgressCount { get; set; }
        public int ResolvedCount { get; set; }
    }

    public class UpdateSupportMessageStatusDto
    {
        public SupportMessageStatus Status { get; set; }
        public string AdminNotes { get; set; }
    }
}
