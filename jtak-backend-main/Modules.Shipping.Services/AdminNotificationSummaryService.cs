using System;
using System.Linq;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Domain;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Orders.Entities;

namespace Modules.Accounting.Services
{
    public interface IAdminNotificationSummaryService
    {
        Task<AdminNotificationSummaryDto> GetSummaryAsync();
    }

    public class AdminNotificationSummaryService : IAdminNotificationSummaryService
    {
        private readonly OrdersDbContext _ordersDb;
        private readonly AppDbContext _appDb;
        private readonly AccountingDbContext _accountingDb;

        public AdminNotificationSummaryService(
            OrdersDbContext ordersDb,
            AppDbContext appDb,
            AccountingDbContext accountingDb)
        {
            _ordersDb = ordersDb ?? throw new ArgumentNullException(nameof(ordersDb));
            _appDb = appDb ?? throw new ArgumentNullException(nameof(appDb));
            _accountingDb = accountingDb ?? throw new ArgumentNullException(nameof(accountingDb));
        }

        public async Task<AdminNotificationSummaryDto> GetSummaryAsync()
        {
            // 1. All active non-terminal orders:
            // Confirmed placed orders (OrderStatus.Success, DeliveredAt == null) with active non-terminal details
            var pendingOrders = await _ordersDb.Orders
                .AsNoTracking()
                .Where(o => o.OrderStatus == OrderStatus.Success && o.DeliveredAt == null)
                .Where(o => o.OrderDetails.Any(d =>
                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                    d.OrderDetailStatus != OrderDetailStatus.Delivered))
                .CountAsync();

            // 2. Unread / New customer support messages
            var pendingSupportMessages = await _appDb.SupportMessages
                .AsNoTracking()
                .CountAsync(x => x.Status == SupportMessageStatus.New);

            // 3. Pending driver cash handover settlement requests
            var pendingDriverSettlements = await _accountingDb.SettlementRequests
                .AsNoTracking()
                .CountAsync(x => x.PartyType == SettlementPartyType.Captain && x.Status == SettlementRequestStatus.Pending);

            // 4. Pending merchant settlement payout requests
            var pendingMerchantSettlements = await _accountingDb.SettlementRequests
                .AsNoTracking()
                .CountAsync(x => x.PartyType == SettlementPartyType.Merchant && x.Status == SettlementRequestStatus.Pending);

            var totalReconciliation = pendingDriverSettlements + pendingMerchantSettlements;

            return new AdminNotificationSummaryDto
            {
                Orders = pendingOrders,
                SupportMessages = pendingSupportMessages,
                DriverSettlements = pendingDriverSettlements,
                MerchantSettlements = pendingMerchantSettlements,
                Reconciliation = totalReconciliation,
                Users = 0,
                TotalActionable = pendingOrders + pendingSupportMessages + totalReconciliation
            };
        }
    }
}
