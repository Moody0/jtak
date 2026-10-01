using System.Collections.Generic;
using System.Threading.Tasks;

namespace Modules.Shipping.Services
{
    public class OrderAccountingRetryResult
    {
        public int TotalFound { get; set; }
        public int Succeeded { get; set; }
        public int Failed { get; set; }
        public List<int> SucceededOrderIds { get; set; } = new List<int>();
        public List<int> FailedOrderIds { get; set; } = new List<int>();
    }

    public interface IOrderAccountingRetryService
    {
        Task<OrderAccountingRetryResult> RetryPendingAccountingOrdersAsync(int maxBatchSize = 50);
        Task<bool> RetryOrderAccountingAsync(int orderId);
    }
}
