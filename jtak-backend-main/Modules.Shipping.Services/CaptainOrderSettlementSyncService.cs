using App.Orders.Data;
using App.Shared.Entities.Enums;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Orders.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    /// <summary>
    /// Cash handovers and fleet settlements already post the financial result.
    /// Reconcile order flags from that evidence without posting money again.
    /// Partial handovers and unpaid earnings never close an order here.
    /// </summary>
    public sealed class CaptainOrderSettlementSyncService
    {
        private readonly AccountingDbContext _accounting;
        private readonly OrdersDbContext _orders;

        public CaptainOrderSettlementSyncService(AccountingDbContext accounting, OrdersDbContext orders)
        {
            _accounting = accounting;
            _orders = orders;
        }

        public async Task<int> SyncAsync(Guid captainId)
        {
            var openOrders = await _orders.Set<Order>().AsNoTracking()
                .Where(o => o.DeliveryId == captainId && o.DeliveredAt != null && !o.IsSettled)
                .ToListAsync();
            if (openOrders.Count == 0) return 0;

            // Entry IDs describe posting order, even when timestamps have the
            // same precision. Evaluate the balances after each entire journal.
            var entries = await _accounting.LedgerEntries.AsNoTracking()
                .Where(e => e.Currency == "SYP" && e.Account.Currency == "SYP" && e.Account.OwnerUserId == captainId &&
                    ((e.Account.Type == AccountType.Asset &&
                      e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix)) ||
                     (e.Account.Type == AccountType.Liability &&
                      e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix))))
                .Select(e => new
                {
                    e.Id, e.JournalTransactionId, e.Debit, e.Credit,
                    IsCash = e.Account.Type == AccountType.Asset,
                    e.Transaction.ReferenceType, e.Transaction.ReferenceId, e.Transaction.PostedDate
                }).OrderBy(e => e.Id).ToListAsync();

            var batches = await _accounting.DailySettlementBatches.AsNoTracking()
                .Where(b => b.CaptainUserId == captainId && b.IsLocked)
                .ToListAsync();
            var requests = await _accounting.SettlementRequests.AsNoTracking()
                .Where(r => r.RequestedByUserId == captainId && r.Currency == "SYP" &&
                    r.Status == SettlementRequestStatus.Completed && r.LedgerTransactionId != null)
                .ToListAsync();

            var postedOrders = new HashSet<int>();
            decimal cash = 0m, earnings = 0m;
            var changed = 0;
            foreach (var journal in entries.GroupBy(e => e.JournalTransactionId).OrderBy(g => g.Min(e => e.Id)))
            {
                var transaction = journal.First();
                cash += journal.Where(e => e.IsCash).Sum(e => e.Debit - e.Credit);
                earnings += journal.Where(e => !e.IsCash).Sum(e => e.Credit - e.Debit);

                if (transaction.ReferenceType == "OrderDelivery" &&
                    int.TryParse(transaction.ReferenceId, out var orderId) &&
                    journal.Any(e => (e.IsCash && e.Debit > 0m) || (!e.IsCash && e.Credit > 0m)))
                    postedOrders.Add(orderId);

                var batch = batches.FirstOrDefault(b => b.SettlementTransactionId == journal.Key);
                var request = requests.FirstOrDefault(r => r.LedgerTransactionId == journal.Key);
                var confirmed = transaction.ReferenceType switch
                {
                    "FleetSettlement" or "CaptainSettlement" => batch != null,
                    "CaptainSettlementRequest" or "CaptainEarningsPayout" => request != null,
                    "CaptainCashHandover" => true, // This journal is the confirmed cash receipt.
                    _ => false
                };
                if (!confirmed) continue;
                if (!journal.Any(e => (e.IsCash && e.Credit > 0m) || (!e.IsCash && e.Debit > 0m)))
                    continue;

                var batchCode = batch?.BatchCode ?? request?.RequestNumber ?? $"CASH-{journal.Key:N}";
                foreach (var order in openOrders.Where(o => !o.IsSettled &&
                    o.DeliveredAt <= transaction.PostedDate && postedOrders.Contains(o.Id)))
                {
                    var hasCash = order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery &&
                        (!order.ActualCashCollected.HasValue || order.ActualCashCollected.Value > 0m);
                    var hasEarnings = order.CaptainCompensationType != CaptainCompensationType.SalariedEmployee &&
                        order.CaptainEarning > 0m;
                    if ((hasCash && Math.Abs(cash) > 0.001m) ||
                        (hasEarnings && Math.Abs(earnings) > 0.001m)) continue;

                    var settledAt = batch?.BatchDate ?? request?.CompletedAt ?? transaction.PostedDate;
                    // Update only the settlement metadata, never a detached
                    // financial snapshot or a concurrently completed settlement.
                    var affected = await _orders.Set<Order>()
                        .Where(o => o.Id == order.Id && o.DeliveryId == captainId && !o.IsSettled)
                        .ExecuteUpdateAsync(update => update
                            .SetProperty(o => o.IsSettled, true)
                            .SetProperty(o => o.SettledAt, (DateTime?)settledAt)
                            .SetProperty(o => o.SettlementBatchId, batchCode));
                    order.IsSettled = true;
                    changed += affected;
                }
            }
            return changed;
        }
    }
}
