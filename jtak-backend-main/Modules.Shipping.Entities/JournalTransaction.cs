using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Modules.Accounting.Entities
{
    public class JournalTransaction : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(100)]
        public string TransactionNumber { get; set; }

        public DateTime PostedDate { get; set; } = DateTime.UtcNow;

        [Required]
        [MaxLength(100)]
        public string ReferenceType { get; set; }

        [Required]
        [MaxLength(100)]
        public string ReferenceId { get; set; }

        [MaxLength(150)]
        public string IdempotencyKey { get; set; }

        [MaxLength(500)]
        public string Description { get; set; }

        public virtual ICollection<LedgerEntry> Entries { get; set; } = new List<LedgerEntry>();
    }

    public class JournalTransactionDto
    {
        public Guid Id { get; set; }
        public string TransactionNumber { get; set; }
        public DateTime PostedDate { get; set; }
        public string ReferenceType { get; set; }
        public string ReferenceId { get; set; }
        public string IdempotencyKey { get; set; }
        public string Description { get; set; }
        public List<LedgerEntryDto> Entries { get; set; } = new List<LedgerEntryDto>();
    }
}
