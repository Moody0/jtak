using App.Orders.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Shipping.Services
{
    public class OrderAccountingRetryService : IOrderAccountingRetryService
    {
        private readonly OrdersDbContext _ordersDb;
        private readonly AccountingDbContext _accountingDb;
        private readonly ILedgerService _ledger;
        private readonly ILogger<OrderAccountingRetryService> _logger;

        public OrderAccountingRetryService(
            OrdersDbContext ordersDb,
            AccountingDbContext accountingDb,
            ILedgerService ledger,
            ILogger<OrderAccountingRetryService> logger)
        {
            _ordersDb = ordersDb ?? throw new ArgumentNullException(nameof(ordersDb));
            _accountingDb = accountingDb ?? throw new ArgumentNullException(nameof(accountingDb));
            _ledger = ledger ?? throw new ArgumentNullException(nameof(ledger));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<OrderAccountingRetryResult> RetryPendingAccountingOrdersAsync(int maxBatchSize = 50)
        {
            var result = new OrderAccountingRetryResult();

            var pendingOrders = await _ordersDb.Orders
                .Include(o => o.OrderDetails)
                .Where(o => o.AccountingStatus == OrderAccountingStatus.PendingAccounting)
                .OrderBy(o => o.DeliveredAt ?? o.PurchaseDate ?? o.CreatedDate)
                .Take(maxBatchSize)
                .ToListAsync();

            result.TotalFound = pendingOrders.Count;

            foreach (var order in pendingOrders)
            {
                var success = await RetryOrderAccountingInternalAsync(order);
                if (success)
                {
                    result.Succeeded++;
                    result.SucceededOrderIds.Add(order.Id);
                }
                else
                {
                    result.Failed++;
                    result.FailedOrderIds.Add(order.Id);
                }
            }

            return result;
        }

        public async Task<bool> RetryOrderAccountingAsync(int orderId)
        {
            var order = await _ordersDb.Orders
                .Include(o => o.OrderDetails)
                .FirstOrDefaultAsync(o => o.Id == orderId);

            if (order == null) return false;
            return await RetryOrderAccountingInternalAsync(order);
        }

        private async Task<bool> RetryOrderAccountingInternalAsync(Order order)
        {
            try
            {
                var bills = await _accountingDb.Bills
                    .Where(b => b.OrderId == order.Id)
                    .ToListAsync();

                if (!bills.Any())
                {
                    _logger.LogWarning("No bills found for pending accounting Order #{OrderId}. Cannot post split.", order.Id);
                    order.AccountingLastError = "No bills found for order.";
                    order.AccountingRetryCount++;
                    await _ordersDb.SaveChangesAsync();
                    return false;
                }

                var merchantSplits = bills.Select(b => new MerchantSplitItem
                {
                    MerchantId = b.MerchantId,
                    MerchantTitle = $"Merchant #{b.MerchantId}",
                    TotalAmount = b.TotalAmount,
                    MerchantAmount = b.MerchantAmount,
                    PlatformCommission = b.JTakAmount,
                    IsPlatformOwned = order.OrderDetails.Any(d =>
                        d.MerchantId == b.MerchantId && d.IsPlatformOwnedSnapshot),
                    CaptainEarningAmount = 0m
                }).ToList();

                var isCod = order.PaymentMethod == PaymentMethod.PayOnDelivery;

                var splitReq = new OrderDeliveredSplitRequest
                {
                    OrderId = order.Id,
                    CaptainUserId = order.DeliveryId ?? Guid.Empty,
                    CaptainName = order.DeliveryUser,
                    DeliveryFee = order.DeliveryFee,
                    DeliveryFeeIsPlatformRevenue = true,
                    CaptainEarning = order.CaptainEarning,
                    ActualCashCollected = order.ActualCashCollected,
                    TotalsIncludeDeliveryFee = false,
                    Currency = "SYP",
                    IsCod = isCod,
                    MerchantSplits = merchantSplits
                };

                await _ledger.PostOrderDeliveredSplitAsync(splitReq);

                foreach (var b in bills)
                {
                    b.IsAddedToDues = true;
                }
                await _accountingDb.SaveChangesAsync();

                order.AccountingStatus = OrderAccountingStatus.Posted;
                order.AccountingPostedAt = DateTime.UtcNow;
                order.AccountingLastError = null;
                await _ordersDb.SaveChangesAsync();

                _logger.LogInformation("Successfully posted retry accounting for delivered Order #{OrderId}", order.Id);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Retry accounting failed for delivered Order #{OrderId}: {Error}", order.Id, ex.Message);
                order.AccountingStatus = OrderAccountingStatus.PendingAccounting;
                order.AccountingLastError = ex.Message;
                order.AccountingRetryCount++;
                await _ordersDb.SaveChangesAsync();
                return false;
            }
        }
    }
}
