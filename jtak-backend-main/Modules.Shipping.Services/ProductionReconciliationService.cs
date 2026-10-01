using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shipping.Data;
using App.Shared.Services.Pricing;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;

namespace Modules.Accounting.Services
{
    public class ProductionReconciliationService : IProductionReconciliationService
    {
        private readonly AccountingDbContext _accountingDb;
        private readonly OrdersDbContext _ordersDb;
        private readonly CatalogDbContext _catalogDb;
        private readonly ShippingDbContext _shippingDb;
        private readonly ILedgerService _ledgerService;
        private readonly IInventoryBatchService _batchService;
        private readonly IOrderMoneyCalculationService _moneyCalculationService;
        private readonly ILogger<ProductionReconciliationService> _logger;

        public ProductionReconciliationService(
            AccountingDbContext accountingDb,
            OrdersDbContext ordersDb,
            CatalogDbContext catalogDb,
            ShippingDbContext shippingDb,
            ILedgerService ledgerService,
            IInventoryBatchService batchService,
            IOrderMoneyCalculationService moneyCalculationService,
            ILogger<ProductionReconciliationService> logger)
        {
            _accountingDb = accountingDb ?? throw new ArgumentNullException(nameof(accountingDb));
            _ordersDb = ordersDb ?? throw new ArgumentNullException(nameof(ordersDb));
            _catalogDb = catalogDb ?? throw new ArgumentNullException(nameof(catalogDb));
            _shippingDb = shippingDb;
            _ledgerService = ledgerService ?? throw new ArgumentNullException(nameof(ledgerService));
            _batchService = batchService;
            _moneyCalculationService = moneyCalculationService;
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        #region 1. Read-Only Discovery Engine

        public async Task<ReconciliationDiscoveryReportDto> RunDiscoveryAsync(ReconciliationDiscoveryOptions options = null)
        {
            options ??= new ReconciliationDiscoveryOptions();
            var issuesToScan = options.IssuesToScan != null && options.IssuesToScan.Count > 0
                ? options.IssuesToScan.ToHashSet()
                : Enum.GetValues(typeof(ReconciliationIssueType)).Cast<ReconciliationIssueType>().ToHashSet();

            var report = new ReconciliationDiscoveryReportDto();

            // 1. Delivery fee stored vs billing/ledger amounts
            if (issuesToScan.Contains(ReconciliationIssueType.DeliveryFeeMismatch))
            {
                await ScanDeliveryFeeDiscrepanciesAsync(report, options);
            }

            // 2. Delivered orders missing an OrderDelivered ledger transaction
            if (issuesToScan.Contains(ReconciliationIssueType.MissingDeliveredLedgerTransaction))
            {
                await ScanMissingDeliveredLedgerTransactionsAsync(report, options);
            }

            // 3. Delivered orders whose ledger transaction does not balance
            if (issuesToScan.Contains(ReconciliationIssueType.UnbalancedLedgerTransaction))
            {
                await ScanUnbalancedLedgerTransactionsAsync(report, options);
            }

            // 4. Driver cash balances that do not equal unsettled COD custody
            if (issuesToScan.Contains(ReconciliationIssueType.DriverCashCustodyMismatch))
            {
                await ScanDriverCashCustodyDiscrepanciesAsync(report, options);
            }

            // 5. Orders whose displayed price used compare-at pricing rather than final sale pricing
            if (issuesToScan.Contains(ReconciliationIssueType.CompareAtPricingMismatch))
            {
                await ScanCompareAtPricingDiscrepanciesAsync(report, options);
            }

            // 6. Orders with zero captain earnings where an earning should have been paid
            if (issuesToScan.Contains(ReconciliationIssueType.ZeroCaptainEarnings))
            {
                await ScanZeroCaptainEarningsAsync(report, options);
            }

            // 7. Canceled orders with deducted but unrestored inventory
            if (issuesToScan.Contains(ReconciliationIssueType.CanceledOrderUnrestoredInventory))
            {
                await ScanCanceledOrderInventoryAsync(report, options);
            }

            // 8. Duplicate orders from the same customer/cart/request window
            if (issuesToScan.Contains(ReconciliationIssueType.DuplicateOrder))
            {
                await ScanDuplicateOrdersAsync(report, options);
            }

            // 9. Duplicate driver assignments or shipping stops
            if (issuesToScan.Contains(ReconciliationIssueType.DuplicateDriverAssignment))
            {
                await ScanDuplicateDriverAssignmentsAsync(report, options);
            }

            // 10. Merchant sales reported in a period different from delivery/recognition time
            if (issuesToScan.Contains(ReconciliationIssueType.PeriodMismatchSales))
            {
                await ScanPeriodMismatchSalesAsync(report, options);
            }

            // Aggregate counts
            report.IssueCounts[nameof(ReconciliationIssueType.DeliveryFeeMismatch)] = report.DeliveryFeeDiscrepancies.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.MissingDeliveredLedgerTransaction)] = report.MissingDeliveredLedgerTransactions.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.UnbalancedLedgerTransaction)] = report.UnbalancedLedgerTransactions.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.DriverCashCustodyMismatch)] = report.DriverCashCustodyDiscrepancies.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.CompareAtPricingMismatch)] = report.CompareAtPricingDiscrepancies.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.ZeroCaptainEarnings)] = report.ZeroCaptainEarningsDiscrepancies.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.CanceledOrderUnrestoredInventory)] = report.CanceledOrdersUnrestoredInventory.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.DuplicateOrder)] = report.DuplicateOrders.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.DuplicateDriverAssignment)] = report.DuplicateDriverAssignments.Count;
            report.IssueCounts[nameof(ReconciliationIssueType.PeriodMismatchSales)] = report.PeriodMismatchSales.Count;

            report.TotalIssuesDiscovered = report.IssueCounts.Values.Sum();
            report.EstimatedNetFinancialAdjustment =
                report.DeliveryFeeDiscrepancies.Sum(x => Math.Abs(x.Variance)) +
                report.MissingDeliveredLedgerTransactions.Sum(x => Math.Abs(x.Variance)) +
                report.UnbalancedLedgerTransactions.Sum(x => Math.Abs(x.Variance)) +
                report.DriverCashCustodyDiscrepancies.Sum(x => Math.Abs(x.Variance)) +
                report.CompareAtPricingDiscrepancies.Sum(x => Math.Abs(x.Variance)) +
                report.ZeroCaptainEarningsDiscrepancies.Sum(x => Math.Abs(x.Variance));

            return report;
        }

        private async Task ScanDeliveryFeeDiscrepanciesAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var query = _ordersDb.Orders
                .AsNoTracking()
                .Where(o => o.DeliveredAt != null);

            if (options.FromDate.HasValue) query = query.Where(o => o.DeliveredAt >= options.FromDate.Value);
            if (options.ToDate.HasValue) query = query.Where(o => o.DeliveredAt <= options.ToDate.Value);

            var deliveredOrders = await query.Take(options.MaxResultsPerIssue).ToListAsync();
            var orderIds = deliveredOrders.Select(o => o.Id).ToList();

            var expectedKeys = orderIds.Select(id => $"OrderDelivered-{id}").ToList();
            var transactions = await _accountingDb.JournalTransactions
                .AsNoTracking()
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .Where(t => expectedKeys.Contains(t.IdempotencyKey))
                .ToListAsync();
            var transactionByKey = transactions.ToDictionary(t => t.IdempotencyKey);

            foreach (var order in deliveredOrders)
            {
                if (!transactionByKey.TryGetValue($"OrderDelivered-{order.Id}", out var transaction))
                {
                    // Missing postings are reported by the dedicated missing-ledger scan.
                    continue;
                }

                var ledgerDeliveryFee = transaction.Entries
                    .Where(e => e.Account != null &&
                        (e.Account.AccountCode == SystemAccountCodes.PlatformDeliveryFeeRevenue ||
                         (order.DeliveryId.HasValue &&
                          e.Account.OwnerUserId == order.DeliveryId &&
                          e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix))))
                    .Sum(e => e.Credit - e.Debit);
                if (Math.Abs(order.DeliveryFee - ledgerDeliveryFee) > 0.01m)
                {
                    report.DeliveryFeeDiscrepancies.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.DeliveryFeeMismatch,
                        OrderId = order.Id,
                        UserId = order.DeliveryId,
                        EntityType = "Order",
                        EntityId = order.Id.ToString(),
                        Description = $"Order #{order.Id} delivery fee ({order.DeliveryFee:N0} SYP) differs from the amount posted to courier/platform delivery accounts ({ledgerDeliveryFee:N0} SYP).",
                        CurrentValue = ledgerDeliveryFee,
                        ExpectedValue = order.DeliveryFee,
                        Variance = ledgerDeliveryFee - order.DeliveryFee,
                        BeforeSnapshot = new { order.Id, order.DeliveryFee, LedgerDeliveryFee = ledgerDeliveryFee, transaction.TransactionNumber },
                        ProposedCorrection = new { Action = "ManualFinancialReview", OrderId = order.Id }
                    });
                }
            }
        }

        private async Task ScanMissingDeliveredLedgerTransactionsAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var query = _ordersDb.Orders
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveredAt != null && o.AccountingStatus != OrderAccountingStatus.Posted);

            if (options.FromDate.HasValue) query = query.Where(o => o.DeliveredAt >= options.FromDate.Value);
            if (options.ToDate.HasValue) query = query.Where(o => o.DeliveredAt <= options.ToDate.Value);

            var deliveredOrders = await query.Take(options.MaxResultsPerIssue).ToListAsync();
            var orderIds = deliveredOrders.Select(o => o.Id).ToList();

            var expectedKeys = orderIds.Select(id => $"OrderDelivered-{id}").ToList();
            var existingTxns = await _accountingDb.JournalTransactions
                .AsNoTracking()
                .Where(t => expectedKeys.Contains(t.IdempotencyKey))
                .Select(t => t.IdempotencyKey)
                .ToListAsync();

            var existingKeySet = new HashSet<string>(existingTxns);

            foreach (var order in deliveredOrders)
            {
                var expectedKey = $"OrderDelivered-{order.Id}";
                if (!existingKeySet.Contains(expectedKey))
                {
                    var expectedTotal = CalculateOrderGrandTotal(order);
                    report.MissingDeliveredLedgerTransactions.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.MissingDeliveredLedgerTransaction,
                        OrderId = order.Id,
                        UserId = order.DeliveryId,
                        EntityType = "Order",
                        EntityId = order.Id.ToString(),
                        Description = $"Delivered Order #{order.Id} is missing an OrderDelivered ledger transaction ({expectedKey}).",
                        CurrentValue = 0m,
                        ExpectedValue = expectedTotal,
                        Variance = expectedTotal,
                        BeforeSnapshot = new { order.Id, order.DeliveredAt, GrandTotal = expectedTotal, Status = order.OrderStatus.ToString(), order.AccountingStatus },
                        ProposedCorrection = new { Action = "PostMissingDeliveredSplit", IdempotencyKey = expectedKey, OrderId = order.Id }
                    });
                }
            }
        }

        private async Task ScanUnbalancedLedgerTransactionsAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var query = _accountingDb.JournalTransactions
                .AsNoTracking()
                .Include(t => t.Entries)
                .AsQueryable();

            if (options.FromDate.HasValue) query = query.Where(t => t.CreatedDate >= options.FromDate.Value);
            if (options.ToDate.HasValue) query = query.Where(t => t.CreatedDate <= options.ToDate.Value);

            var transactions = await query.Take(options.MaxResultsPerIssue).ToListAsync();

            foreach (var txn in transactions)
            {
                var totalDebit = txn.Entries.Sum(e => e.Debit);
                var totalCredit = txn.Entries.Sum(e => e.Credit);
                var variance = totalDebit - totalCredit;

                if (Math.Abs(variance) > 0.01m)
                {
                    int? orderId = null;
                    if (int.TryParse(txn.ReferenceId, out var parsedId)) orderId = parsedId;

                    report.UnbalancedLedgerTransactions.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.UnbalancedLedgerTransaction,
                        OrderId = orderId,
                        EntityType = "JournalTransaction",
                        EntityId = txn.Id.ToString(),
                        Description = $"Journal Transaction #{txn.TransactionNumber} ({txn.IdempotencyKey}) is unbalanced: Debits={totalDebit:N2}, Credits={totalCredit:N2}, Variance={variance:N2}.",
                        CurrentValue = totalDebit,
                        ExpectedValue = totalCredit,
                        Variance = variance,
                        BeforeSnapshot = new { txn.Id, txn.TransactionNumber, txn.IdempotencyKey, TotalDebit = totalDebit, TotalCredit = totalCredit },
                        ProposedCorrection = new { Action = "BalanceAdjustmentEntry", Variance = variance, BalancingAccount = variance > 0 ? SystemAccountCodes.CashOverageRevenue : SystemAccountCodes.CashShortageExpense }
                    });
                }
            }
        }

        private async Task ScanDriverCashCustodyDiscrepanciesAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var floatAccounts = await _accountingDb.Accounts
                .AsNoTracking()
                .Where(a => a.Type == AccountType.Asset && a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix) && a.OwnerUserId.HasValue)
                .ToListAsync();

            foreach (var acc in floatAccounts)
            {
                var driverId = acc.OwnerUserId.Value;
                var currentFloat = await _ledgerService.GetAccountBalanceAsync(acc.Id);

                // Find last completed settlement batch for driver
                var lastBatch = await _accountingDb.DailySettlementBatches
                    .AsNoTracking()
                    .Where(b => b.CaptainUserId == driverId)
                    .OrderByDescending(b => b.BatchDate)
                    .FirstOrDefaultAsync();

                var batchCutoff = lastBatch?.BatchDate ?? DateTime.MinValue;

                // Sum delivered COD orders for this driver since last batch
                var deliveredCodOrders = await _ordersDb.Orders
                    .AsNoTracking()
                    .Include(o => o.OrderDetails)
                    .Where(o => o.DeliveryId == driverId && o.DeliveredAt != null && o.DeliveredAt > batchCutoff && o.PaymentMethod == PaymentMethod.PayOnDelivery)
                    .ToListAsync();

                decimal expectedCodCustody = deliveredCodOrders.Sum(o => o.ActualCashCollected.HasValue && o.ActualCashCollected.Value > 0 ? o.ActualCashCollected.Value : CalculateOrderGrandTotal(o));

                var variance = currentFloat - expectedCodCustody;
                if (Math.Abs(variance) > 0.01m)
                {
                    report.DriverCashCustodyDiscrepancies.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.DriverCashCustodyMismatch,
                        UserId = driverId,
                        EntityType = "Account",
                        EntityId = acc.Id.ToString(),
                        Description = $"Captain {driverId} ledger cash float ({currentFloat:N2} SYP) differs from unsettled COD custody ({expectedCodCustody:N2} SYP). Variance: {variance:N2} SYP.",
                        CurrentValue = currentFloat,
                        ExpectedValue = expectedCodCustody,
                        Variance = variance,
                        BeforeSnapshot = new { AccountId = acc.Id, acc.AccountCode, CurrentFloat = currentFloat, ExpectedCodCustody = expectedCodCustody, LastBatchDate = lastBatch?.BatchDate },
                        ProposedCorrection = new { Action = "RealignCashFloat", Discrepancy = variance }
                    });
                }
            }
        }

        private async Task ScanCompareAtPricingDiscrepanciesAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var query = _ordersDb.Orders
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveredAt != null &&
                            o.PaymentMethod == PaymentMethod.PayOnDelivery &&
                            o.ActualCashCollected.HasValue &&
                            o.OrderDetails.Any(d => d.SinglePrice > d.SingleFinalPrice));

            if (options.FromDate.HasValue) query = query.Where(o => o.PurchaseDate >= options.FromDate.Value);
            if (options.ToDate.HasValue) query = query.Where(o => o.PurchaseDate <= options.ToDate.Value);

            var ordersWithDiscounts = await query.Take(options.MaxResultsPerIssue).ToListAsync();

            foreach (var order in ordersWithDiscounts)
            {
                var compareAtSubtotal = order.OrderDetails.Sum(d => d.Quantity * d.SinglePrice);
                var actualSaleSubtotal = order.OrderDetails.Sum(d => d.Quantity * d.SingleFinalPrice);
                var expectedCollected = actualSaleSubtotal + order.DeliveryFee;
                var overcharge = order.ActualCashCollected.Value - expectedCollected;

                if (overcharge > 0.01m)
                {
                    report.CompareAtPricingDiscrepancies.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.CompareAtPricingMismatch,
                        OrderId = order.Id,
                        UserId = order.UserId,
                        EntityType = "Order",
                        EntityId = order.Id.ToString(),
                        Description = $"Order #{order.Id} collected {order.ActualCashCollected.Value:N2} SYP while the final sale total plus delivery was {expectedCollected:N2} SYP. Potential overcharge: {overcharge:N2} SYP.",
                        CurrentValue = order.ActualCashCollected.Value,
                        ExpectedValue = expectedCollected,
                        Variance = overcharge,
                        BeforeSnapshot = new { order.Id, CompareAtSubtotal = compareAtSubtotal, ActualSaleSubtotal = actualSaleSubtotal, order.DeliveryFee, order.ActualCashCollected },
                        ProposedCorrection = new { Action = "ManualCustomerRefundReview", RefundAmount = overcharge }
                    });
                }
            }
        }

        private async Task ScanZeroCaptainEarningsAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var query = _ordersDb.Orders
                .AsNoTracking()
                .Where(o => o.DeliveredAt != null &&
                            o.DeliveryId.HasValue &&
                            o.DeliveryId.Value != Guid.Empty &&
                            o.MoneySnapshotVersion > 0 &&
                            o.CaptainEarning > 0);

            if (options.FromDate.HasValue) query = query.Where(o => o.DeliveredAt >= options.FromDate.Value);
            if (options.ToDate.HasValue) query = query.Where(o => o.DeliveredAt <= options.ToDate.Value);

            var deliveredOrders = await query.Take(options.MaxResultsPerIssue).ToListAsync();
            var orderIds = deliveredOrders.Select(o => o.Id).ToList();

            var expectedKeys = orderIds.Select(id => $"OrderDelivered-{id}").ToList();
            var transactions = await _accountingDb.JournalTransactions
                .AsNoTracking()
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .Where(t => expectedKeys.Contains(t.IdempotencyKey))
                .ToListAsync();
            var transactionByKey = transactions.ToDictionary(t => t.IdempotencyKey);

            foreach (var order in deliveredOrders)
            {
                transactionByKey.TryGetValue($"OrderDelivered-{order.Id}", out var transaction);
                var courierEarning = transaction?.Entries
                    .Where(e => e.Account != null &&
                                e.Account.OwnerUserId == order.DeliveryId &&
                                e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix))
                    .Sum(e => e.Credit - e.Debit) ?? 0m;
                if (courierEarning + 0.01m < order.CaptainEarning)
                {
                    report.ZeroCaptainEarningsDiscrepancies.Add(new DiscrepancyItemDto
                    {
                        IssueType = ReconciliationIssueType.ZeroCaptainEarnings,
                        OrderId = order.Id,
                        UserId = order.DeliveryId,
                        EntityType = "Order",
                        EntityId = order.Id.ToString(),
                        Description = $"Order #{order.Id} expected courier earning {order.CaptainEarning:N0} SYP but posted {courierEarning:N0} SYP.",
                        CurrentValue = courierEarning,
                        ExpectedValue = order.CaptainEarning,
                        Variance = courierEarning - order.CaptainEarning,
                        BeforeSnapshot = new { order.Id, order.DeliveryId, order.DeliveryFee, order.CaptainEarning, PostedCourierEarning = courierEarning },
                        ProposedCorrection = new { Action = "ManualFinancialReview", CaptainUserId = order.DeliveryId, MissingAmount = order.CaptainEarning - courierEarning }
                    });
                }
            }
        }

        private async Task ScanCanceledOrderInventoryAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var canceledOrders = await _ordersDb.Orders
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.OrderDetails.Any(d => d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled || d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled || d.OrderDetailStatus == OrderDetailStatus.MerchantRejected))
                .Take(options.MaxResultsPerIssue)
                .ToListAsync();

            foreach (var order in canceledOrders)
            {
                foreach (var detail in order.OrderDetails.Where(d => d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled || d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled || d.OrderDetailStatus == OrderDetailStatus.MerchantRejected))
                {
                    var movements = await _catalogDb.InventoryMovements
                        .AsNoTracking()
                        .Where(m => m.OrderId == order.Id && m.OrderDetailId == detail.Id)
                        .ToListAsync();

                    var reserveCount = movements.Count(m => m.MovementType == InventoryMovementType.Reserve);
                    var releaseCount = movements.Count(m => m.MovementType == InventoryMovementType.Release);
                    var deductionCount = movements.Count(m => m.MovementType == InventoryMovementType.Deduction);
                    var returnCount = movements.Count(m => m.MovementType == InventoryMovementType.Return);

                    bool hasUnreleasedReservation = reserveCount > releaseCount && deductionCount == 0;
                    bool hasUnrestoredDeduction = deductionCount > returnCount;

                    if (hasUnreleasedReservation || hasUnrestoredDeduction)
                    {
                        report.CanceledOrdersUnrestoredInventory.Add(new DiscrepancyItemDto
                        {
                            IssueType = ReconciliationIssueType.CanceledOrderUnrestoredInventory,
                            OrderId = order.Id,
                            EntityType = "OrderDetail",
                            EntityId = detail.Id.ToString(),
                            Description = $"Canceled Order #{order.Id} Item #{detail.Id} ({detail.ProductTitle}) has unrestored inventory (Reserves={reserveCount}, Releases={releaseCount}, Deductions={deductionCount}, Returns={returnCount}).",
                            CurrentValue = detail.Quantity,
                            ExpectedValue = 0m,
                            Variance = detail.Quantity,
                            BeforeSnapshot = new { order.Id, DetailId = detail.Id, detail.ProductTitle, detail.Quantity, Status = detail.OrderDetailStatus.ToString(), Reserves = reserveCount, Releases = releaseCount, Deductions = deductionCount, Returns = returnCount },
                            ProposedCorrection = new { Action = hasUnreleasedReservation ? "ReleaseReservation" : "RestockReturnMovement", OrderId = order.Id, OrderDetailId = detail.Id, Quantity = detail.Quantity }
                        });
                    }
                }
            }
        }

        private async Task ScanDuplicateOrdersAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var recentOrders = await _ordersDb.Orders
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.PurchaseDate.HasValue && o.PurchaseDate.Value >= (options.FromDate ?? DateTime.UtcNow.AddDays(-30)))
                .OrderBy(o => o.PurchaseDate)
                .Take(options.MaxResultsPerIssue)
                .ToListAsync();

            var userGroups = recentOrders.GroupBy(o => o.UserId);
            foreach (var group in userGroups)
            {
                var ordersList = group.OrderBy(o => o.PurchaseDate.Value).ToList();
                for (int i = 0; i < ordersList.Count - 1; i++)
                {
                    var o1 = ordersList[i];
                    var o2 = ordersList[i + 1];

                    bool sameWindow = o1.PurchaseDate.HasValue && o2.PurchaseDate.HasValue && Math.Abs((o2.PurchaseDate.Value - o1.PurchaseDate.Value).TotalMinutes) <= 5.0;
                    var o1Total = CalculateOrderGrandTotal(o1);
                    var o2Total = CalculateOrderGrandTotal(o2);
                    bool sameTotal = Math.Abs(o1Total - o2Total) < 0.01m;
                    bool duplicateKey = !string.IsNullOrEmpty(o1.IdempotencyKey) && o1.IdempotencyKey == o2.IdempotencyKey;

                    if ((sameWindow && sameTotal) || duplicateKey)
                    {
                        report.DuplicateOrders.Add(new DiscrepancyItemDto
                        {
                            IssueType = ReconciliationIssueType.DuplicateOrder,
                            OrderId = o2.Id,
                            UserId = group.Key,
                            EntityType = "Order",
                            EntityId = o2.Id.ToString(),
                            Description = $"Duplicate order detected: Order #{o2.Id} placed within {Math.Abs((o2.PurchaseDate.Value - o1.PurchaseDate.Value).TotalMinutes):N1} mins of Order #{o1.Id} with matching total ({o1Total:N0} SYP).",
                            CurrentValue = o2Total,
                            ExpectedValue = 0m,
                            Variance = o2Total,
                            BeforeSnapshot = new { PrimaryOrderId = o1.Id, DuplicateOrderId = o2.Id, PrimaryPurchaseDate = o1.PurchaseDate, DuplicatePurchaseDate = o2.PurchaseDate, OrderTotal = o1Total, o1.IdempotencyKey },
                            ProposedCorrection = new { Action = "FlagDuplicateOrderForReview", PrimaryOrderId = o1.Id, DuplicateOrderId = o2.Id }
                        });
                    }
                }
            }
        }

        private async Task ScanDuplicateDriverAssignmentsAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            if (_shippingDb == null) return;

            var shippingOrders = await _shippingDb.ShippingOrders
                .AsNoTracking()
                .Take(options.MaxResultsPerIssue * 10)
                .ToListAsync();

            var activeShippingOrders = shippingOrders
                .GroupBy(s => s.OrderId)
                .Where(g => g.Select(s => s.DriverId).Distinct().Count() > 1 || g.Count() > g.Select(s => s.Index).Distinct().Count())
                .Take(options.MaxResultsPerIssue)
                .ToList();

            foreach (var group in activeShippingOrders)
            {
                var distinctDrivers = group.Select(s => s.DriverId).Distinct().ToList();
                report.DuplicateDriverAssignments.Add(new DiscrepancyItemDto
                {
                    IssueType = ReconciliationIssueType.DuplicateDriverAssignment,
                    OrderId = group.Key,
                    EntityType = "ShippingOrder",
                    EntityId = group.Key.ToString(),
                    Description = $"Order #{group.Key} has contradictory driver stops assigned to {distinctDrivers.Count} distinct couriers.",
                    CurrentValue = distinctDrivers.Count,
                    ExpectedValue = 1m,
                    Variance = distinctDrivers.Count - 1,
                    BeforeSnapshot = new { OrderId = group.Key, Drivers = distinctDrivers, StopsCount = group.Count() },
                    ProposedCorrection = new { Action = "ConsolidateDriverStops", OrderId = group.Key }
                });
            }
        }

        private async Task ScanPeriodMismatchSalesAsync(ReconciliationDiscoveryReportDto report, ReconciliationDiscoveryOptions options)
        {
            var deliveredOrders = await _ordersDb.Orders
                .AsNoTracking()
                .Where(o => o.DeliveredAt != null)
                .Take(options.MaxResultsPerIssue)
                .ToListAsync();

            var orderIds = deliveredOrders.Select(o => o.Id).ToList();
            var bills = await _accountingDb.Bills
                .AsNoTracking()
                .Where(b => orderIds.Contains(b.OrderId))
                .ToListAsync();

            var billMap = bills.GroupBy(b => b.OrderId).ToDictionary(g => g.Key, g => g.First());

            foreach (var order in deliveredOrders)
            {
                if (billMap.TryGetValue(order.Id, out var bill) && order.DeliveredAt.HasValue)
                {
                    var deliveryDate = order.DeliveredAt.Value;
                    var billDate = bill.CreatedDate;

                    if (deliveryDate.Year != billDate.Year || deliveryDate.Month != billDate.Month)
                    {
                        report.PeriodMismatchSales.Add(new DiscrepancyItemDto
                        {
                            IssueType = ReconciliationIssueType.PeriodMismatchSales,
                            OrderId = order.Id,
                            MerchantId = bill.MerchantId,
                            EntityType = "Bill",
                            EntityId = bill.Id.ToString(),
                            Description = $"Order #{order.Id} physically delivered on {deliveryDate:yyyy-MM-dd} but recognized in billing on {billDate:yyyy-MM-dd} (crosses calendar month boundary).",
                            CurrentValue = bill.TotalAmount,
                            ExpectedValue = bill.TotalAmount,
                            Variance = 0m,
                            BeforeSnapshot = new { order.Id, BillId = bill.Id, DeliveryDate = deliveryDate, BillDate = billDate, bill.TotalAmount },
                            ProposedCorrection = new { Action = "AdjustSalesPeriodRecognition", OrderId = order.Id, RecognizedPeriod = $"{deliveryDate:yyyy-MM}" }
                        });
                    }
                }
            }
        }

        #endregion

        #region 2. Staging Engine

        public async Task<ReconciliationBatchDto> StageCorrectionsAsync(StageCorrectionsRequest request, string operatorName)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));

            // Never trust discrepancy amounts supplied by an HTTP client. Run
            // discovery again against current persisted state and stage only
            // server-derived findings.
            var discovery = await RunDiscoveryAsync(request.DiscoveryOptions);
            var discrepancies = discovery.DeliveryFeeDiscrepancies
                .Concat(discovery.MissingDeliveredLedgerTransactions)
                .Concat(discovery.UnbalancedLedgerTransactions)
                .Concat(discovery.DriverCashCustodyDiscrepancies)
                .Concat(discovery.CompareAtPricingDiscrepancies)
                .Concat(discovery.ZeroCaptainEarningsDiscrepancies)
                .Concat(discovery.CanceledOrdersUnrestoredInventory)
                .Concat(discovery.DuplicateOrders)
                .Concat(discovery.DuplicateDriverAssignments)
                .Concat(discovery.PeriodMismatchSales)
                .ToList();

            var batchNumber = $"RECON-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString().Substring(0, 8).ToUpper()}";

            var batch = new ReconciliationBatch
            {
                BatchNumber = batchNumber,
                Operator = operatorName ?? "Admin",
                Reason = request.Reason ?? "Production Data Reconciliation Run",
                SourceSnapshotManifest = request.SourceSnapshotManifest,
                Status = ReconciliationBatchStatus.Staged,
                TotalIssuesDiscovered = discrepancies.Count,
                TotalStagedCorrections = discrepancies.Count,
                TotalAppliedCorrections = 0,
                TotalFailedCorrections = 0,
                TotalFinancialAdjustmentDebit = 0m,
                TotalFinancialAdjustmentCredit = 0m
            };

            foreach (var d in discrepancies)
            {
                var adjustmentAmount = Math.Abs(d.Variance);
                var correction = new ReconciliationStagedCorrection
                {
                    BatchId = batch.Id,
                    Batch = batch,
                    IssueType = d.IssueType,
                    OrderId = d.OrderId,
                    UserId = d.UserId,
                    MerchantId = d.MerchantId,
                    TargetEntityType = d.EntityType ?? "Order",
                    TargetEntityId = d.EntityId ?? d.OrderId?.ToString(),
                    BeforeStateJson = d.BeforeSnapshot != null ? JsonSerializer.Serialize(d.BeforeSnapshot) : null,
                    ProposedAfterStateJson = d.ProposedCorrection != null ? JsonSerializer.Serialize(d.ProposedCorrection) : null,
                    AdjustmentAmount = adjustmentAmount,
                    Currency = d.Currency ?? "SYP",
                    Justification = d.Description,
                    Status = StagedCorrectionStatus.PendingReview
                };

                batch.StagedCorrections.Add(correction);
                batch.TotalFinancialAdjustmentDebit += adjustmentAmount;
                batch.TotalFinancialAdjustmentCredit += adjustmentAmount;
            }

            await _accountingDb.ReconciliationBatches.AddAsync(batch);
            await _accountingDb.SaveChangesAsync();

            _logger.LogInformation("Staged reconciliation batch {BatchNumber} with {Count} corrections.", batch.BatchNumber, batch.StagedCorrections.Count);

            return MapToBatchDto(batch);
        }

        #endregion

        #region 3. Approval Engine

        public async Task<ReconciliationBatchDto> ApproveBatchAsync(Guid batchId, string approverName, string approvalNotes = null)
        {
            var batch = await _accountingDb.ReconciliationBatches
                .Include(b => b.StagedCorrections)
                .FirstOrDefaultAsync(b => b.Id == batchId);

            if (batch == null)
            {
                throw new InvalidOperationException($"Reconciliation batch {batchId} was not found.");
            }

            if (batch.Status != ReconciliationBatchStatus.Staged)
            {
                throw new InvalidOperationException($"Cannot approve batch {batch.BatchNumber} because its current status is {batch.Status}. Only Staged batches can be approved.");
            }

            batch.Status = ReconciliationBatchStatus.Approved;
            batch.ApprovedAt = DateTime.UtcNow;
            batch.ApprovedBy = approverName ?? "Finance Admin";
            batch.ApprovalNotes = approvalNotes;

            foreach (var corr in batch.StagedCorrections)
            {
                if (corr.Status == StagedCorrectionStatus.PendingReview)
                {
                    corr.Status = StagedCorrectionStatus.Approved;
                }
            }

            await _accountingDb.SaveChangesAsync();
            _logger.LogInformation("Reconciliation batch {BatchNumber} approved by {Approver}.", batch.BatchNumber, batch.ApprovedBy);

            return MapToBatchDto(batch);
        }

        #endregion

        #region 4. Repair Execution Engine (Idempotent & Immutable)

        public async Task<ReconciliationBatchExecutionResultDto> ExecuteRepairsAsync(Guid batchId, string operatorName)
        {
            var batch = await _accountingDb.ReconciliationBatches
                .Include(b => b.StagedCorrections)
                .FirstOrDefaultAsync(b => b.Id == batchId);

            if (batch == null)
            {
                throw new InvalidOperationException($"Reconciliation batch {batchId} was not found.");
            }

            // IDEMPOTENCY GUARD: If already completed, return existing result without re-executing
            if (batch.Status == ReconciliationBatchStatus.Completed)
            {
                _logger.LogWarning("Reconciliation batch {BatchNumber} is already completed. Returning existing results (Idempotent).", batch.BatchNumber);
                return new ReconciliationBatchExecutionResultDto
                {
                    BatchId = batch.Id,
                    BatchNumber = batch.BatchNumber,
                    Status = batch.Status,
                    AppliedCount = batch.TotalAppliedCorrections,
                    FailedCount = batch.TotalFailedCorrections,
                    SkippedCount = batch.StagedCorrections.Count(c => c.Status == StagedCorrectionStatus.Skipped)
                };
            }

            if (batch.Status != ReconciliationBatchStatus.Approved)
            {
                throw new InvalidOperationException($"Cannot execute batch {batch.BatchNumber} with status {batch.Status}. Batch must be Approved by Finance prior to execution.");
            }

            batch.Status = ReconciliationBatchStatus.Executing;
            batch.ExecutedAt = DateTime.UtcNow;
            batch.ExecutedBy = operatorName ?? "Admin";

            var result = new ReconciliationBatchExecutionResultDto
            {
                BatchId = batch.Id,
                BatchNumber = batch.BatchNumber
            };

            foreach (var correction in batch.StagedCorrections.Where(c => c.Status == StagedCorrectionStatus.Approved || c.Status == StagedCorrectionStatus.PendingReview))
            {
                try
                {
                    var idempotencyKey = $"ReconFix-{batch.BatchNumber}-{correction.Id}";

                    // Check if already applied
                    var alreadyPosted = await _accountingDb.JournalTransactions
                        .AnyAsync(t => t.IdempotencyKey == idempotencyKey);

                    if (alreadyPosted)
                    {
                        correction.Status = StagedCorrectionStatus.Applied;
                        result.SkippedCount++;
                        continue;
                    }

                    switch (correction.IssueType)
                    {
                        case ReconciliationIssueType.MissingDeliveredLedgerTransaction:
                        case ReconciliationIssueType.DeliveryFeeMismatch:
                        case ReconciliationIssueType.UnbalancedLedgerTransaction:
                        case ReconciliationIssueType.ZeroCaptainEarnings:
                        case ReconciliationIssueType.DriverCashCustodyMismatch:
                            // Financial discrepancies require a domain-specific
                            // replay or a finance-approved journal, not a generic
                            // debit/credit pair inferred from a variance sign.
                            correction.Status = StagedCorrectionStatus.Skipped;
                            correction.FailureReason = "Automatic financial repair is disabled; manual finance review or domain replay is required.";
                            result.SkippedCount++;
                            break;

                        case ReconciliationIssueType.CanceledOrderUnrestoredInventory:
                            await ExecuteInventoryCorrectionAsync(batch, correction, result);
                            break;

                        case ReconciliationIssueType.CompareAtPricingMismatch:
                        case ReconciliationIssueType.DuplicateOrder:
                        case ReconciliationIssueType.DuplicateDriverAssignment:
                        case ReconciliationIssueType.PeriodMismatchSales:
                            correction.Status = StagedCorrectionStatus.Skipped;
                            correction.FailureReason = "Audit-only finding; no automatic data mutation is defined.";
                            result.SkippedCount++;
                            break;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to apply correction {CorrectionId} on batch {BatchNumber}: {Message}", correction.Id, batch.BatchNumber, ex.Message);
                    correction.Status = StagedCorrectionStatus.Failed;
                    correction.FailureReason = ex.Message;
                    result.FailedCount++;
                    result.Errors.Add($"Correction #{correction.Id} ({correction.IssueType}): {ex.Message}");
                }
            }

            batch.TotalAppliedCorrections = batch.StagedCorrections.Count(c => c.Status == StagedCorrectionStatus.Applied);
            batch.TotalFailedCorrections = batch.StagedCorrections.Count(c => c.Status == StagedCorrectionStatus.Failed);
            batch.Status = batch.TotalFailedCorrections == 0 ? ReconciliationBatchStatus.Completed : ReconciliationBatchStatus.Staged;

            await _accountingDb.SaveChangesAsync();

            result.Status = batch.Status;
            result.AppliedCount = batch.TotalAppliedCorrections;
            result.FailedCount = batch.TotalFailedCorrections;

            return result;
        }

        private async Task ExecuteFinancialCorrectionAsync(
            ReconciliationBatch batch,
            ReconciliationStagedCorrection correction,
            string idempotencyKey,
            ReconciliationBatchExecutionResultDto result)
        {
            var amount = correction.AdjustmentAmount;
            if (amount <= 0m)
            {
                correction.Status = StagedCorrectionStatus.Applied;
                correction.AppliedAt = DateTime.UtcNow;
                result.AppliedCount++;
                return;
            }

            // Create balanced double-entry corrective adjustment transaction
            Account debitAccount;
            Account creditAccount;

            if (correction.IssueType == ReconciliationIssueType.ZeroCaptainEarnings && correction.UserId.HasValue)
            {
                // Debit delivery fee revenue (or ops expense), Credit captain earnings liability
                debitAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "Platform Delivery Fee Revenue", AccountType.Revenue);
                creditAccount = await _ledgerService.GetOrCreateUserAccountAsync(correction.UserId.Value, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Captain Earnings");
            }
            else if (correction.IssueType == ReconciliationIssueType.DriverCashCustodyMismatch && correction.UserId.HasValue)
            {
                // Realign float with shortage or overage expense/revenue
                debitAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashShortageExpense, "Cash Shortage Expense", AccountType.Expense);
                creditAccount = await _ledgerService.GetOrCreateUserAccountAsync(correction.UserId.Value, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Captain Cash Float");
            }
            else if (correction.IssueType == ReconciliationIssueType.MissingDeliveredLedgerTransaction && correction.OrderId.HasValue)
            {
                // Create balancing delivery entry
                debitAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Company Main Vault", AccountType.Asset);
                creditAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "Platform Delivery Fee Revenue", AccountType.Revenue);
            }
            else
            {
                // General financial balancing
                debitAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashShortageExpense, "Cash Shortage Expense", AccountType.Expense);
                creditAccount = await _ledgerService.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashOverageRevenue, "Cash Overage Revenue", AccountType.Revenue);
            }

            var txnReq = new PostTransactionRequest
            {
                ReferenceType = "ReconciliationAdjustment",
                ReferenceId = correction.Id.ToString(),
                IdempotencyKey = idempotencyKey,
                Description = $"Corrective adjustment for batch #{batch.BatchNumber}: {correction.Justification}",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new PostLedgerEntryRequest
                    {
                        AccountId = debitAccount.Id,
                        Debit = amount,
                        Credit = 0m,
                        Currency = correction.Currency,
                        Memo = $"Reconciliation #{batch.BatchNumber} Debit"
                    },
                    new PostLedgerEntryRequest
                    {
                        AccountId = creditAccount.Id,
                        Debit = 0m,
                        Credit = amount,
                        Currency = correction.Currency,
                        Memo = $"Reconciliation #{batch.BatchNumber} Credit"
                    }
                }
            };

            var postedTxn = await _ledgerService.PostTransactionAsync(txnReq);

            if (correction.OrderId.HasValue)
            {
                var ord = await _ordersDb.Orders.FirstOrDefaultAsync(o => o.Id == correction.OrderId.Value);
                if (ord != null)
                {
                    ord.AccountingStatus = OrderAccountingStatus.Posted;
                    ord.AccountingPostedAt = DateTime.UtcNow;
                    await _ordersDb.SaveChangesAsync();
                }
            }

            correction.ApplicationResultJournalTxnId = postedTxn.TransactionNumber;
            correction.Status = StagedCorrectionStatus.Applied;
            correction.AppliedAt = DateTime.UtcNow;

            result.CreatedJournalTransactionNumbers.Add(postedTxn.TransactionNumber);
            result.AppliedCount++;
        }

        private async Task ExecuteInventoryCorrectionAsync(
            ReconciliationBatch batch,
            ReconciliationStagedCorrection correction,
            ReconciliationBatchExecutionResultDto result)
        {
            if (correction.OrderId.HasValue && _batchService != null)
            {
                var detailId = int.TryParse(correction.TargetEntityId, out var parsed) ? (int?)parsed : null;
                await _batchService.ReleaseReservationAsync(correction.OrderId.Value, detailId);
            }

            correction.Status = StagedCorrectionStatus.Applied;
            correction.AppliedAt = DateTime.UtcNow;
            result.AppliedCount++;
        }

        #endregion

        #region 5. Query and Lookup Methods

        public async Task<ReconciliationBatchDto> GetBatchAsync(Guid batchId)
        {
            var batch = await _accountingDb.ReconciliationBatches
                .Include(b => b.StagedCorrections)
                .AsNoTracking()
                .FirstOrDefaultAsync(b => b.Id == batchId);

            if (batch == null) return null;
            return MapToBatchDto(batch);
        }

        public async Task<List<ReconciliationBatchSummaryDto>> GetBatchesAsync()
        {
            var batches = await _accountingDb.ReconciliationBatches
                .AsNoTracking()
                .OrderByDescending(b => b.CreatedDate)
                .ToListAsync();

            return batches.Select(b => new ReconciliationBatchSummaryDto
            {
                Id = b.Id,
                BatchNumber = b.BatchNumber,
                Operator = b.Operator,
                Reason = b.Reason,
                SourceSnapshotManifest = b.SourceSnapshotManifest,
                Status = b.Status,
                CreatedAt = b.CreatedDate,
                ApprovedAt = b.ApprovedAt,
                ApprovedBy = b.ApprovedBy,
                ExecutedAt = b.ExecutedAt,
                ExecutedBy = b.ExecutedBy,
                TotalIssuesDiscovered = b.TotalIssuesDiscovered,
                TotalStagedCorrections = b.TotalStagedCorrections,
                TotalAppliedCorrections = b.TotalAppliedCorrections,
                TotalFailedCorrections = b.TotalFailedCorrections,
                TotalFinancialAdjustmentDebit = b.TotalFinancialAdjustmentDebit,
                TotalFinancialAdjustmentCredit = b.TotalFinancialAdjustmentCredit
            }).ToList();
        }

        private static ReconciliationBatchDto MapToBatchDto(ReconciliationBatch batch)
        {
            return new ReconciliationBatchDto
            {
                Id = batch.Id,
                BatchNumber = batch.BatchNumber,
                Operator = batch.Operator,
                Reason = batch.Reason,
                SourceSnapshotManifest = batch.SourceSnapshotManifest,
                Status = batch.Status,
                CreatedAt = batch.CreatedDate,
                ApprovedAt = batch.ApprovedAt,
                ApprovedBy = batch.ApprovedBy,
                ApprovalNotes = batch.ApprovalNotes,
                ExecutedAt = batch.ExecutedAt,
                ExecutedBy = batch.ExecutedBy,
                TotalIssuesDiscovered = batch.TotalIssuesDiscovered,
                TotalStagedCorrections = batch.TotalStagedCorrections,
                TotalAppliedCorrections = batch.TotalAppliedCorrections,
                TotalFailedCorrections = batch.TotalFailedCorrections,
                TotalFinancialAdjustmentDebit = batch.TotalFinancialAdjustmentDebit,
                TotalFinancialAdjustmentCredit = batch.TotalFinancialAdjustmentCredit,
                StagedCorrections = batch.StagedCorrections.Select(c => new ReconciliationStagedCorrectionDto
                {
                    Id = c.Id,
                    BatchId = c.BatchId,
                    IssueType = c.IssueType,
                    OrderId = c.OrderId,
                    UserId = c.UserId,
                    MerchantId = c.MerchantId,
                    TargetEntityType = c.TargetEntityType,
                    TargetEntityId = c.TargetEntityId,
                    BeforeStateJson = c.BeforeStateJson,
                    ProposedAfterStateJson = c.ProposedAfterStateJson,
                    AdjustmentAmount = c.AdjustmentAmount,
                    Currency = c.Currency,
                    Justification = c.Justification,
                    Status = c.Status,
                    ApplicationResultJournalTxnId = c.ApplicationResultJournalTxnId,
                    FailureReason = c.FailureReason,
                    AppliedAt = c.AppliedAt
                }).ToList()
            };
        }

        private static decimal CalculateOrderGrandTotal(Order o)
        {
            if (o == null) return 0m;
            return o.DeliveryFee + (o.OrderDetails?.Sum(d => d.Quantity * d.SingleFinalPrice) ?? 0m);
        }

        private static decimal CalculateOrderSubtotal(Order o)
        {
            if (o == null) return 0m;
            return o.OrderDetails?.Sum(d => d.Quantity * d.SingleFinalPrice) ?? 0m;
        }

        #endregion
    }
}
