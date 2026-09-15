using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public class CaptainSettlementSummaryDto
    {
        public Guid CaptainUserId { get; set; }
        public string CaptainName { get; set; }
        public string PhoneNumber { get; set; }
        public decimal CashFloatBalance { get; set; }
        public decimal WagesEarnedBalance { get; set; }
        public decimal ExpectedNetCashDue { get; set; }
        public string Currency { get; set; } = "SYP";
        public DateTime? LastSettlementDate { get; set; }
        public int TotalDeliveredOrders { get; set; }
    }

    public class SettleCaptainShiftRequest
    {
        public Guid CaptainUserId { get; set; }
        public decimal PhysicalCashReceived { get; set; }
        public string Currency { get; set; } = "SYP";
        public string Notes { get; set; }
        public string DiscrepancyReason { get; set; }
    }

    public class SettlementResultDto
    {
        public Guid SettlementBatchId { get; set; }
        public string BatchCode { get; set; }
        public Guid SettlementTransactionId { get; set; }
        public string TransactionNumber { get; set; }
        public Guid CaptainUserId { get; set; }
        public string CaptainName { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalWagesEarned { get; set; }
        public decimal ExpectedNetCash { get; set; }
        public decimal PhysicalCashReceived { get; set; }
        public decimal DiscrepancyAmount { get; set; }
        public string DiscrepancyReason { get; set; }
        public string Notes { get; set; }
        public DateTime SettledAt { get; set; }
    }

    public class CaptainShiftDetailsDto
    {
        public Guid CaptainUserId { get; set; }
        public string CaptainName { get; set; }
        public decimal CashFloatBalance { get; set; }
        public decimal WagesEarnedBalance { get; set; }
        public decimal ExpectedNetCashDue { get; set; }
        public string Currency { get; set; } = "SYP";
        public DateTime? LastSettlementDate { get; set; }
        public List<AccountStatementItemDto> FloatStatement { get; set; } = new List<AccountStatementItemDto>();
        public List<AccountStatementItemDto> EarningsStatement { get; set; } = new List<AccountStatementItemDto>();
    }

    public interface IEodReconciliationService
    {
        Task<List<CaptainSettlementSummaryDto>> GetFleetSettlementSummariesAsync();
        Task<CaptainShiftDetailsDto> GetCaptainShiftDetailsAsync(Guid captainUserId);
        Task<SettlementResultDto> SettleCaptainShiftAsync(SettleCaptainShiftRequest request, Guid handledByAdminId);
        Task<List<DailySettlementBatchDto>> GetSettlementHistoryAsync(int count = 50);
    }
}
