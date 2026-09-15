using Solf.Base;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Accounting.Entities
{
    public class LedgerEntry : AuditableEntity
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public Guid JournalTransactionId { get; set; }

        [Required]
        public Guid AccountId { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Debit { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Credit { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "SYP";

        [MaxLength(500)]
        public string Memo { get; set; }

        public virtual JournalTransaction Transaction { get; set; }
        public virtual Account Account { get; set; }
    }

    public class LedgerEntryDto
    {
        public long Id { get; set; }
        public Guid JournalTransactionId { get; set; }
        public Guid AccountId { get; set; }
        public string AccountCode { get; set; }
        public string AccountName { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public string Currency { get; set; }
        public string Memo { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
