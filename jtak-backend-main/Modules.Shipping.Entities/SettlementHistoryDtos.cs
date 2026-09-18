using System;
using System.Collections.Generic;

namespace Modules.Accounting.Entities
{
    public enum SettlementHistoryPartyFilter : byte
    {
        All = 0,
        Merchant = 1,
        Captain = 2
    }

    public class SettlementHistoryItemDto
    {
        public string Id { get; set; }
        public string RequestNumber { get; set; }
        public SettlementPartyType PartyType { get; set; }
        public string PartyTypeLabel { get; set; }
        public string PartyName { get; set; }
        public string Phone { get; set; }
        public int? MerchantId { get; set; }
        public Guid? DriverId { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Method { get; set; }
        public string Status { get; set; } = "Completed";
        public DateTime? RequestedAt { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public DateTime CompletedAt { get; set; }
        public string ApprovedBy { get; set; }
        public string ConfirmedBy { get; set; }
        public string SourceAccount { get; set; }
        public string DestinationAccount { get; set; }
        public string JournalTransactionNumber { get; set; }
        public Guid? JournalTransactionId { get; set; }
        public string Notes { get; set; }
        public string OperationType { get; set; }
    }

    public class SettlementHistorySummaryDto
    {
        public int TotalCompletedCount { get; set; }
        public decimal TotalCompletedAmount { get; set; }
        public int MerchantCompletedCount { get; set; }
        public decimal MerchantCompletedAmount { get; set; }
        public int DriverCompletedCount { get; set; }
        public decimal DriverCompletedAmount { get; set; }
        public string Currency { get; set; } = "SYP";
    }

    public class SettlementHistoryDataTableRequest
    {
        public string SearchTerm { get; set; }
        public SettlementHistoryPartyFilter PartyFilter { get; set; } = SettlementHistoryPartyFilter.All;
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public string SortColumn { get; set; } = "CompletedAt";
        public string SortDirection { get; set; } = "DESC";
    }

    public class SettlementHistoryDataTableResultDto
    {
        public List<SettlementHistoryItemDto> Items { get; set; } = new List<SettlementHistoryItemDto>();
        public int TotalRecords { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public SettlementHistorySummaryDto Summary { get; set; }
    }

    public class SettlementReceiptDto
    {
        public string Id { get; set; }
        public string ReceiptNumber { get; set; }
        public string RequestNumber { get; set; }
        public SettlementPartyType PartyType { get; set; }
        public string ReceiptTitle { get; set; }
        public string PartyName { get; set; }
        public string Phone { get; set; }
        public int? MerchantId { get; set; }
        public Guid? DriverId { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Method { get; set; }
        public string Status { get; set; } = "مكتمل";
        public DateTime? RequestedAt { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public DateTime CompletedAt { get; set; }
        public string ApprovedBy { get; set; }
        public string ConfirmedBy { get; set; }
        public string VendorPayableAccount { get; set; }
        public string CaptainCashFloatAccount { get; set; }
        public string PayoutSourceAccount { get; set; }
        public string DestinationAccount { get; set; }
        public string JournalTransactionNumber { get; set; }
        public Guid? JournalTransactionId { get; set; }
        public string OperationType { get; set; }
        public string Notes { get; set; }
        public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;
    }
}
