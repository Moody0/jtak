using System;
using System.Collections.Generic;

namespace Modules.Accounting.Entities
{
    public class PostTransactionRequest
    {
        public string TransactionNumber { get; set; }
        public string ReferenceType { get; set; }
        public string ReferenceId { get; set; }
        public string IdempotencyKey { get; set; }
        public string Description { get; set; }
        public List<PostLedgerEntryRequest> Entries { get; set; } = new List<PostLedgerEntryRequest>();
    }

    public class PostLedgerEntryRequest
    {
        public Guid AccountId { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Memo { get; set; }
    }

    public class OrderDeliveredSplitRequest
    {
        public int OrderId { get; set; }
        public Guid CaptainUserId { get; set; }
        public string CaptainName { get; set; }
        public decimal DeliveryFee { get; set; }
        public bool TotalsIncludeDeliveryFee { get; set; }
        public string Currency { get; set; } = "SYP";
        public bool IsCod { get; set; } = true;
        public bool IsCompanyCash { get; set; } = false;
        public List<MerchantSplitItem> MerchantSplits { get; set; } = new List<MerchantSplitItem>();
    }

    public class MerchantSplitItem
    {
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public decimal TotalAmount { get; set; }
        public decimal MerchantAmount { get; set; }
        public decimal PlatformCommission { get; set; }
        public bool IsPlatformOwned { get; set; }
        public decimal CaptainEarningAmount { get; set; }
    }

    public class AccountStatementItemDto
    {
        public long EntryId { get; set; }
        public Guid TransactionId { get; set; }
        public string TransactionNumber { get; set; }
        public DateTime PostedDate { get; set; }
        public string ReferenceType { get; set; }
        public string ReferenceId { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public decimal RunningBalance { get; set; }
        public string Currency { get; set; }
        public string Memo { get; set; }
    }
}
