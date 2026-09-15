using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Modules.Accounting.Entities
{
    public class Account : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(100)]
        public string AccountCode { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; }

        public AccountType Type { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "SYP";

        public Guid? OwnerUserId { get; set; }

        public int? OwnerMerchantId { get; set; }

        public bool IsActive { get; set; } = true;

        public virtual ICollection<LedgerEntry> LedgerEntries { get; set; } = new List<LedgerEntry>();
    }

    public class AccountDto
    {
        public Guid Id { get; set; }
        public string AccountCode { get; set; }
        public string Name { get; set; }
        public AccountType Type { get; set; }
        public string Currency { get; set; }
        public Guid? OwnerUserId { get; set; }
        public int? OwnerMerchantId { get; set; }
        public bool IsActive { get; set; }
        public decimal CurrentBalance { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}
