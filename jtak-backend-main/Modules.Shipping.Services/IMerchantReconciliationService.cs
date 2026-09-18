using System;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public interface IMerchantReconciliationService
    {
        Task<MerchantReconciliationSummaryDto> GetSummaryAsync();
        Task<MerchantReconciliationDataTableResultDto> GetDataTableAsync(MerchantReconciliationDataTableRequest request);
        Task<MerchantStatementDto> GetMerchantStatementAsync(int merchantId, MerchantStatementRequestDto request);
    }
}
