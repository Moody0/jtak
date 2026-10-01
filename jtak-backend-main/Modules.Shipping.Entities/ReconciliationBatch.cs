using Solf.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Modules.Accounting.Entities
{
    public enum ReconciliationBatchStatus : byte
    {
        Discovered = 0,
        Staged = 1,
        Approved = 2,
        Executing = 3,
        Completed = 4,
        RolledBack = 5,
        Rejected = 6
    }

    public enum ReconciliationIssueType : byte
    {
        DeliveryFeeMismatch = 1,
        MissingDeliveredLedgerTransaction = 2,
        UnbalancedLedgerTransaction = 3,
        DriverCashCustodyMismatch = 4,
        CompareAtPricingMismatch = 5,
        ZeroCaptainEarnings = 6,
        CanceledOrderUnrestoredInventory = 7,
        DuplicateOrder = 8,
        DuplicateDriverAssignment = 9,
        PeriodMismatchSales = 10
    }

    public enum StagedCorrectionStatus : byte
    {
        PendingReview = 0,
        Approved = 1,
        Applied = 2,
        Skipped = 3,
        Failed = 4
    }

    /// <summary>
    /// Staging container for production data reconciliation runs.
    /// Ensures that financial issues are discovered read-only, staged for human/financial approval,
    /// and executed idempotently without direct, un-audited production mutations.
    /// </summary>
    public class ReconciliationBatch : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required, MaxLength(80)]
        public string BatchNumber { get; set; }

        [MaxLength(200)]
        public string Operator { get; set; }

        [MaxLength(500)]
        public string Reason { get; set; }

        [MaxLength(500)]
        public string SourceSnapshotManifest { get; set; }

        public ReconciliationBatchStatus Status { get; set; } = ReconciliationBatchStatus.Staged;

        public DateTime? ApprovedAt { get; set; }

        [MaxLength(200)]
        public string ApprovedBy { get; set; }

        [MaxLength(1000)]
        public string ApprovalNotes { get; set; }

        public DateTime? ExecutedAt { get; set; }

        [MaxLength(200)]
        public string ExecutedBy { get; set; }

        public int TotalIssuesDiscovered { get; set; }
        public int TotalStagedCorrections { get; set; }
        public int TotalAppliedCorrections { get; set; }
        public int TotalFailedCorrections { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalFinancialAdjustmentDebit { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalFinancialAdjustmentCredit { get; set; }

        public virtual ICollection<ReconciliationStagedCorrection> StagedCorrections { get; set; } = new List<ReconciliationStagedCorrection>();
    }

    /// <summary>
    /// Immutable record of a proposed correction for an identified financial or data inconsistency.
    /// Stores the exact before and proposed after JSON snapshots for audit and verification.
    /// </summary>
    public class ReconciliationStagedCorrection : AuditableEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid BatchId { get; set; }

        [ForeignKey(nameof(BatchId))]
        public virtual ReconciliationBatch Batch { get; set; }

        public ReconciliationIssueType IssueType { get; set; }

        public int? OrderId { get; set; }

        public Guid? UserId { get; set; }

        public int? MerchantId { get; set; }

        [MaxLength(80)]
        public string TargetEntityType { get; set; }

        [MaxLength(128)]
        public string TargetEntityId { get; set; }

        public string BeforeStateJson { get; set; }

        public string ProposedAfterStateJson { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal AdjustmentAmount { get; set; }

        [MaxLength(8)]
        public string Currency { get; set; } = "SYP";

        [MaxLength(1000)]
        public string Justification { get; set; }

        public StagedCorrectionStatus Status { get; set; } = StagedCorrectionStatus.PendingReview;

        [MaxLength(100)]
        public string ApplicationResultJournalTxnId { get; set; }

        [MaxLength(1000)]
        public string FailureReason { get; set; }

        public DateTime? AppliedAt { get; set; }
    }

    #region DTOs

    public class ReconciliationDiscoveryOptions
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public List<ReconciliationIssueType> IssuesToScan { get; set; }
        public int MaxResultsPerIssue { get; set; } = 500;
    }

    public class DiscrepancyItemDto
    {
        public ReconciliationIssueType IssueType { get; set; }
        public int? OrderId { get; set; }
        public Guid? UserId { get; set; }
        public int? MerchantId { get; set; }
        public string EntityType { get; set; }
        public string EntityId { get; set; }
        public string Description { get; set; }
        public decimal CurrentValue { get; set; }
        public decimal ExpectedValue { get; set; }
        public decimal Variance { get; set; }
        public string Currency { get; set; } = "SYP";
        public object BeforeSnapshot { get; set; }
        public object ProposedCorrection { get; set; }
    }

    public class ReconciliationDiscoveryReportDto
    {
        public DateTime ScanTimeUtc { get; set; } = DateTime.UtcNow;
        public int TotalIssuesDiscovered { get; set; }
        public List<DiscrepancyItemDto> DeliveryFeeDiscrepancies { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> MissingDeliveredLedgerTransactions { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> UnbalancedLedgerTransactions { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> DriverCashCustodyDiscrepancies { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> CompareAtPricingDiscrepancies { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> ZeroCaptainEarningsDiscrepancies { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> CanceledOrdersUnrestoredInventory { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> DuplicateOrders { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> DuplicateDriverAssignments { get; set; } = new List<DiscrepancyItemDto>();
        public List<DiscrepancyItemDto> PeriodMismatchSales { get; set; } = new List<DiscrepancyItemDto>();
        public Dictionary<string, int> IssueCounts { get; set; } = new Dictionary<string, int>();
        public decimal EstimatedNetFinancialAdjustment { get; set; }
    }

    public class StageCorrectionsRequest
    {
        public string Reason { get; set; }
        public string SourceSnapshotManifest { get; set; }
        public List<DiscrepancyItemDto> SelectedDiscrepancies { get; set; }
        public ReconciliationDiscoveryOptions DiscoveryOptions { get; set; }
    }

    public class ReconciliationBatchSummaryDto
    {
        public Guid Id { get; set; }
        public string BatchNumber { get; set; }
        public string Operator { get; set; }
        public string Reason { get; set; }
        public string SourceSnapshotManifest { get; set; }
        public ReconciliationBatchStatus Status { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public string ApprovedBy { get; set; }
        public DateTime? ExecutedAt { get; set; }
        public string ExecutedBy { get; set; }
        public int TotalIssuesDiscovered { get; set; }
        public int TotalStagedCorrections { get; set; }
        public int TotalAppliedCorrections { get; set; }
        public int TotalFailedCorrections { get; set; }
        public decimal TotalFinancialAdjustmentDebit { get; set; }
        public decimal TotalFinancialAdjustmentCredit { get; set; }
    }

    public class ReconciliationBatchDto : ReconciliationBatchSummaryDto
    {
        public string ApprovalNotes { get; set; }
        public List<ReconciliationStagedCorrectionDto> StagedCorrections { get; set; } = new List<ReconciliationStagedCorrectionDto>();
    }

    public class ReconciliationStagedCorrectionDto
    {
        public Guid Id { get; set; }
        public Guid BatchId { get; set; }
        public ReconciliationIssueType IssueType { get; set; }
        public int? OrderId { get; set; }
        public Guid? UserId { get; set; }
        public int? MerchantId { get; set; }
        public string TargetEntityType { get; set; }
        public string TargetEntityId { get; set; }
        public string BeforeStateJson { get; set; }
        public string ProposedAfterStateJson { get; set; }
        public decimal AdjustmentAmount { get; set; }
        public string Currency { get; set; }
        public string Justification { get; set; }
        public StagedCorrectionStatus Status { get; set; }
        public string ApplicationResultJournalTxnId { get; set; }
        public string FailureReason { get; set; }
        public DateTime? AppliedAt { get; set; }
    }

    public class ReconciliationBatchExecutionResultDto
    {
        public Guid BatchId { get; set; }
        public string BatchNumber { get; set; }
        public ReconciliationBatchStatus Status { get; set; }
        public int AppliedCount { get; set; }
        public int FailedCount { get; set; }
        public int SkippedCount { get; set; }
        public List<string> CreatedJournalTransactionNumbers { get; set; } = new List<string>();
        public List<string> Errors { get; set; } = new List<string>();
    }

    public class ApproveReconciliationBatchRequest
    {
        public string Notes { get; set; }
    }

    #endregion
}
