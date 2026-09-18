using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace App.Shared.Entities
{
    public class AdminAuditLog
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;

        public Guid? AdminUserId { get; set; }

        [MaxLength(200)]
        public string AdminName { get; set; }

        [MaxLength(200)]
        public string AdminEmail { get; set; }

        [MaxLength(100)]
        public string Module { get; set; }

        [MaxLength(100)]
        public string Action { get; set; }

        [MaxLength(100)]
        public string EntityType { get; set; }

        [MaxLength(200)]
        public string EntityId { get; set; }

        [MaxLength(2000)]
        public string Description { get; set; }

        [MaxLength(50)]
        public string Result { get; set; } = "Success"; // Success, Failed

        public string FailureReason { get; set; }

        [MaxLength(100)]
        public string IpAddress { get; set; }

        [MaxLength(500)]
        public string UserAgent { get; set; }

        [MaxLength(100)]
        public string CorrelationId { get; set; }

        public string BeforeStateJson { get; set; }

        public string AfterStateJson { get; set; }
    }
}
