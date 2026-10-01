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

    public enum ErrandStatus
    {
        Submitted = 0,
        Quoted = 1,
        Approved = 2,
        Assigned = 3,
        Purchased = 4,
        Delivered = 5,
        Declined = 6,
        Cancelled = 7,
        PurchasePending = 8,
        DeliveryPending = 9,
        ReturnPending = 10,
        Returned = 11,
        Unavailable = 12
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

        // Populated only for the “طلبات” workflow. The approved retail price
        // stays immutable after approval; the actual shop cost records any
        // contracted discount earned by JTAK.
        public Guid? ErrandRequestKey { get; set; }
        public ErrandStatus? ErrandStatus { get; set; }
        public decimal? ErrandItemPrice { get; set; }
        public decimal? ErrandDeliveryFee { get; set; }
        // Snapshot of the dedicated errand-driver wage at quote time. Null on
        // legacy rows; those retain the historic delivery-fee-as-wage behavior.
        public decimal? ErrandDriverEarning { get; set; }
        public Guid? ErrandQuoteKey { get; set; }
        public DateTime? ErrandQuoteExpiresAt { get; set; }
        public DateTime? ErrandApprovedAt { get; set; }
        public Guid? ErrandDriverUserId { get; set; }
        public string ErrandDeliveryCode { get; set; }
        public decimal? ErrandPurchaseCost { get; set; }
        public string ErrandReceiptReference { get; set; }
        public string ErrandReceiptPhotoToken { get; set; }
        public DateTime? ErrandPurchasedAt { get; set; }
        public decimal? ErrandRefundAmount { get; set; }
        public string ErrandReturnReason { get; set; }
        public DateTime? ErrandReturnedAt { get; set; }
        public decimal? ErrandCashCollected { get; set; }
        public DateTime? ErrandDeliveredAt { get; set; }
        public string ErrandItemsJson { get; set; }
        public string ErrandPickupPlace { get; set; }
        public decimal? ErrandPickupLatitude { get; set; }
        public decimal? ErrandPickupLongitude { get; set; }
        public string ErrandUnavailableReason { get; set; }
        public int ErrandDeliveryCodeFailedAttempts { get; set; }
    }

    public class ErrandStatusEvent
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }
        public int SupportMessageId { get; set; }
        public int? FromStatus { get; set; }
        public int ToStatus { get; set; }
        public Guid? ActorUserId { get; set; }
        [MaxLength(32)] public string ActorRole { get; set; }
        [MaxLength(500)] public string Note { get; set; }
        public DateTime CreatedDate { get; set; }
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
        public ErrandStatus? ErrandStatus { get; set; }
        public decimal? ErrandItemPrice { get; set; }
        public decimal? ErrandDeliveryFee { get; set; }
        public decimal? ErrandDriverEarning { get; set; }
        public DateTime? ErrandQuoteExpiresAt { get; set; }
        public Guid? ErrandDriverUserId { get; set; }
        public decimal? ErrandPurchaseCost { get; set; }
        public string ErrandReceiptReference { get; set; }
        public string ErrandReceiptPhotoToken { get; set; }
        public decimal? ErrandRefundAmount { get; set; }
        public string ErrandReturnReason { get; set; }
        public string ErrandUnavailableReason { get; set; }
        public decimal? ErrandCashCollected { get; set; }
        public int ErrandDeliveryCodeFailedAttempts { get; set; }
        public string ErrandLatestException { get; set; }
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
