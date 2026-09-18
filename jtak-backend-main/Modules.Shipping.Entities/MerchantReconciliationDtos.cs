using System;
using System.Collections.Generic;

namespace Modules.Accounting.Entities
{
    public class MerchantReconciliationSummaryDto
    {
        public decimal TotalMerchantPayables { get; set; }
        public decimal TotalReservedSettlements { get; set; }
        public decimal TotalAvailableForSettlement { get; set; }
        public decimal TotalJTakCommission { get; set; }
        public decimal TotalCompletedSettlements { get; set; }
        public int ActiveMerchantsCount { get; set; }
        public int PendingRequestsCount { get; set; }
        public string Currency { get; set; } = "SYP";
    }

    public class MerchantReconciliationItemDto
    {
        public int MerchantId { get; set; }
        public string MerchantName { get; set; }
        public string OwnerName { get; set; }
        public string Phone { get; set; }
        public int OrdersCount { get; set; }
        public decimal GrossSales { get; set; }
        public decimal JTakShare { get; set; }
        public decimal MerchantNet { get; set; }
        public decimal ReservedAmount { get; set; }
        public decimal AvailableAmount { get; set; }
        public decimal ApprovedAwaitingReceiptAmount { get; set; }
        public decimal CurrentBalance { get; set; }
        public DateTime? LastSettlementDate { get; set; }
        public SettlementRequestStatus? LastSettlementStatus { get; set; }
        public string LastSettlementRequestNumber { get; set; }
        public string Currency { get; set; } = "SYP";
    }

    public class MerchantReconciliationDataTableRequest
    {
        public string SearchTerm { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public string SortColumn { get; set; }
        public string SortDirection { get; set; } = "ASC";
    }

    public class MerchantReconciliationDataTableResultDto
    {
        public List<MerchantReconciliationItemDto> Items { get; set; } = new List<MerchantReconciliationItemDto>();
        public int TotalRecords { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class MerchantStatementRequestDto
    {
        public string SearchTerm { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 50;
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }

    public class MerchantStatementDto
    {
        public int MerchantId { get; set; }
        public string MerchantName { get; set; }
        public string OwnerName { get; set; }
        public string Phone { get; set; }
        public string AccountCode { get; set; }
        public decimal CurrentBalance { get; set; }
        public decimal ReservedAmount { get; set; }
        public decimal AvailableAmount { get; set; }
        public decimal ApprovedAwaitingReceiptAmount { get; set; }
        public string Currency { get; set; } = "SYP";
        public int TotalRecords { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public List<MerchantStatementTransactionDto> Items { get; set; } = new List<MerchantStatementTransactionDto>();
        public List<MerchantSettlementHistoryItemDto> SettlementHistory { get; set; } = new List<MerchantSettlementHistoryItemDto>();
    }

    public class MerchantStatementTransactionDto
    {
        public long EntryId { get; set; }
        public Guid TransactionId { get; set; }
        public string TransactionNumber { get; set; }
        public DateTime PostedDate { get; set; }
        public string Type { get; set; }
        public int? OrderNumber { get; set; }
        public string MerchantTitle { get; set; }
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }
        public DateTime? OrderDate { get; set; }
        public decimal? GrossAmount { get; set; }
        public decimal? JTakShare { get; set; }
        public decimal? MerchantNet { get; set; }
        public decimal? Discount { get; set; }
        public decimal? DeliveryFee { get; set; }
        public string PaymentMethod { get; set; }
        public string FinancialStatus { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public decimal RunningBalance { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Description { get; set; }
        public string SettlementRequestNumber { get; set; }
        public string ReferenceType { get; set; }
        public string ReferenceId { get; set; }
    }

    public class MerchantSettlementHistoryItemDto
    {
        public Guid Id { get; set; }
        public string RequestNumber { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Method { get; set; }
        public string AccountDetails { get; set; }
        public DateTime RequestedAt { get; set; }
        public SettlementRequestStatus Status { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public DateTime? RejectedAt { get; set; }
        public string RejectionReason { get; set; }
        public DateTime? CompletedAt { get; set; }
        public string PayoutSourceAccount { get; set; }
        public string ApprovedBy { get; set; }
        public string ConfirmedBy { get; set; }
        public string Notes { get; set; }
    }
}
