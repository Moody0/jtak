using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using App.Catalog.Data;
using App.Shared.Entities;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public class SettlementHistoryService : ISettlementHistoryService
    {
        private readonly AccountingDbContext _context;
        private readonly CatalogDbContext _catalogDb;
        private readonly UserManager<AppUser> _userManager;
        private readonly ILogger<SettlementHistoryService> _logger;

        public SettlementHistoryService(
            AccountingDbContext context,
            CatalogDbContext catalogDb = null,
            UserManager<AppUser> userManager = null,
            ILogger<SettlementHistoryService> logger = null)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _catalogDb = catalogDb;
            _userManager = userManager;
            _logger = logger;
        }

        public async Task<SettlementHistoryDataTableResultDto> GetDataTableAsync(SettlementHistoryDataTableRequest request)
        {
            request ??= new SettlementHistoryDataTableRequest();
            if (request.Page <= 0) request.Page = 1;
            if (request.PageSize <= 0) request.PageSize = 10;
            if (request.PageSize > 1000) request.PageSize = 1000;

            var allItems = await LoadCompletedSettlementsAsync();

            // Apply Filters
            var filtered = FilterItems(allItems, request.PartyFilter, request.FromDate, request.ToDate, request.SearchTerm);

            // Calculate Authoritative Summary over filtered dataset
            var summary = CalculateSummary(filtered);

            // Apply Server-side Ordering
            var ordered = OrderItems(filtered, request.SortColumn, request.SortDirection);

            // Apply Server-side Pagination
            var paged = ordered
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToList();

            return new SettlementHistoryDataTableResultDto
            {
                Items = paged,
                TotalRecords = filtered.Count,
                Page = request.Page,
                PageSize = request.PageSize,
                Summary = summary
            };
        }

        public async Task<SettlementHistorySummaryDto> GetSummaryAsync(
            SettlementHistoryPartyFilter partyFilter = SettlementHistoryPartyFilter.All,
            DateTime? fromDate = null,
            DateTime? toDate = null,
            string searchTerm = null)
        {
            var allItems = await LoadCompletedSettlementsAsync();
            var filtered = FilterItems(allItems, partyFilter, fromDate, toDate, searchTerm);
            return CalculateSummary(filtered);
        }

        public async Task<List<SettlementHistoryItemDto>> GetPrintDataAsync(SettlementHistoryDataTableRequest request)
        {
            request ??= new SettlementHistoryDataTableRequest();
            var allItems = await LoadCompletedSettlementsAsync();
            var filtered = FilterItems(allItems, request.PartyFilter, request.FromDate, request.ToDate, request.SearchTerm);
            var ordered = OrderItems(filtered, request.SortColumn, request.SortDirection);

            // Limit print dataset to safe max (1000) to prevent browser freeze
            return ordered.Take(1000).ToList();
        }

        public async Task<SettlementReceiptDto> GetReceiptAsync(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
                throw new ArgumentException("معرف سجل التسوية مطلوب.", nameof(id));

            var idTrimmed = id.Trim();
            Guid parsedGuid = Guid.Empty;
            bool isGuid = Guid.TryParse(idTrimmed, out parsedGuid);

            // 1. Try finding in SettlementRequests
            var req = await _context.SettlementRequests.AsNoTracking()
                .Include(r => r.MerchantAllocations)
                .FirstOrDefaultAsync(r => (isGuid && r.Id == parsedGuid) || r.RequestNumber == idTrimmed);

            if (req != null)
            {
                // Strict guardrail: Do NOT allow receipt printing for a settlement that is not legitimately Completed
                if (req.Status != SettlementRequestStatus.Completed)
                {
                    throw new InvalidOperationException("لا يمكن طباعة إيصال لطلب تسوية غير مكتمل.");
                }

                // Resolve Admin and Approver Names
                string approvedByName = await ResolveAdminNameAsync(req.ReviewedByAdminId);
                string confirmedByName = await ResolveAdminNameAsync(req.CompletedByAdminId) ?? (req.PartyType == SettlementPartyType.Merchant ? "التاجر" : "الإدارة المالية");

                // Resolve Journal Transaction
                string journalTxnNumber = null;
                if (req.LedgerTransactionId.HasValue)
                {
                    var jt = await _context.JournalTransactions.AsNoTracking()
                        .FirstOrDefaultAsync(t => t.Id == req.LedgerTransactionId.Value);
                    journalTxnNumber = jt?.TransactionNumber;
                }
                if (string.IsNullOrEmpty(journalTxnNumber))
                {
                    var jtRef = await _context.JournalTransactions.AsNoTracking()
                        .FirstOrDefaultAsync(t => t.ReferenceId == req.Id.ToString());
                    journalTxnNumber = jtRef?.TransactionNumber;
                }

                // Resolve Merchant details if merchant
                int? merchantId = null;
                string partyName = req.RequestedByName;
                string vendorAccount = null;
                string payoutSourceAccount = ResolvePayoutSourceAccountLabel(req.Method);

                if (req.PartyType == SettlementPartyType.Merchant)
                {
                    var firstAlloc = req.MerchantAllocations.FirstOrDefault();
                    if (firstAlloc != null)
                    {
                        merchantId = firstAlloc.MerchantId;
                        if (!string.IsNullOrWhiteSpace(firstAlloc.MerchantTitle))
                        {
                            partyName = firstAlloc.MerchantTitle;
                        }
                    }

                    if (merchantId.HasValue)
                    {
                        vendorAccount = $"{SystemAccountCodes.VendorPayablePrefix}{merchantId.Value}";
                    }
                    else
                    {
                        vendorAccount = $"{SystemAccountCodes.VendorPayablePrefix}VND";
                    }

                    string phone = req.RequestedByPhone;
                    if (string.IsNullOrWhiteSpace(phone) && merchantId.HasValue && _catalogDb != null)
                    {
                        var m = await _catalogDb.Merchants.AsNoTracking().FirstOrDefaultAsync(x => x.Id == merchantId.Value);
                        phone = m?.Phone1 ?? m?.Phone2;
                    }

                    return new SettlementReceiptDto
                    {
                        Id = req.Id.ToString(),
                        ReceiptNumber = $"REC-{req.RequestNumber}",
                        RequestNumber = req.RequestNumber,
                        PartyType = SettlementPartyType.Merchant,
                        ReceiptTitle = "إيصال تسوية وصرف مستحقات تاجر",
                        PartyName = partyName,
                        Phone = phone,
                        MerchantId = merchantId,
                        Amount = req.Amount,
                        Currency = req.Currency ?? "SYP",
                        Method = FormatMethodLabel(req.Method),
                        Status = "مكتمل",
                        RequestedAt = req.CreatedDate,
                        ApprovedAt = req.ReviewedAt,
                        CompletedAt = req.CompletedAt ?? req.ReviewedAt ?? req.CreatedDate,
                        ApprovedBy = approvedByName ?? "مدير النظام",
                        ConfirmedBy = confirmedByName,
                        VendorPayableAccount = vendorAccount,
                        PayoutSourceAccount = payoutSourceAccount,
                        DestinationAccount = vendorAccount,
                        JournalTransactionNumber = journalTxnNumber ?? "قيد مسجل في دفتر الأستاذ",
                        JournalTransactionId = req.LedgerTransactionId,
                        OperationType = "تسوية وصرف مستحقات تاجر",
                        Notes = req.Notes,
                        GeneratedAt = DateTime.UtcNow
                    };
                }
                else
                {
                    // Captain Settlement Request
                    var captainFloatAccount = $"{SystemAccountCodes.CaptainCashFloatPrefix}{req.RequestedByUserId}";
                    return new SettlementReceiptDto
                    {
                        Id = req.Id.ToString(),
                        ReceiptNumber = $"REC-{req.RequestNumber}",
                        RequestNumber = req.RequestNumber,
                        PartyType = SettlementPartyType.Captain,
                        ReceiptTitle = "إيصال توريد نقدية وتسوية عهدة مندوب",
                        PartyName = req.RequestedByName,
                        Phone = req.RequestedByPhone,
                        DriverId = req.RequestedByUserId,
                        Amount = req.Amount,
                        Currency = req.Currency ?? "SYP",
                        Method = FormatMethodLabel(req.Method) ?? "نقداً - الخزينة الرئيسية",
                        Status = "مكتمل",
                        RequestedAt = req.CreatedDate,
                        ApprovedAt = req.ReviewedAt,
                        CompletedAt = req.CompletedAt ?? req.ReviewedAt ?? req.CreatedDate,
                        ApprovedBy = approvedByName ?? "المسؤول المالي",
                        ConfirmedBy = confirmedByName,
                        CaptainCashFloatAccount = captainFloatAccount,
                        PayoutSourceAccount = "1000 - خزينة الشركة الرئيسية",
                        DestinationAccount = "1000 - خزينة الشركة الرئيسية",
                        JournalTransactionNumber = journalTxnNumber ?? "قيد مسجل في دفتر الأستاذ",
                        JournalTransactionId = req.LedgerTransactionId,
                        OperationType = "نقدية موردة / تسوية عهدة كابتن",
                        Notes = req.Notes,
                        GeneratedAt = DateTime.UtcNow
                    };
                }
            }

            // 2. Try finding in DailySettlementBatches
            var batch = await _context.DailySettlementBatches.AsNoTracking()
                .FirstOrDefaultAsync(b => (isGuid && b.Id == parsedGuid) || b.BatchCode == idTrimmed);

            if (batch != null)
            {
                string captainName = await ResolveUserNameAsync(batch.CaptainUserId) ?? $"الكابتن {batch.CaptainUserId}";
                string adminName = await ResolveAdminNameAsync(batch.HandledByAdminId) ?? "المسؤول المالي";

                string journalTxnNumber = null;
                if (batch.SettlementTransactionId != Guid.Empty)
                {
                    var jt = await _context.JournalTransactions.AsNoTracking()
                        .FirstOrDefaultAsync(t => t.Id == batch.SettlementTransactionId);
                    journalTxnNumber = jt?.TransactionNumber;
                }

                decimal amount = batch.NetCashRemitted > 0 ? batch.NetCashRemitted : batch.TotalCashCollected;
                var captainFloatAccount = $"{SystemAccountCodes.CaptainCashFloatPrefix}{batch.CaptainUserId}";

                return new SettlementReceiptDto
                {
                    Id = batch.Id.ToString(),
                    ReceiptNumber = $"REC-{batch.BatchCode}",
                    RequestNumber = batch.BatchCode,
                    PartyType = SettlementPartyType.Captain,
                    ReceiptTitle = "إيصال تسوية وتوريد عهدة يومية لمندوب",
                    PartyName = captainName,
                    DriverId = batch.CaptainUserId,
                    Amount = amount,
                    Currency = "SYP",
                    Method = "نقداً - تسوية وردية يومية",
                    Status = "مكتمل",
                    RequestedAt = batch.CreatedDate,
                    ApprovedAt = batch.BatchDate,
                    CompletedAt = batch.BatchDate,
                    ApprovedBy = adminName,
                    ConfirmedBy = adminName,
                    CaptainCashFloatAccount = captainFloatAccount,
                    PayoutSourceAccount = "1000 - خزينة الشركة الرئيسية",
                    DestinationAccount = "1000 - خزينة الشركة الرئيسية",
                    JournalTransactionNumber = journalTxnNumber ?? "قيد مسجل في دفتر الأستاذ",
                    JournalTransactionId = batch.SettlementTransactionId != Guid.Empty ? batch.SettlementTransactionId : null,
                    OperationType = "تسوية عهدة يومية (EOD Shift Remittance)",
                    Notes = batch.DiscrepancyReason ?? batch.Notes,
                    GeneratedAt = DateTime.UtcNow
                };
            }

            throw new InvalidOperationException("سجل التسوية المطلوب غير موجود.");
        }

        private async Task<List<SettlementHistoryItemDto>> LoadCompletedSettlementsAsync()
        {
            var list = new List<SettlementHistoryItemDto>();

            // 1. Authoritative Source A: SettlementRequests (Status == Completed)
            var completedRequests = await _context.SettlementRequests.AsNoTracking()
                .Include(r => r.MerchantAllocations)
                .Where(r => r.Status == SettlementRequestStatus.Completed)
                .ToListAsync();

            // 2. Authoritative Source B: DailySettlementBatches (All valid completed EOD shifts)
            var batches = await _context.DailySettlementBatches.AsNoTracking().ToListAsync();

            // Collect all transaction IDs and Reference IDs to batch-load Journal Transactions (zero N+1)
            var txIds = completedRequests
                .Where(r => r.LedgerTransactionId.HasValue)
                .Select(r => r.LedgerTransactionId.Value)
                .Concat(batches.Where(b => b.SettlementTransactionId != Guid.Empty).Select(b => b.SettlementTransactionId))
                .Distinct()
                .ToList();

            var refIds = completedRequests.Select(r => r.Id.ToString()).Distinct().ToList();

            var matchingJournals = await _context.JournalTransactions.AsNoTracking()
                .Where(t => (txIds.Count > 0 && txIds.Contains(t.Id)) || (refIds.Count > 0 && refIds.Contains(t.ReferenceId)))
                .ToListAsync();

            var journalByIdMap = matchingJournals.ToDictionary(t => t.Id, t => t.TransactionNumber);
            var journalByRefMap = matchingJournals
                .Where(t => !string.IsNullOrEmpty(t.ReferenceId))
                .GroupBy(t => t.ReferenceId)
                .ToDictionary(g => g.Key, g => g.First().TransactionNumber);

            // Collect user IDs for batch-loading names if UserManager available
            var userIds = completedRequests
                .Select(r => r.RequestedByUserId)
                .Concat(completedRequests.Where(r => r.ReviewedByAdminId.HasValue).Select(r => r.ReviewedByAdminId.Value))
                .Concat(completedRequests.Where(r => r.CompletedByAdminId.HasValue).Select(r => r.CompletedByAdminId.Value))
                .Concat(batches.Select(b => b.CaptainUserId))
                .Concat(batches.Select(b => b.HandledByAdminId))
                .Distinct()
                .ToList();

            var userMap = new Dictionary<Guid, string>();
            if (_userManager != null && userIds.Count > 0)
            {
                foreach (var uid in userIds)
                {
                    try
                    {
                        var u = await _userManager.FindByIdAsync(uid.ToString());
                        if (u != null)
                        {
                            userMap[uid] = u.FullName ?? u.UserName;
                        }
                    }
                    catch
                    {
                        // Ignore individual lookup errors
                    }
                }
            }

            // Map SettlementRequests
            foreach (var req in completedRequests)
            {
                int? merchantId = null;
                string partyName = req.RequestedByName;
                string destAccount = null;

                if (req.PartyType == SettlementPartyType.Merchant)
                {
                    var firstAlloc = req.MerchantAllocations.FirstOrDefault();
                    if (firstAlloc != null)
                    {
                        merchantId = firstAlloc.MerchantId;
                        if (!string.IsNullOrWhiteSpace(firstAlloc.MerchantTitle))
                        {
                            partyName = firstAlloc.MerchantTitle;
                        }
                    }
                    destAccount = merchantId.HasValue
                        ? $"{SystemAccountCodes.VendorPayablePrefix}{merchantId.Value}"
                        : $"{SystemAccountCodes.VendorPayablePrefix}VND";
                }
                else
                {
                    destAccount = $"{SystemAccountCodes.CaptainCashFloatPrefix}{req.RequestedByUserId}";
                }

                string approvedBy = req.ReviewedByAdminId.HasValue && userMap.TryGetValue(req.ReviewedByAdminId.Value, out var aName)
                    ? aName
                    : (req.ReviewedByAdminId.HasValue ? "مدير النظام" : null);

                string confirmedBy = req.CompletedByAdminId.HasValue && userMap.TryGetValue(req.CompletedByAdminId.Value, out var cName)
                    ? cName
                    : (req.PartyType == SettlementPartyType.Merchant ? "التاجر" : (approvedBy ?? "الإدارة المالية"));

                string txnNumber = null;
                if (req.LedgerTransactionId.HasValue && journalByIdMap.TryGetValue(req.LedgerTransactionId.Value, out var jNum1))
                {
                    txnNumber = jNum1;
                }
                else if (journalByRefMap.TryGetValue(req.Id.ToString(), out var jNum2))
                {
                    txnNumber = jNum2;
                }

                var completedTime = req.CompletedAt ?? req.ReviewedAt ?? req.CreatedDate;

                list.Add(new SettlementHistoryItemDto
                {
                    Id = req.Id.ToString(),
                    RequestNumber = req.RequestNumber,
                    PartyType = req.PartyType,
                    PartyTypeLabel = req.PartyType == SettlementPartyType.Merchant ? "تاجر" : "سائق / مندوب",
                    PartyName = partyName,
                    Phone = req.RequestedByPhone,
                    MerchantId = merchantId,
                    DriverId = req.PartyType == SettlementPartyType.Captain ? req.RequestedByUserId : null,
                    Amount = req.Amount,
                    Currency = req.Currency ?? "SYP",
                    Method = FormatMethodLabel(req.Method) ?? (req.PartyType == SettlementPartyType.Merchant ? "صندوق الخزينة النقدي" : "نقداً - الخزينة"),
                    Status = "Completed",
                    RequestedAt = req.CreatedDate,
                    ApprovedAt = req.ReviewedAt,
                    CompletedAt = completedTime,
                    ApprovedBy = approvedBy ?? "مدير النظام",
                    ConfirmedBy = confirmedBy,
                    SourceAccount = ResolvePayoutSourceAccountLabel(req.Method),
                    DestinationAccount = destAccount,
                    JournalTransactionNumber = txnNumber,
                    JournalTransactionId = req.LedgerTransactionId,
                    Notes = req.Notes,
                    OperationType = req.PartyType == SettlementPartyType.Merchant ? "تسوية مستحقات تاجر" : "توريد نقدية عهدة كابتن"
                });
            }

            // Map DailySettlementBatches (Avoiding duplicates if already represented by SettlementRequest)
            var existingRequestCodes = new HashSet<string>(completedRequests.Select(r => r.RequestNumber), StringComparer.OrdinalIgnoreCase);
            var existingTxnIds = new HashSet<Guid>(completedRequests.Where(r => r.LedgerTransactionId.HasValue).Select(r => r.LedgerTransactionId.Value));

            foreach (var b in batches)
            {
                if (existingRequestCodes.Contains(b.BatchCode) ||
                    (b.SettlementTransactionId != Guid.Empty && existingTxnIds.Contains(b.SettlementTransactionId)))
                {
                    continue; // Skip duplicate
                }

                string captainName = userMap.TryGetValue(b.CaptainUserId, out var capName)
                    ? capName
                    : $"الكابتن {b.CaptainUserId}";

                string adminName = userMap.TryGetValue(b.HandledByAdminId, out var admName)
                    ? admName
                    : "المسؤول المالي";

                string txnNumber = b.SettlementTransactionId != Guid.Empty && journalByIdMap.TryGetValue(b.SettlementTransactionId, out var jNum)
                    ? jNum
                    : null;

                decimal amount = b.NetCashRemitted > 0 ? b.NetCashRemitted : b.TotalCashCollected;

                list.Add(new SettlementHistoryItemDto
                {
                    Id = b.Id.ToString(),
                    RequestNumber = b.BatchCode,
                    PartyType = SettlementPartyType.Captain,
                    PartyTypeLabel = "سائق / مندوب",
                    PartyName = captainName,
                    Phone = null,
                    MerchantId = null,
                    DriverId = b.CaptainUserId,
                    Amount = amount,
                    Currency = "SYP",
                    Method = "نقداً - تسوية وردية يومية",
                    Status = "Completed",
                    RequestedAt = b.CreatedDate,
                    ApprovedAt = b.BatchDate,
                    CompletedAt = b.BatchDate,
                    ApprovedBy = adminName,
                    ConfirmedBy = adminName,
                    SourceAccount = "1000 - خزينة الشركة الرئيسية",
                    DestinationAccount = $"{SystemAccountCodes.CaptainCashFloatPrefix}{b.CaptainUserId}",
                    JournalTransactionNumber = txnNumber,
                    JournalTransactionId = b.SettlementTransactionId != Guid.Empty ? b.SettlementTransactionId : null,
                    Notes = b.DiscrepancyReason ?? b.Notes,
                    OperationType = "تسوية عهدة يومية (EOD Shift Remittance)"
                });
            }

            return list;
        }

        private static List<SettlementHistoryItemDto> FilterItems(
            List<SettlementHistoryItemDto> items,
            SettlementHistoryPartyFilter partyFilter,
            DateTime? fromDate,
            DateTime? toDate,
            string searchTerm)
        {
            var query = items.AsEnumerable();

            // 1. Party Filter
            if (partyFilter == SettlementHistoryPartyFilter.Merchant)
            {
                query = query.Where(x => x.PartyType == SettlementPartyType.Merchant);
            }
            else if (partyFilter == SettlementHistoryPartyFilter.Captain)
            {
                query = query.Where(x => x.PartyType == SettlementPartyType.Captain);
            }

            // 2. Date Filter
            if (fromDate.HasValue)
            {
                var start = fromDate.Value.Date;
                query = query.Where(x => x.CompletedAt >= start);
            }
            if (toDate.HasValue)
            {
                var end = toDate.Value.Date.AddDays(1).AddTicks(-1);
                query = query.Where(x => x.CompletedAt <= end);
            }

            // 3. Search Term
            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                var term = searchTerm.Trim();
                query = query.Where(x =>
                    (x.RequestNumber != null && x.RequestNumber.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (x.PartyName != null && x.PartyName.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (x.Phone != null && x.Phone.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (x.JournalTransactionNumber != null && x.JournalTransactionNumber.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (x.MerchantId.HasValue && x.MerchantId.Value.ToString() == term) ||
                    (x.Notes != null && x.Notes.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) ||
                    (x.DestinationAccount != null && x.DestinationAccount.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0)
                );
            }

            return query.ToList();
        }

        private static SettlementHistorySummaryDto CalculateSummary(List<SettlementHistoryItemDto> items)
        {
            var merchants = items.Where(x => x.PartyType == SettlementPartyType.Merchant).ToList();
            var drivers = items.Where(x => x.PartyType == SettlementPartyType.Captain).ToList();

            return new SettlementHistorySummaryDto
            {
                TotalCompletedCount = items.Count,
                TotalCompletedAmount = items.Sum(x => x.Amount),
                MerchantCompletedCount = merchants.Count,
                MerchantCompletedAmount = merchants.Sum(x => x.Amount),
                DriverCompletedCount = drivers.Count,
                DriverCompletedAmount = drivers.Sum(x => x.Amount),
                Currency = "SYP"
            };
        }

        private static List<SettlementHistoryItemDto> OrderItems(List<SettlementHistoryItemDto> items, string sortColumn, string sortDirection)
        {
            bool isAsc = string.Equals(sortDirection, "ASC", StringComparison.OrdinalIgnoreCase);
            var col = (sortColumn ?? "CompletedAt").Trim();

            return col.ToLowerInvariant() switch
            {
                "amount" => isAsc ? items.OrderBy(x => x.Amount).ToList() : items.OrderByDescending(x => x.Amount).ToList(),
                "partyname" => isAsc ? items.OrderBy(x => x.PartyName).ToList() : items.OrderByDescending(x => x.PartyName).ToList(),
                "requestnumber" => isAsc ? items.OrderBy(x => x.RequestNumber).ToList() : items.OrderByDescending(x => x.RequestNumber).ToList(),
                _ => isAsc ? items.OrderBy(x => x.CompletedAt).ToList() : items.OrderByDescending(x => x.CompletedAt).ToList(),
            };
        }

        private async Task<string> ResolveAdminNameAsync(Guid? adminId)
        {
            if (!adminId.HasValue || adminId.Value == Guid.Empty) return null;
            if (_userManager == null) return null;
            try
            {
                var u = await _userManager.FindByIdAsync(adminId.Value.ToString());
                return u?.FullName ?? u?.UserName;
            }
            catch
            {
                return null;
            }
        }

        private async Task<string> ResolveUserNameAsync(Guid userId)
        {
            if (userId == Guid.Empty) return null;
            if (_userManager == null) return null;
            try
            {
                var u = await _userManager.FindByIdAsync(userId.ToString());
                return u?.FullName ?? u?.UserName;
            }
            catch
            {
                return null;
            }
        }

        private static string ResolvePayoutSourceAccountLabel(string method)
        {
            var m = (method ?? string.Empty).ToLowerInvariant();
            if (m.Contains("bank") || m.Contains("wire") || m.Contains("transfer"))
                return $"{SystemAccountCodes.BankMain} - الحساب البنكي الرئيسي";
            if (m.Contains("safe") || m == "cash_safe" || m == "office_safe")
                return $"{SystemAccountCodes.CompanyCashSafe} - صندوق الخزينة النقدي";
            if (m.Contains("pgw") || m.Contains("gateway") || m.Contains("clearing"))
                return $"{SystemAccountCodes.ElectronicPaymentGateway} - بوابة الدفع الإلكتروني";

            return $"{SystemAccountCodes.CompanyMainVault} - خزينة الشركة الرئيسية";
        }

        private static string FormatMethodLabel(string method)
        {
            if (string.IsNullOrWhiteSpace(method)) return "نقداً من الخزينة";
            var m = method.ToLowerInvariant();
            if (m.Contains("bank") || m.Contains("transfer")) return "حوالة بنكية";
            if (m.Contains("safe") || m == "cash_safe") return "صندوق الخزينة النقدي";
            if (m.Contains("vault") || m == "cash" || m == "cash_hand") return "نقداً - الخزينة الرئيسية";
            return method;
        }
    }
}
