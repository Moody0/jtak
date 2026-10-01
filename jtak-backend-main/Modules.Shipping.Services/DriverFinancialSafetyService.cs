using System;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Domain;
using App.Shared.Services.Pricing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Orders.Entities;

namespace Modules.Accounting.Services;

public sealed class DriverCashPosition
{
    public decimal Cash { get; init; }
    public decimal ReservedForHandover { get; init; }
    public decimal ReservedForPurchases { get; init; }
    public decimal ExpectedCollections { get; init; }
    public bool HasUnfinishedAccounting { get; init; }
    public decimal SpendableCash => HasUnfinishedAccounting ? 0m :
        Math.Max(0m, Cash - ReservedForHandover - ReservedForPurchases);
}

/// <summary>One driver cash lock shared by assignments, purchases and settlements.
/// Reservations derive from durable requests; no separate reservation table can drift.
/// </summary>
public sealed class DriverFinancialSafetyService
{
    private readonly AccountingDbContext _accounting;
    private readonly ILedgerService _ledger;
    private readonly AppDbContext _app;
    private readonly OrdersDbContext _orders;

    public DriverFinancialSafetyService(AccountingDbContext accounting, ILedgerService ledger,
        AppDbContext app = null, OrdersDbContext orders = null)
    { _accounting = accounting; _ledger = ledger; _app = app; _orders = orders; }

    public async Task<DriverCashPosition> GetPositionAsync(Guid driverId, int? excludeErrandId = null,
        int? excludeOrderId = null, Guid? excludeHandoverId = null, string currency = "SYP")
    {
        var cash = await _ledger.GetUserCashFloatBalanceAsync(driverId, currency);
        var handoverAmounts = await _accounting.SettlementRequests.AsNoTracking().Where(x =>
            x.RequestedByUserId == driverId && x.PartyType == SettlementPartyType.Captain &&
            x.Currency == currency && (!excludeHandoverId.HasValue || x.Id != excludeHandoverId.Value) &&
            (x.Status == SettlementRequestStatus.Pending || x.Status == SettlementRequestStatus.Approved))
            .Select(x => x.Amount).ToListAsync();
        var handovers = handoverAmounts.Sum();
        decimal purchases = 0m, collections = 0m;
        var unfinished = false;
        if (_app != null) {
            var errands = await _app.SupportMessages.AsNoTracking().Where(x =>
                x.ErrandDriverUserId == driverId && (!excludeErrandId.HasValue || x.Id != excludeErrandId.Value) &&
                (x.ErrandStatus == ErrandStatus.Assigned || x.ErrandStatus == ErrandStatus.Purchased ||
                 x.ErrandStatus == ErrandStatus.PurchasePending || x.ErrandStatus == ErrandStatus.DeliveryPending ||
                 x.ErrandStatus == ErrandStatus.ReturnPending))
                .Select(x => new { x.ErrandStatus, x.ErrandItemPrice, x.ErrandDeliveryFee }).ToListAsync();
            purchases = errands.Where(x => x.ErrandStatus == ErrandStatus.Assigned)
                .Sum(x => x.ErrandItemPrice.GetValueOrDefault());
            collections = errands.Where(x => x.ErrandStatus == ErrandStatus.Assigned || x.ErrandStatus == ErrandStatus.Purchased)
                .Sum(x => x.ErrandItemPrice.GetValueOrDefault() + x.ErrandDeliveryFee.GetValueOrDefault());
            unfinished = errands.Any(x => x.ErrandStatus == ErrandStatus.PurchasePending ||
                x.ErrandStatus == ErrandStatus.DeliveryPending || x.ErrandStatus == ErrandStatus.ReturnPending);
        }
        if (_orders != null) {
            unfinished |= await _orders.Orders.AsNoTracking().AnyAsync(x => x.DeliveryId == driverId &&
                (x.AccountingStatus == OrderAccountingStatus.PendingAccounting || x.AccountingStatus == OrderAccountingStatus.Failed));
            // Use the fulfillment calculator, including legacy price fallback.
            var active = await _orders.Orders.AsNoTracking().Include(x => x.OrderDetails).Where(x =>
                x.DeliveryId == driverId && (!excludeOrderId.HasValue || x.Id != excludeOrderId.Value) &&
                x.PaymentMethod == PaymentMethod.PayOnDelivery && x.DeliveredAt == null &&
                x.OrderStatus == OrderStatus.Success && x.DeletionDate == null &&
                x.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.Pending ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantAccepted || d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup ||
                    d.OrderDetailStatus == OrderDetailStatus.ShippingStarted || d.OrderDetailStatus == OrderDetailStatus.CustomerPending)).ToListAsync();
            var calculator = new OrderMoneyCalculationService();
            foreach (var order in active) {
                var details = (order.OrderDetails ?? Array.Empty<OrderDetail>()).Select(x => new OrderDetailDto {
                    Quantity = x.Quantity, SingleFinalPrice = x.SingleFinalPrice, SinglePrice = x.SinglePrice, MerchantId = x.MerchantId,
                    OrderDetailStatus = x.OrderDetailStatus }).ToArray();
                collections += calculator.CalculateOrderMoney(details, order.DeliveryFee, order.PaymentMethod,
                    captainEarning: order.CaptainEarning).CashToCollect;
            }
        }
        return new DriverCashPosition { Cash = cash, ReservedForHandover = handovers,
            ReservedForPurchases = purchases, ExpectedCollections = collections, HasUnfinishedAccounting = unfinished };
    }

    public async Task<T> WithDriverLockAsync<T>(Guid driverId, Func<Task<T>> action)
    {
        if (!_accounting.Database.IsRelational()) return await action();
        if (_accounting.Database.ProviderName?.Contains("MySql", StringComparison.OrdinalIgnoreCase) == true) {
            // A session lock spans App/Orders and Accounting contexts without
            // hiding a committed journal inside a transaction on another context.
            // Purchase recovery relies on the journal committing before final status.
            var connection = _accounting.Database.GetDbConnection();
            var opened = connection.State != ConnectionState.Open;
            if (opened) await _accounting.Database.OpenConnectionAsync();
            var lockName = "jtak_driver_money_" + driverId.ToString("N");
            var acquired = false;
            try {
                using var command = connection.CreateCommand();
                command.Transaction = _accounting.Database.CurrentTransaction?.GetDbTransaction();
                command.CommandText = "SELECT GET_LOCK(@name, 10)";
                var parameter = command.CreateParameter(); parameter.ParameterName = "@name"; parameter.Value = lockName;
                command.Parameters.Add(parameter);
                acquired = Convert.ToInt32(await command.ExecuteScalarAsync()) == 1;
                if (!acquired) throw new InvalidOperationException("توجد عملية مالية أخرى للمندوب. انتظر قليلاً ثم أعد المحاولة.");
                return await action();
            } finally {
                try { if (acquired) {
                    using var command = connection.CreateCommand();
                    command.Transaction = _accounting.Database.CurrentTransaction?.GetDbTransaction();
                    command.CommandText = "SELECT RELEASE_LOCK(@name)";
                    var parameter = command.CreateParameter(); parameter.ParameterName = "@name"; parameter.Value = lockName;
                    command.Parameters.Add(parameter);
                    await command.ExecuteScalarAsync();
                } } catch {
                    // Closing the connection resets its session lock. Do not turn
                    // an already committed financial action into a failed response.
                    await _accounting.Database.CloseConnectionAsync();
                } finally {
                    if (opened && connection.State == ConnectionState.Open)
                        await _accounting.Database.CloseConnectionAsync();
                }
            }
        }
        var owned = _accounting.Database.CurrentTransaction == null;
        await using var transaction = owned
            ? await _accounting.Database.BeginTransactionAsync(IsolationLevel.Serializable) : null;
        var result = await action();
        if (owned) await transaction.CommitAsync();
        return result;
    }
}
