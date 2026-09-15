using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Accounting.Entities
{
    public class DailySettlementBatch : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(100)]
        public string BatchCode { get; set; }

        [Required]
        public Guid CaptainUserId { get; set; }

        public DateTime BatchDate { get; set; } = DateTime.UtcNow;

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCashCollected { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalWagesEarned { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal NetCashRemitted { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal DiscrepancyAmount { get; set; }

        [MaxLength(500)]
        public string DiscrepancyReason { get; set; }

        public Guid HandledByAdminId { get; set; }

        public Guid SettlementTransactionId { get; set; }

        public bool IsLocked { get; set; } = true;

        [MaxLength(500)]
        public string Notes { get; set; }
    }

    public class DailySettlementBatchDto
    {
        public Guid Id { get; set; }
        public string BatchCode { get; set; }
        public Guid CaptainUserId { get; set; }
        public string CaptainName { get; set; }
        public DateTime BatchDate { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalWagesEarned { get; set; }
        public decimal NetCashRemitted { get; set; }
        public decimal DiscrepancyAmount { get; set; }
        public string DiscrepancyReason { get; set; }
        public Guid HandledByAdminId { get; set; }
        public Guid SettlementTransactionId { get; set; }
        public bool IsLocked { get; set; }
        public string Notes { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
