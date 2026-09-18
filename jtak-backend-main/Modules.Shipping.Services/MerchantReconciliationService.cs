using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using App.Catalog.Data;
using Modules.Catalog.Entities;
using App.Orders.Data;
using Modules.Orders.Entities;

namespace Modules.Accounting.Services
{
    public class MerchantReconciliationService : IMerchantReconciliationService
    {
        private readonly AccountingDbContext _accountingDb;
        private readonly CatalogDbContext _catalogDb;
        private readonly OrdersDbContext _ordersDb;
        private readonly ILedgerService _ledgerService;
        private readonly ILogger<MerchantReconciliationService> _logger;

        public MerchantReconciliationService(
            AccountingDbContext accountingDb,
            CatalogDbContext catalogDb,
            OrdersDbContext ordersDb,
            ILedgerService ledgerService,
            ILogger<MerchantReconciliationService> logger)
        {
            _accountingDb = accountingDb ?? throw new ArgumentNullException(nameof(accountingDb));
            _catalogDb = catalogDb ?? throw new ArgumentNullException(nameof(catalogDb));
            _ordersDb = ordersDb ?? throw new ArgumentNullException(nameof(ordersDb));
            _ledgerService = ledgerService ?? throw new ArgumentNullException(nameof(ledgerService));
            _logger = logger;
        }

        public async Task<MerchantReconciliationSummaryDto> GetSummaryAsync()
        {
            // 1. Query all active merchants
            var activeMerchants = await _catalogDb.Merchants.AsNoTracking()
                .Where(m => m.DeletionDate == null && m.Active)
                .Select(m => m.Id)
                .ToListAsync();

            // 2. Compute Total Merchant Payables (Liability: Credit - Debit) from ledger
            var vendorAccounts = await _accountingDb.Accounts.AsNoTracking()
                .Where(a => a.OwnerMerchantId != null &&
                            activeMerchants.Contains(a.OwnerMerchantId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix))
                .Select(a => new
                {
                    MerchantId = a.OwnerMerchantId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToListAsync();

            var totalMerchantPayables = vendorAccounts.Sum(x => x.Balance);

            // 3. Compute Total Reserved Settlements (Pending + Approved allocations)
            var reservedAllocations = await _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Include(a => a.SettlementRequest)
                .Where(a => a.SettlementRequest != null &&
                            (a.SettlementRequest.Currency == null || a.SettlementRequest.Currency == "SYP") &&
                            (a.SettlementRequest.Status == SettlementRequestStatus.Pending ||
                             a.SettlementRequest.Status == SettlementRequestStatus.Approved))
                .SumAsync(a => (decimal?)a.Amount) ?? 0m;

            // 4. Compute Total Completed Settlements
            var completedAllocations = await _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Include(a => a.SettlementRequest)
                .Where(a => a.SettlementRequest != null &&
                            (a.SettlementRequest.Currency == null || a.SettlementRequest.Currency == "SYP") &&
                            a.SettlementRequest.Status == SettlementRequestStatus.Completed)
                .SumAsync(a => (decimal?)a.Amount) ?? 0m;

            // 5. Compute Total JTAK Commission Revenue
            var commissionAccounts = await _accountingDb.Accounts.AsNoTracking()
                .Where(a => a.AccountCode == SystemAccountCodes.PlatformCommissionRevenue ||
                            a.AccountCode.StartsWith("4010-REV-COMM"))
                .Select(a => a.LedgerEntries.Sum(e => e.Credit - e.Debit))
                .ToListAsync();

            var totalJTakCommission = commissionAccounts.Sum();

            // 6. Pending Requests Count
            var pendingRequestsCount = await _accountingDb.SettlementRequests.AsNoTracking()
                .CountAsync(r => r.PartyType == SettlementPartyType.Merchant && r.Status == SettlementRequestStatus.Pending);

            return new MerchantReconciliationSummaryDto
            {
                TotalMerchantPayables = totalMerchantPayables,
                TotalReservedSettlements = reservedAllocations,
                TotalAvailableForSettlement = Math.Max(0m, totalMerchantPayables - reservedAllocations),
                TotalJTakCommission = totalJTakCommission,
                TotalCompletedSettlements = completedAllocations,
                ActiveMerchantsCount = activeMerchants.Count,
                PendingRequestsCount = pendingRequestsCount,
                Currency = "SYP"
            };
        }

        public async Task<MerchantReconciliationDataTableResultDto> GetDataTableAsync(MerchantReconciliationDataTableRequest request)
        {
            if (request == null) request = new MerchantReconciliationDataTableRequest();
            if (request.Page < 1) request.Page = 1;
            if (request.PageSize < 1) request.PageSize = 10;

            var query = _catalogDb.Merchants.AsNoTracking()
                .Where(m => m.DeletionDate == null && m.Active);

            if (!string.IsNullOrWhiteSpace(request.SearchTerm))
            {
                var term = request.SearchTerm.Trim().ToLowerInvariant();
                int parsedId = 0;
                bool isId = int.TryParse(term, out parsedId);

                query = query.Where(m =>
                    m.Title.ToLower().Contains(term) ||
                    (m.OwnerName != null && m.OwnerName.ToLower().Contains(term)) ||
                    (m.Phone1 != null && m.Phone1.Contains(term)) ||
                    (m.Phone2 != null && m.Phone2.Contains(term)) ||
                    (isId && m.Id == parsedId));
            }

            var totalRecords = await query.CountAsync();

            query = request.SortDirection?.ToUpperInvariant() == "DESC"
                ? query.OrderByDescending(m => m.Id)
                : query.OrderBy(m => m.Title);

            var merchants = await query
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToListAsync();

            var merchantIds = merchants.Select(m => m.Id).ToList();

            // 1. Fetch Ledger Balances for these merchants
            var ledgerBalances = await _accountingDb.Accounts.AsNoTracking()
                .Where(a => a.OwnerMerchantId != null &&
                            merchantIds.Contains(a.OwnerMerchantId.Value) &&
                            a.Type == AccountType.Liability &&
                            a.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix))
                .Select(a => new
                {
                    MerchantId = a.OwnerMerchantId.Value,
                    Balance = a.LedgerEntries.Sum(e => e.Credit - e.Debit)
                })
                .ToDictionaryAsync(x => x.MerchantId, x => x.Balance);

            // 2. Fetch Reserved and Approved allocations per merchant
            var activeAllocations = await _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Include(a => a.SettlementRequest)
                .Where(a => merchantIds.Contains(a.MerchantId) &&
                            a.SettlementRequest != null &&
                            (a.SettlementRequest.Status == SettlementRequestStatus.Pending ||
                             a.SettlementRequest.Status == SettlementRequestStatus.Approved))
                .GroupBy(a => a.MerchantId)
                .Select(g => new
                {
                    MerchantId = g.Key,
                    TotalReserved = g.Sum(x => x.Amount),
                    ApprovedAwaitingReceipt = g.Where(x => x.SettlementRequest.Status == SettlementRequestStatus.Approved).Sum(x => x.Amount)
                })
                .ToDictionaryAsync(x => x.MerchantId);

            // 3. Fetch Order aggregates per merchant from delivered order details
            var orderAggregates = await _ordersDb.OrderDetails.AsNoTracking()
                .Where(d => merchantIds.Contains(d.MerchantId))
                .GroupBy(d => d.MerchantId)
                .Select(g => new
                {
                    MerchantId = g.Key,
                    OrdersCount = g.Select(x => x.OrderId).Distinct().Count(),
                    GrossSales = g.Sum(x => (decimal)x.Quantity * (x.SingleFinalPrice > 0 ? x.SingleFinalPrice : x.SinglePrice)),
                    MerchantNet = g.Sum(x => (decimal)x.Quantity * (x.SingleMerchantProfit > 0 ? x.SingleMerchantProfit : (x.SingleFinalPrice > 0 ? x.SingleFinalPrice : x.SinglePrice))),
                })
                .ToDictionaryAsync(x => x.MerchantId);

            // 4. Fetch Latest Settlement per merchant
            var latestSettlements = await _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Where(a => merchantIds.Contains(a.MerchantId) && a.SettlementRequest != null)
                .OrderByDescending(a => a.SettlementRequest.CreatedDate)
                .Select(a => new
                {
                    a.MerchantId,
                    a.SettlementRequest.RequestNumber,
                    a.SettlementRequest.Status,
                    a.SettlementRequest.CreatedDate
                })
                .ToListAsync();

            var latestSettlementByMerchant = latestSettlements
                .GroupBy(x => x.MerchantId)
                .ToDictionary(g => g.Key, g => g.First());

            // Build result items
            var items = merchants.Select(m =>
            {
                var balance = ledgerBalances.TryGetValue(m.Id, out var b) ? b : 0m;
                var reserved = activeAllocations.TryGetValue(m.Id, out var alloc) ? alloc.TotalReserved : 0m;
                var approvedAwaiting = activeAllocations.TryGetValue(m.Id, out var alloc2) ? alloc2.ApprovedAwaitingReceipt : 0m;
                var available = Math.Max(0m, balance - reserved);

                var orderStats = orderAggregates.TryGetValue(m.Id, out var stats) ? stats : null;
                var gross = orderStats?.GrossSales ?? 0m;
                var net = orderStats?.MerchantNet ?? 0m;
                var jtakShare = Math.Max(0m, gross - net);

                var latestSettle = latestSettlementByMerchant.TryGetValue(m.Id, out var ls) ? ls : null;

                return new MerchantReconciliationItemDto
                {
                    MerchantId = m.Id,
                    MerchantName = m.Title,
                    OwnerName = m.OwnerName,
                    Phone = !string.IsNullOrWhiteSpace(m.Phone1) ? m.Phone1 : m.Phone2,
                    OrdersCount = orderStats?.OrdersCount ?? 0,
                    GrossSales = gross,
                    JTakShare = jtakShare,
                    MerchantNet = net,
                    ReservedAmount = reserved,
                    AvailableAmount = available,
                    ApprovedAwaitingReceiptAmount = approvedAwaiting,
                    CurrentBalance = balance,
                    LastSettlementDate = latestSettle?.CreatedDate,
                    LastSettlementStatus = latestSettle?.Status,
                    LastSettlementRequestNumber = latestSettle?.RequestNumber,
                    Currency = "SYP"
                };
            }).ToList();

            return new MerchantReconciliationDataTableResultDto
            {
                Items = items,
                TotalRecords = totalRecords,
                Page = request.Page,
                PageSize = request.PageSize
            };
        }

        public async Task<MerchantStatementDto> GetMerchantStatementAsync(int merchantId, MerchantStatementRequestDto request)
        {
            if (request == null) request = new MerchantStatementRequestDto();
            if (request.Page < 1) request.Page = 1;
            if (request.PageSize < 1) request.PageSize = 50;

            // 1. Fetch Merchant metadata
            var merchant = await _catalogDb.Merchants.AsNoTracking()
                .FirstOrDefaultAsync(m => m.Id == merchantId);

            if (merchant == null)
                throw new InvalidOperationException($"Merchant #{merchantId} was not found in catalog.");

            var accountCode = $"{SystemAccountCodes.VendorPayablePrefix}{merchantId}";

            // 2. Fetch Merchant's Vendor Payable Account
            var account = await _accountingDb.Accounts.AsNoTracking()
                .FirstOrDefaultAsync(a => a.OwnerMerchantId == merchantId &&
                                          a.Type == AccountType.Liability &&
                                          a.AccountCode == accountCode);

            // 3. Fetch Chronological Ledger Entries
            var entriesQuery = _accountingDb.LedgerEntries.AsNoTracking()
                .Include(e => e.Transaction)
                .Where(e => e.AccountId == (account != null ? account.Id : Guid.Empty));

            if (request.FromDate.HasValue)
                entriesQuery = entriesQuery.Where(e => (e.Transaction != null ? e.Transaction.PostedDate : e.CreatedDate) >= request.FromDate.Value);
            if (request.ToDate.HasValue)
                entriesQuery = entriesQuery.Where(e => (e.Transaction != null ? e.Transaction.PostedDate : e.CreatedDate) <= request.ToDate.Value);

            var rawEntries = await entriesQuery
                .OrderBy(e => e.Transaction != null ? e.Transaction.PostedDate : e.CreatedDate)
                .ThenBy(e => e.Id)
                .ToListAsync();

            // 4. Compute Accurate Chronological Running Balance (Earliest to Latest)
            decimal running = 0m;
            var processedTransactions = new List<MerchantStatementTransactionDto>();

            // Collect referenced order IDs and settlement IDs for batch enrichment
            var orderIdsToFetch = new HashSet<int>();
            var settlementIdsToFetch = new HashSet<string>();

            foreach (var e in rawEntries)
            {
                // Liability account formula: Credit increases payable, Debit decreases payable
                running += (e.Credit - e.Debit);

                var refType = e.Transaction?.ReferenceType ?? "General";
                var refId = e.Transaction?.ReferenceId ?? string.Empty;

                int parsedOrderId = 0;
                if (refType == "OrderDelivery" || refType == "OrderCancellationReversal")
                {
                    if (int.TryParse(refId, out parsedOrderId))
                        orderIdsToFetch.Add(parsedOrderId);
                }
                else if (refType == "MerchantSettlementRequest" || refType == "SettlementRequest")
                {
                    if (!string.IsNullOrWhiteSpace(refId))
                        settlementIdsToFetch.Add(refId);
                }

                processedTransactions.Add(new MerchantStatementTransactionDto
                {
                    EntryId = e.Id,
                    TransactionId = e.JournalTransactionId,
                    TransactionNumber = e.Transaction?.TransactionNumber ?? $"TXN-{e.Id}",
                    PostedDate = e.Transaction?.PostedDate ?? e.CreatedDate,
                    ReferenceType = refType,
                    ReferenceId = refId,
                    OrderNumber = parsedOrderId > 0 ? parsedOrderId : (int?)null,
                    MerchantTitle = merchant.Title,
                    Debit = e.Debit,
                    Credit = e.Credit,
                    RunningBalance = running,
                    Currency = e.Currency ?? "SYP",
                    Description = e.Memo ?? e.Transaction?.Description ?? "قيد محاسبي"
                });
            }

            // 5. Batch Fetch Linked Orders & Details
            var ordersMap = new Dictionary<int, Order>();
            if (orderIdsToFetch.Count > 0)
            {
                ordersMap = await _ordersDb.Orders.AsNoTracking()
                    .Include(o => o.OrderDetails)
                    .Where(o => orderIdsToFetch.Contains(o.Id))
                    .ToDictionaryAsync(o => o.Id);
            }

            // 6. Batch Fetch Linked Settlement Requests
            var settlementsMap = new Dictionary<string, SettlementRequest>();
            if (settlementIdsToFetch.Count > 0)
            {
                var settlementGuids = new List<Guid>();
                var settlementNumbers = new List<string>();

                foreach (var id in settlementIdsToFetch)
                {
                    if (Guid.TryParse(id, out var g)) settlementGuids.Add(g);
                    else settlementNumbers.Add(id);
                }

                var requests = await _accountingDb.SettlementRequests.AsNoTracking()
                    .Where(r => settlementGuids.Contains(r.Id) || settlementNumbers.Contains(r.RequestNumber))
                    .ToListAsync();

                foreach (var r in requests)
                {
                    settlementsMap[r.Id.ToString()] = r;
                    settlementsMap[r.RequestNumber] = r;
                }
            }

            // 7. Enrich Transactions with Human-Readable "البيان" and Order/Customer metadata
            foreach (var item in processedTransactions)
            {
                if (item.ReferenceType == "OrderDelivery" && item.OrderNumber.HasValue && ordersMap.TryGetValue(item.OrderNumber.Value, out var order))
                {
                    item.CustomerName = !string.IsNullOrWhiteSpace(order.User) ? order.User : "عميل جيتك";
                    item.CustomerPhone = order.Phonenumber;
                    item.OrderDate = order.PurchaseDate ?? order.CreatedDate;
                    item.PaymentMethod = order.PaymentMethod == PaymentMethod.PayOnDelivery ? "نقداً عند الاستلام (COD)" : "دفع إلكتروني";
                    item.FinancialStatus = "تم القيد بالدفتر";
                    item.Type = "مبيعات طلب";

                    var merchantItems = order.OrderDetails?.Where(d => d.MerchantId == merchantId).ToList() ?? new List<OrderDetail>();
                    var gross = merchantItems.Sum(d => (decimal)d.Quantity * (d.SingleFinalPrice > 0 ? d.SingleFinalPrice : d.SinglePrice));
                    var net = item.Credit;
                    var jtakShare = Math.Max(0m, gross - net);

                    item.GrossAmount = gross > 0 ? gross : item.Credit;
                    item.MerchantNet = net;
                    item.JTakShare = jtakShare;

                    // Human-Readable Statement Description
                    item.Description = $"طلب #{order.Id} — {merchant.Title} — العميل: {item.CustomerName} — إجمالي الطلب {item.GrossAmount:N0} ل.س — صافي مستحق التاجر {item.MerchantNet:N0} ل.س";
                }
                else if (item.ReferenceType == "MerchantSettlementRequest" || item.ReferenceType == "SettlementRequest")
                {
                    item.Type = "تسوية مستحقات";
                    var requestNum = item.ReferenceId;
                    if (settlementsMap.TryGetValue(item.ReferenceId, out var settleReq))
                    {
                        requestNum = settleReq.RequestNumber;
                        item.SettlementRequestNumber = settleReq.RequestNumber;
                    }
                    else
                    {
                        item.SettlementRequestNumber = item.ReferenceId;
                    }

                    item.FinancialStatus = "مكتمل";
                    item.Description = $"تم استلام وتسوية {requestNum} — تم خصم {item.Debit:N0} ل.س من مستحقات التاجر";
                }
                else if (item.ReferenceType == "OrderCancellationReversal")
                {
                    item.Type = "إلغاء وتعديل قيد طلب";
                    item.FinancialStatus = "معكوس";
                    item.Description = $"عكس قيد مبيعات الطلب #{item.OrderNumber} بسبب إلغاء الطلب — تم خصم {item.Debit:N0} ل.س";
                }
                else
                {
                    item.Type = "قيد تسوية محاسبي";
                    item.FinancialStatus = "مقيد";
                }
            }

            // 8. Fetch Merchant's Complete Settlement Request History
            var settlementHistory = await _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Include(a => a.SettlementRequest)
                .Where(a => a.MerchantId == merchantId && a.SettlementRequest != null)
                .OrderByDescending(a => a.SettlementRequest.CreatedDate)
                .Select(a => new MerchantSettlementHistoryItemDto
                {
                    Id = a.SettlementRequestId,
                    RequestNumber = a.SettlementRequest.RequestNumber,
                    Amount = a.Amount,
                    Currency = a.SettlementRequest.Currency ?? "SYP",
                    Method = a.SettlementRequest.Method ?? "حوالة / نقدي",
                    AccountDetails = a.SettlementRequest.AccountDetails,
                    RequestedAt = a.SettlementRequest.CreatedDate,
                    Status = a.SettlementRequest.Status,
                    ApprovedAt = (a.SettlementRequest.Status == SettlementRequestStatus.Approved || a.SettlementRequest.Status == SettlementRequestStatus.Completed) ? a.SettlementRequest.ReviewedAt : null,
                    RejectedAt = a.SettlementRequest.Status == SettlementRequestStatus.Rejected ? a.SettlementRequest.ReviewedAt : null,
                    RejectionReason = a.SettlementRequest.RejectionReason,
                    CompletedAt = a.SettlementRequest.CompletedAt,
                    PayoutSourceAccount = a.SettlementRequest.Method,
                    Notes = a.SettlementRequest.Notes
                })
                .ToListAsync();

            // 9. Compute Real-time Balances
            var currentBalance = running; // Running balance at the latest chronological entry

            var activeAllocationsQuery = _accountingDb.SettlementRequestMerchantAllocations.AsNoTracking()
                .Include(a => a.SettlementRequest)
                .Where(a => a.MerchantId == merchantId && a.SettlementRequest != null);

            var reservedAllocations = await activeAllocationsQuery
                .Where(a => a.SettlementRequest.Status == SettlementRequestStatus.Pending ||
                            a.SettlementRequest.Status == SettlementRequestStatus.Approved)
                .SumAsync(a => (decimal?)a.Amount) ?? 0m;

            var approvedAwaitingAllocations = await activeAllocationsQuery
                .Where(a => a.SettlementRequest.Status == SettlementRequestStatus.Approved)
                .SumAsync(a => (decimal?)a.Amount) ?? 0m;

            var availableAmount = Math.Max(0m, currentBalance - reservedAllocations);

            // 10. Filter by Search Term (e.g. Transaction Number, Order Number, Settlement Request #, Description, Customer)
            var filteredTransactions = processedTransactions.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(request.SearchTerm))
            {
                var term = request.SearchTerm.Trim().ToLowerInvariant();
                filteredTransactions = filteredTransactions.Where(t =>
                    (t.TransactionNumber != null && t.TransactionNumber.ToLowerInvariant().Contains(term)) ||
                    (t.OrderNumber.HasValue && t.OrderNumber.Value.ToString().Contains(term)) ||
                    (t.SettlementRequestNumber != null && t.SettlementRequestNumber.ToLowerInvariant().Contains(term)) ||
                    (t.Description != null && t.Description.ToLowerInvariant().Contains(term)) ||
                    (t.CustomerName != null && t.CustomerName.ToLowerInvariant().Contains(term)) ||
                    (t.ReferenceId != null && t.ReferenceId.ToLowerInvariant().Contains(term)));
            }

            // 11. Sort: AUTHORITATIVE NEWEST FIRST (PostedDate DESC, EntryId DESC)
            var sortedTransactions = filteredTransactions
                .OrderByDescending(t => t.PostedDate)
                .ThenByDescending(t => t.EntryId)
                .ToList();

            var totalRecords = sortedTransactions.Count;

            // 12. Apply Server-side Pagination
            var pagedTransactions = sortedTransactions
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToList();

            return new MerchantStatementDto
            {
                MerchantId = merchant.Id,
                MerchantName = merchant.Title,
                OwnerName = merchant.OwnerName,
                Phone = !string.IsNullOrWhiteSpace(merchant.Phone1) ? merchant.Phone1 : merchant.Phone2,
                AccountCode = accountCode,
                CurrentBalance = currentBalance,
                ReservedAmount = reservedAllocations,
                AvailableAmount = availableAmount,
                ApprovedAwaitingReceiptAmount = approvedAwaitingAllocations,
                Currency = "SYP",
                TotalRecords = totalRecords,
                Page = request.Page,
                PageSize = request.PageSize,
                Items = pagedTransactions,
                SettlementHistory = settlementHistory
            };
        }
    }
}
