using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public interface ISettlementHistoryService
    {
        Task<SettlementHistoryDataTableResultDto> GetDataTableAsync(SettlementHistoryDataTableRequest request);
        Task<SettlementHistorySummaryDto> GetSummaryAsync(SettlementHistoryPartyFilter partyFilter = SettlementHistoryPartyFilter.All, DateTime? fromDate = null, DateTime? toDate = null, string searchTerm = null);
        Task<SettlementReceiptDto> GetReceiptAsync(string id);
        Task<List<SettlementHistoryItemDto>> GetPrintDataAsync(SettlementHistoryDataTableRequest request);
    }
}
