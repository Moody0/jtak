using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Accounting.Entities
{
    public enum SettlementPartyType : byte
    {
        Captain = 0,
        Merchant = 1
    }

    public enum SettlementRequestStatus : byte
    {
        Pending = 0,
        Approved = 1,
        Rejected = 2,
        Completed = 3
    }

    /// <summary>
    /// A user initiated cash handover/payout request. Money is only moved by the
    /// ledger when a captain request is accepted or an approved merchant payout
    /// is marked as received.
    /// </summary>
    public class SettlementRequest : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required, MaxLength(80)]
        public string RequestNumber { get; set; }

        public SettlementPartyType PartyType { get; set; }
        public SettlementRequestStatus Status { get; set; } = SettlementRequestStatus.Pending;
        public Guid RequestedByUserId { get; set; }

        [MaxLength(200)]
        public string RequestedByName { get; set; }

        [MaxLength(40)]
        public string RequestedByPhone { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        [Required, MaxLength(8)]
        public string Currency { get; set; } = "SYP";

        [MaxLength(80)]
        public string Method { get; set; }

        [MaxLength(500)]
        public string AccountDetails { get; set; }

        [MaxLength(500)]
        public string Notes { get; set; }

        [MaxLength(500)]
        public string RejectionReason { get; set; }

        public Guid? ReviewedByAdminId { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public Guid? CompletedByAdminId { get; set; }
        public DateTime? CompletedAt { get; set; }
        public Guid? LedgerTransactionId { get; set; }

        public virtual ICollection<SettlementRequestMerchantAllocation> MerchantAllocations { get; set; }
            = new List<SettlementRequestMerchantAllocation>();
    }

    public class SettlementRequestMerchantAllocation
    {
        [Key]
        public long Id { get; set; }
        public Guid SettlementRequestId { get; set; }
        public int MerchantId { get; set; }

        [MaxLength(200)]
        public string MerchantTitle { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        public virtual SettlementRequest SettlementRequest { get; set; }
    }

    public class CreateSettlementRequestDto
    {
        public decimal? Amount { get; set; }
        public string Method { get; set; }
        public string AccountDetails { get; set; }
        public string Notes { get; set; }
    }

    public class ReviewSettlementRequestDto
    {
        public string Notes { get; set; }
        public string Reason { get; set; }
    }

    public class SettlementRequestDto
    {
        public Guid Id { get; set; }
        public string RequestNumber { get; set; }
        public SettlementPartyType PartyType { get; set; }
        public SettlementRequestStatus Status { get; set; }
        public Guid RequestedByUserId { get; set; }
        public string RequestedByName { get; set; }
        public string RequestedByPhone { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; }
        public string Method { get; set; }
        public string AccountDetails { get; set; }
        public string Notes { get; set; }
        public string RejectionReason { get; set; }
        public Guid? ReviewedByAdminId { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
        public Guid? LedgerTransactionId { get; set; }
        public DateTime CreatedDate { get; set; }
        public List<SettlementMerchantAllocationDto> MerchantAllocations { get; set; } = new();
    }

    public class SettlementMerchantAllocationDto
    {
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public decimal Amount { get; set; }
    }
}
