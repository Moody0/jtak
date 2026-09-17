using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public interface ILedgerService
    {
        Task<Account> GetOrCreateUserAccountAsync(Guid userId, AccountType type, string accountCodePrefix, string accountName, string currency = "SYP");
        Task<Account> GetOrCreateMerchantAccountAsync(int merchantId, string merchantName, string currency = "SYP");
        Task<Account> GetOrCreateSystemAccountAsync(string accountCode, string accountName, AccountType type, string currency = "SYP");
        Task<JournalTransactionDto> PostTransactionAsync(PostTransactionRequest request);
        Task<JournalTransactionDto> PostOrderDeliveredSplitAsync(OrderDeliveredSplitRequest request);
        Task<JournalTransactionDto> PostCaptainCashHandoverAsync(Guid captainUserId, decimal amount, string referenceId, string captainName = null, string currency = "SYP");
        Task<JournalTransactionDto> PostOrderCancellationReversalAsync(int orderId, string reason);
        Task<decimal> GetAccountBalanceAsync(Guid accountId);
        Task<decimal> GetUserCashFloatBalanceAsync(Guid captainUserId, string currency = "SYP");
        Task<decimal> GetUserEarningsBalanceAsync(Guid captainUserId, string currency = "SYP");
        Task<decimal> GetMerchantPayableBalanceAsync(int merchantId, string currency = "SYP");
        Task<List<AccountStatementItemDto>> GetAccountStatementAsync(Guid accountId, DateTime? fromDate = null, DateTime? toDate = null);
        Task<JournalTransactionDto> PostGatewaySettlementToBankAsync(decimal amount, string providerReference = null, string currency = "SYP");
        Task SeedSystemAccountsAsync();
    }
}
