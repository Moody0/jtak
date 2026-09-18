using System;
using System.Collections.Generic;
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
            // 1. All active orders belonging to the 4 Admin categories:
            // - Waiting for approval (بانتظار الموافقة)
            // - No courier assigned (بدون مندوب)
            // - Ready for delivery (جاهز للتوصيل)
            // - In delivery (جاري التوصيل)
            // Strictly excludes: Completed/Delivered, Cancelled, Rejected, carts/unplaced orders
            var placedOrders = await _ordersDb.Orders
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.OrderStatus == OrderStatus.Success && o.DeliveredAt == null)
                .ToListAsync();

            int pendingOrders = 0;
            foreach (var order in placedOrders)
            {
                var details = order.OrderDetails ?? (ICollection<OrderDetail>)Array.Empty<OrderDetail>();

                bool allTerminal = details.Count > 0 && details.All(d =>
                    d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantRejected);

                if (allTerminal) continue;

                var active = details.Where(d =>
                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.MerchantRejected).ToList();

                bool isDelivered = active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered);
                if (isDelivered) continue;

                bool hasAssignedDriver = order.DeliveryId.HasValue &&
                                         !string.IsNullOrWhiteSpace(order.DeliveryUser) &&
                                         !order.DeliveryUser.Contains("?");

                bool isPending = details.Count == 0 || active.Any(d =>
                    d.OrderDetailStatus == OrderDetailStatus.Pending ||
                    d.OrderDetailStatus == OrderDetailStatus.CustomerPending ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantAccepted);

                bool isReady = active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);

                bool isInTransit = active.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted);

                bool isUnassigned = !hasAssignedDriver;

                // Distinct 4-bucket union: counted once per order ID
                if (isPending || isUnassigned || isReady || isInTransit)
                {
                    pendingOrders++;
                }
            }

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
