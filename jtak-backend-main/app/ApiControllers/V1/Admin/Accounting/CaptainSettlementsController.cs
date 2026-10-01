using Modules.Accounting.Services;
using Modules.Shipping.Services;
using App.Shared.Services.Extentions;
using App.ApiModels;
using App.Extensions;
using App.Orders.Data;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Orders.Entities;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin.Accounting
{
    public class CaptainSettlementsOverviewDto
    {
        public int TotalOrders { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalDeliveryFees { get; set; }
        public decimal TotalCaptainEarnings { get; set; }
        public decimal TotalNetDueToCompany { get; set; }
        public List<CaptainSettlementItemDto> Items { get; set; } = new();
    }

    public class CaptainSettlementItemDto
    {
        public Guid CaptainId { get; set; }
        public string CaptainName { get; set; }
        public string PhoneNumber { get; set; }
        public CaptainCompensationType CompensationType { get; set; }
        public string CompensationTypeDisplay { get; set; }
        public decimal CaptainRate { get; set; }
        public int CompletedOrdersCount { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalDeliveryFees { get; set; }
        public decimal TotalCaptainEarnings { get; set; }
        public decimal NetDueToCompany { get; set; }
        public int UnsettledOrdersCount { get; set; }
        public int SettledOrdersCount { get; set; }
        public string SettlementStatus { get; set; } // "Settled", "Unsettled", "NoOrders"
        public DateTime? LastSettledAt { get; set; }
        public string LastSettlementBatchId { get; set; }
    }

    public class CaptainOrdersSettlementDetailDto
    {
        public Guid CaptainId { get; set; }
        public string CaptainName { get; set; }
        public string PhoneNumber { get; set; }
        public CaptainCompensationType CompensationType { get; set; }
        public string CompensationTypeDisplay { get; set; }
        public decimal CaptainRate { get; set; }
        public int TotalOrders { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalDeliveryFees { get; set; }
        public decimal TotalCaptainEarnings { get; set; }
        public decimal NetDueToCompany { get; set; }
        public List<CaptainOrderSettlementItemDto> Orders { get; set; } = new();
    }

    public class CaptainOrderSettlementItemDto
    {
        public int OrderId { get; set; }
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public decimal? DistanceInKm { get; set; }
        public decimal CustomerDeliveryFee { get; set; }
        public decimal OriginalDeliveryFee { get; set; }
        public decimal CaptainEarning { get; set; }
        public decimal CashCollected { get; set; }
        public decimal ProductsTotal { get; set; }
        public Modules.Orders.Entities.PaymentMethod PaymentMethod { get; set; }
        public bool IsSettled { get; set; }
        public DateTime? SettledAt { get; set; }
        public string SettlementBatchId { get; set; }
    }

    public class ConfirmCaptainSettlementRequest
    {
        [Required]
        public Guid CaptainId { get; set; }
        public List<int> OrderIds { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public string Notes { get; set; }
    }

    public class SettlementBatchReceiptDto
    {
        public string BatchId { get; set; }
        public Guid CaptainId { get; set; }
        public string CaptainName { get; set; }
        public string PhoneNumber { get; set; }
        public CaptainCompensationType CompensationType { get; set; }
        public string CompensationTypeDisplay { get; set; }
        public DateTime SettledAt { get; set; }
        public int OrdersCount { get; set; }
        public decimal TotalCashCollected { get; set; }
        public decimal TotalDeliveryFees { get; set; }
        public decimal TotalCaptainEarnings { get; set; }
        public decimal NetDueToCompany { get; set; }
        public string HandledByAdminName { get; set; }
        public string Notes { get; set; }
        public List<CaptainOrderSettlementItemDto> Orders { get; set; } = new();
    }

    public class CaptainLookupDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; }
        public string PhoneNumber { get; set; }
        public CaptainCompensationType CompensationType { get; set; }
        public decimal CaptainRate { get; set; }
    }

    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class CaptainSettlementsController : SolApiController
    {
        private readonly OrdersDbContext _ordersDb;
        private readonly AccountingDbContext _accountingDb;
        private readonly UserManager<AppUser> _userManager;
        private readonly IAdminAuditService _auditService;
        private readonly ILedgerService _ledgerService;
        private readonly INotificationService _notifications;

        public CaptainSettlementsController(
            OrdersDbContext ordersDb,
            AccountingDbContext accountingDb,
            UserManager<AppUser> userManager,
            ILedgerService ledgerService,
            INotificationService notifications = null,
            IAdminAuditService auditService = null)
        {
            _ordersDb = ordersDb ?? throw new ArgumentNullException(nameof(ordersDb));
            _accountingDb = accountingDb ?? throw new ArgumentNullException(nameof(accountingDb));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
            _ledgerService = ledgerService ?? throw new ArgumentNullException(nameof(ledgerService));
            _notifications = notifications;
            _auditService = auditService;
        }

        /// <summary>
        /// Get active delivery drivers for filter selection
        /// </summary>
        [HttpGet("Captains")]
        public async Task<ActionResult<List<CaptainLookupDto>>> GetCaptains()
        {
            var drivers = await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString());
            var list = drivers.Select(d => new CaptainLookupDto
            {
                Id = d.Id,
                Name = d.FullName ?? d.UserName,
                PhoneNumber = d.PhoneNumber,
                CompensationType = d.CaptainCompensationType,
                CaptainRate = d.CaptainRate
            }).OrderBy(d => d.Name).ToList();

            return Ok(list);
        }

        /// <summary>
        /// Get aggregate settlements summary for delivery captains filtered by date range and settlement status
        /// </summary>
        [HttpGet("Summary")]
        public async Task<ActionResult<CaptainSettlementsOverviewDto>> GetSummary(
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null,
            [FromQuery] Guid? captainId = null,
            [FromQuery] string settlementStatus = "unsettled",
            [FromQuery] string searchTerm = null)
        {
            await SyncUnpostedSettlementBatchesAsync();
            var drivers = (await _userManager.GetUsersInRoleAsync(AppRoleName.Delivery.ToString())).ToList();
            if (captainId.HasValue && captainId.Value != Guid.Empty)
            {
                drivers = drivers.Where(d => d.Id == captainId.Value).ToList();
            }

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                var term = searchTerm.Trim().ToLowerInvariant();
                drivers = drivers.Where(d =>
                    (d.FullName != null && d.FullName.ToLowerInvariant().Contains(term)) ||
                    (d.UserName != null && d.UserName.ToLowerInvariant().Contains(term)) ||
                    (d.PhoneNumber != null && d.PhoneNumber.Contains(term))).ToList();
            }

            var driverIds = drivers.Select(d => d.Id).ToList();

            var query = _ordersDb.Set<Order>()
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveredAt != null &&
                            o.DeliveryId.HasValue &&
                            driverIds.Contains(o.DeliveryId.Value));

            if (fromDate.HasValue)
            {
                query = query.Where(o => o.DeliveredAt >= fromDate.Value);
            }

            if (toDate.HasValue)
            {
                var endOfDay = toDate.Value.Date.AddDays(1).AddTicks(-1);
                query = query.Where(o => o.DeliveredAt <= endOfDay);
            }

            var orders = await query.ToListAsync();

            var items = new List<CaptainSettlementItemDto>();

            foreach (var driver in drivers)
            {
                var driverOrders = orders.Where(o => o.DeliveryId == driver.Id).ToList();

                var totalCount = driverOrders.Count;
                var unsettledOrders = driverOrders.Where(o => !o.IsSettled).ToList();
                var settledOrders = driverOrders.Where(o => o.IsSettled).ToList();

                // Apply settlementStatus filter
                var filterKey = (settlementStatus ?? "all").ToLowerInvariant();
                if (filterKey == "unsettled" && unsettledOrders.Count == 0 && totalCount > 0)
                {
                    continue;
                }
                if (filterKey == "settled" && settledOrders.Count == 0 && totalCount > 0)
                {
                    continue;
                }
                if ((filterKey == "unsettled" || filterKey == "settled") && totalCount == 0)
                {
                    continue;
                }

                var relevantOrders = filterKey switch
                {
                    "unsettled" => unsettledOrders,
                    "settled" => settledOrders,
                    _ => driverOrders
                };

                var cashCollected = relevantOrders.Sum(o => CalculateCashCollected(o));
                var deliveryFees = relevantOrders.Sum(o => o.DeliveryFee);
                var captainEarnings = relevantOrders.Sum(o => CalculateCaptainEarning(o));
                var netDueToCompany = cashCollected - captainEarnings;

                var lastSettled = settledOrders.OrderByDescending(o => o.SettledAt).FirstOrDefault();

                string status;
                if (totalCount == 0)
                {
                    status = "NoOrders";
                }
                else if (unsettledOrders.Count == 0)
                {
                    status = "Settled";
                }
                else
                {
                    status = "Unsettled";
                }

                items.Add(new CaptainSettlementItemDto
                {
                    CaptainId = driver.Id,
                    CaptainName = driver.FullName ?? driver.UserName,
                    PhoneNumber = driver.PhoneNumber,
                    CompensationType = driver.CaptainCompensationType,
                    CompensationTypeDisplay = FormatCompensationDisplay(driver.CaptainCompensationType, driver.CaptainRate),
                    CaptainRate = driver.CaptainRate,
                    CompletedOrdersCount = relevantOrders.Count,
                    TotalCashCollected = cashCollected,
                    TotalDeliveryFees = deliveryFees,
                    TotalCaptainEarnings = captainEarnings,
                    NetDueToCompany = netDueToCompany,
                    UnsettledOrdersCount = unsettledOrders.Count,
                    SettledOrdersCount = settledOrders.Count,
                    SettlementStatus = status,
                    LastSettledAt = lastSettled?.SettledAt,
                    LastSettlementBatchId = lastSettled?.SettlementBatchId
                });
            }

            var overview = new CaptainSettlementsOverviewDto
            {
                TotalOrders = items.Sum(i => i.CompletedOrdersCount),
                TotalCashCollected = items.Sum(i => i.TotalCashCollected),
                TotalDeliveryFees = items.Sum(i => i.TotalDeliveryFees),
                TotalCaptainEarnings = items.Sum(i => i.TotalCaptainEarnings),
                TotalNetDueToCompany = items.Sum(i => i.NetDueToCompany),
                Items = items.OrderByDescending(i => i.NetDueToCompany).ToList()
            };

            return Ok(overview);
        }

        /// <summary>
        /// Get detailed orders list for a captain within the period with fee breakdown
        /// </summary>
        [HttpGet("Captain/{captainId}/Orders")]
        public async Task<ActionResult<CaptainOrdersSettlementDetailDto>> GetCaptainOrders(
            Guid captainId,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null,
            [FromQuery] string settlementStatus = "all")
        {
            var driver = await _userManager.FindByIdAsync(captainId.ToString());
            if (driver == null)
            {
                return NotFound(ApiErr.Create("الكابتن غير موجود"));
            }

            var query = _ordersDb.Set<Order>()
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveredAt != null && o.DeliveryId == captainId);

            if (fromDate.HasValue)
            {
                query = query.Where(o => o.DeliveredAt >= fromDate.Value);
            }

            if (toDate.HasValue)
            {
                var endOfDay = toDate.Value.Date.AddDays(1).AddTicks(-1);
                query = query.Where(o => o.DeliveredAt <= endOfDay);
            }

            var filterKey = (settlementStatus ?? "all").ToLowerInvariant();
            if (filterKey == "unsettled")
            {
                query = query.Where(o => !o.IsSettled);
            }
            else if (filterKey == "settled")
            {
                query = query.Where(o => o.IsSettled);
            }

            var orders = await query.OrderByDescending(o => o.DeliveredAt).ToListAsync();

            var orderItems = orders.Select(o => new CaptainOrderSettlementItemDto
            {
                OrderId = o.Id,
                CustomerName = o.User ?? "زبون",
                CustomerPhone = o.Phonenumber,
                DeliveredAt = o.DeliveredAt,
                DistanceInKm = o.DistanceInKm,
                CustomerDeliveryFee = o.DeliveryFee,
                OriginalDeliveryFee = o.OriginalDeliveryFee ?? o.DeliveryFee,
                CaptainEarning = CalculateCaptainEarning(o),
                CashCollected = CalculateCashCollected(o),
                ProductsTotal = CalculateProductsTotal(o),
                PaymentMethod = o.PaymentMethod,
                IsSettled = o.IsSettled,
                SettledAt = o.SettledAt,
                SettlementBatchId = o.SettlementBatchId
            }).ToList();

            var cashCollected = orderItems.Sum(o => o.CashCollected);
            var deliveryFees = orderItems.Sum(o => o.CustomerDeliveryFee);
            var captainEarnings = orderItems.Sum(o => o.CaptainEarning);

            var detail = new CaptainOrdersSettlementDetailDto
            {
                CaptainId = driver.Id,
                CaptainName = driver.FullName ?? driver.UserName,
                PhoneNumber = driver.PhoneNumber,
                CompensationType = driver.CaptainCompensationType,
                CompensationTypeDisplay = FormatCompensationDisplay(driver.CaptainCompensationType, driver.CaptainRate),
                CaptainRate = driver.CaptainRate,
                TotalOrders = orderItems.Count,
                TotalCashCollected = cashCollected,
                TotalDeliveryFees = deliveryFees,
                TotalCaptainEarnings = captainEarnings,
                NetDueToCompany = cashCollected - captainEarnings,
                Orders = orderItems
            };

            return Ok(detail);
        }

        /// <summary>
        /// Confirm settlement for captain orders, locking them with a unique settlement batch ID
        /// </summary>
        [HttpPost("ConfirmSettlement")]
        public async Task<ActionResult<SettlementBatchReceiptDto>> ConfirmSettlement([FromBody] ConfirmCaptainSettlementRequest request)
        {
            if (request == null || request.CaptainId == Guid.Empty)
            {
                return BadRequest(ApiErr.Create("يجب تحديد الكابتن لإتمام التسوية"));
            }

            var driver = await _userManager.FindByIdAsync(request.CaptainId.ToString());
            if (driver == null)
            {
                return NotFound(ApiErr.Create("الكابتن غير موجود"));
            }

            var adminId = User.GetUserId() ?? Guid.Empty;
            var adminUser = await _userManager.FindByIdAsync(adminId.ToString());
            var adminName = adminUser?.FullName ?? adminUser?.UserName ?? "مسؤول النظام";

            var query = _ordersDb.Set<Order>()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveryId == request.CaptainId && o.DeliveredAt != null && !o.IsSettled);

            if (request.OrderIds != null && request.OrderIds.Count > 0)
            {
                query = query.Where(o => request.OrderIds.Contains(o.Id));
            }
            else
            {
                if (request.FromDate.HasValue)
                {
                    query = query.Where(o => o.DeliveredAt >= request.FromDate.Value);
                }
                if (request.ToDate.HasValue)
                {
                    var endOfDay = request.ToDate.Value.Date.AddDays(1).AddTicks(-1);
                    query = query.Where(o => o.DeliveredAt <= endOfDay);
                }
            }

            var orders = await query.ToListAsync();
            if (orders.Count == 0)
            {
                return BadRequest(ApiErr.Create("لا توجد طلبات غير مسوّاة للكابتن في هذه الفترة المحددة."));
            }

            var nowUtc = DateTime.UtcNow;
            var batchCode = $"SETTLE-{driver.Id.ToString()[..8].ToUpperInvariant()}-{nowUtc:yyyyMMddHHmmss}";

            var totalCashCollected = orders.Sum(o => CalculateCashCollected(o));
            var totalDeliveryFees = orders.Sum(o => o.DeliveryFee);
            var totalCaptainEarnings = orders.Sum(o => CalculateCaptainEarning(o));
            var wagesToOffset = Math.Min(totalCashCollected, totalCaptainEarnings);
            var netDueToCompany = totalCashCollected - wagesToOffset;

            foreach (var order in orders)
            {
                order.IsSettled = true;
                order.SettledAt = nowUtc;
                order.SettlementBatchId = batchCode;
            }

            // 1. Post double-entry accounting ledger transaction
            Guid settlementTxnId = Guid.Empty;
            if (totalCashCollected > 0 || totalCaptainEarnings > 0)
            {
                var floatAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                    request.CaptainId,
                    AccountType.Asset,
                    SystemAccountCodes.CaptainCashFloatPrefix,
                    $"Cash Float - {driver.FullName ?? driver.UserName}",
                    "SYP");

                var wagesAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                    request.CaptainId,
                    AccountType.Liability,
                    SystemAccountCodes.CaptainEarningsPrefix,
                    $"Earnings - {driver.FullName ?? driver.UserName}",
                    "SYP");

                var vaultAcc = await _ledgerService.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault",
                    AccountType.Asset,
                    "SYP");

                var txnRequest = new PostTransactionRequest
                {
                    ReferenceType = "CaptainSettlement",
                    ReferenceId = batchCode,
                    IdempotencyKey = $"SettlementBatch-{batchCode}",
                    Description = $"تسوية وردية الكابتن {driver.FullName ?? driver.UserName} - دفعة {batchCode}",
                    Entries = new List<PostLedgerEntryRequest>()
                };

                if (netDueToCompany > 0)
                {
                    txnRequest.Entries.Add(new PostLedgerEntryRequest
                    {
                        AccountId = vaultAcc.Id,
                        Debit = netDueToCompany,
                        Credit = 0m,
                        Currency = "SYP",
                        Memo = $"توريد نقدي لخزينة الشركة من الكابتن {driver.FullName ?? driver.UserName} - تسوية {batchCode}"
                    });
                }

                if (wagesToOffset > 0)
                {
                    txnRequest.Entries.Add(new PostLedgerEntryRequest
                    {
                        AccountId = wagesAcc.Id,
                        Debit = wagesToOffset,
                        Credit = 0m,
                        Currency = "SYP",
                        Memo = $"اقتطاع مستحقات توصيل الكابتن {driver.FullName ?? driver.UserName} من العهدة - تسوية {batchCode}"
                    });
                }

                if (totalCashCollected > 0)
                {
                    txnRequest.Entries.Add(new PostLedgerEntryRequest
                    {
                        AccountId = floatAcc.Id,
                        Debit = 0m,
                        Credit = totalCashCollected,
                        Currency = "SYP",
                        Memo = $"تفريغ وتسوية عهدة الكابتن {driver.FullName ?? driver.UserName} - تسوية {batchCode}"
                    });
                }

                if (txnRequest.Entries.Count > 0)
                {
                    var txnDto = await _ledgerService.PostTransactionAsync(txnRequest);
                    settlementTxnId = txnDto.Id;
                }
            }

            // 2. Record payment in Payments table so it appears in driver's payment history
            var payment = new Payment
            {
                ByUserId = request.CaptainId,
                ByUser = driver.FullName ?? driver.UserName,
                ToUserId = adminId != Guid.Empty ? adminId : Guid.NewGuid(),
                ToUser = adminName,
                Amount = netDueToCompany > 0 ? netDueToCompany : totalCashCollected,
                NewBalance = 0m,
                HandoverDate = nowUtc
            };
            _accountingDb.Payments.Add(payment);

            // 3. Create persistent DailySettlementBatch
            var batch = new DailySettlementBatch
            {
                Id = Guid.NewGuid(),
                BatchCode = batchCode,
                CaptainUserId = request.CaptainId,
                BatchDate = nowUtc,
                TotalCashCollected = totalCashCollected,
                TotalWagesEarned = totalCaptainEarnings,
                NetCashRemitted = netDueToCompany,
                HandledByAdminId = adminId,
                SettlementTransactionId = settlementTxnId != Guid.Empty ? settlementTxnId : Guid.NewGuid(),
                IsLocked = true,
                Notes = request.Notes ?? $"تسوية عدد {orders.Count} طلب للكابتن {driver.FullName ?? driver.UserName}"
            };

            _accountingDb.DailySettlementBatches.Add(batch);

            await _ordersDb.SaveChangesAsync();
            await _accountingDb.SaveChangesAsync();

            // 4. Send realtime push notification to driver app
            if (_notifications != null)
            {
                try
                {
                    await _notifications.SendSettlementCompleted(
                        new[] { driver.Id },
                        batchCode,
                        totalCashCollected > 0 ? totalCashCollected : netDueToCompany);
                }
                catch
                {
                    // Notification push should never fail the settlement
                }
            }

            var receipt = new SettlementBatchReceiptDto
            {
                BatchId = batchCode,
                CaptainId = driver.Id,
                CaptainName = driver.FullName ?? driver.UserName,
                PhoneNumber = driver.PhoneNumber,
                CompensationType = driver.CaptainCompensationType,
                CompensationTypeDisplay = FormatCompensationDisplay(driver.CaptainCompensationType, driver.CaptainRate),
                SettledAt = nowUtc,
                OrdersCount = orders.Count,
                TotalCashCollected = totalCashCollected,
                TotalDeliveryFees = totalDeliveryFees,
                TotalCaptainEarnings = totalCaptainEarnings,
                NetDueToCompany = netDueToCompany,
                HandledByAdminName = adminName,
                Notes = batch.Notes,
                Orders = orders.Select(o => new CaptainOrderSettlementItemDto
                {
                    OrderId = o.Id,
                    CustomerName = o.User ?? "زبون",
                    CustomerPhone = o.Phonenumber,
                    DeliveredAt = o.DeliveredAt,
                    DistanceInKm = o.DistanceInKm,
                    CustomerDeliveryFee = o.DeliveryFee,
                    OriginalDeliveryFee = o.OriginalDeliveryFee ?? o.DeliveryFee,
                    CaptainEarning = CalculateCaptainEarning(o),
                    CashCollected = CalculateCashCollected(o),
                    ProductsTotal = CalculateProductsTotal(o),
                    PaymentMethod = o.PaymentMethod,
                    IsSettled = true,
                    SettledAt = nowUtc,
                    SettlementBatchId = batchCode
                }).ToList()
            };

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Settlements",
                    Action = "ConfirmCaptainSettlement",
                    EntityType = "CaptainSettlementBatch",
                    EntityId = batchCode,
                    Description = $"اعتماد تسوية الكابتن {driver.FullName ?? driver.UserName} بعدد {orders.Count} طلب بمبلغ صافي {netDueToCompany:N0} ل.س",
                    Result = "Success",
                    AfterState = receipt
                });
            }

            return Ok(receipt);
        }

        /// <summary>
        /// Get printable receipt for a settlement batch
        /// </summary>
        [HttpGet("Batches/{batchCode}")]
        public async Task<ActionResult<SettlementBatchReceiptDto>> GetBatchReceipt(string batchCode)
        {
            if (string.IsNullOrWhiteSpace(batchCode))
            {
                return BadRequest(ApiErr.Create("يجب تحديد رقم الدفعة"));
            }

            var batch = await _accountingDb.DailySettlementBatches
                .FirstOrDefaultAsync(b => b.BatchCode == batchCode);

            var orders = await _ordersDb.Set<Order>()
                .AsNoTracking()
                .Include(o => o.OrderDetails)
                .Where(o => o.SettlementBatchId == batchCode)
                .OrderBy(o => o.DeliveredAt)
                .ToListAsync();

            if (batch == null && orders.Count == 0)
            {
                return NotFound(ApiErr.Create("دفعة التسوية غير موجودة"));
            }

            var captainId = batch?.CaptainUserId ?? orders.FirstOrDefault()?.DeliveryId ?? Guid.Empty;
            var driver = await _userManager.FindByIdAsync(captainId.ToString());
            var adminId = batch?.HandledByAdminId ?? Guid.Empty;
            var admin = adminId != Guid.Empty ? await _userManager.FindByIdAsync(adminId.ToString()) : null;

            var cashCollected = batch?.TotalCashCollected ?? orders.Sum(o => CalculateCashCollected(o));
            var captainEarnings = batch?.TotalWagesEarned ?? orders.Sum(o => CalculateCaptainEarning(o));
            var deliveryFees = orders.Sum(o => o.DeliveryFee);
            var netDue = batch?.NetCashRemitted ?? (cashCollected - captainEarnings);

            var receipt = new SettlementBatchReceiptDto
            {
                BatchId = batchCode,
                CaptainId = captainId,
                CaptainName = driver?.FullName ?? driver?.UserName ?? "كابتن",
                PhoneNumber = driver?.PhoneNumber,
                CompensationType = driver?.CaptainCompensationType ?? CaptainCompensationType.SalariedEmployee,
                CompensationTypeDisplay = driver != null ? FormatCompensationDisplay(driver.CaptainCompensationType, driver.CaptainRate) : "غير محدد",
                SettledAt = batch?.BatchDate ?? orders.FirstOrDefault()?.SettledAt ?? DateTime.UtcNow,
                OrdersCount = orders.Count,
                TotalCashCollected = cashCollected,
                TotalDeliveryFees = deliveryFees,
                TotalCaptainEarnings = captainEarnings,
                NetDueToCompany = netDue,
                HandledByAdminName = admin?.FullName ?? admin?.UserName ?? "مسؤول النظام",
                Notes = batch?.Notes,
                Orders = orders.Select(o => new CaptainOrderSettlementItemDto
                {
                    OrderId = o.Id,
                    CustomerName = o.User ?? "زبون",
                    CustomerPhone = o.Phonenumber,
                    DeliveredAt = o.DeliveredAt,
                    DistanceInKm = o.DistanceInKm,
                    CustomerDeliveryFee = o.DeliveryFee,
                    OriginalDeliveryFee = o.OriginalDeliveryFee ?? o.DeliveryFee,
                    CaptainEarning = CalculateCaptainEarning(o),
                    CashCollected = CalculateCashCollected(o),
                    ProductsTotal = CalculateProductsTotal(o),
                    PaymentMethod = o.PaymentMethod,
                    IsSettled = o.IsSettled,
                    SettledAt = o.SettledAt,
                    SettlementBatchId = o.SettlementBatchId
                }).ToList()
            };

            return Ok(receipt);
        }

        private static decimal CalculateCashCollected(Order order)
        {
            if (order.ActualCashCollected.HasValue && order.ActualCashCollected.Value >= 0)
            {
                return order.ActualCashCollected.Value;
            }

            if (order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery)
            {
                var products = order.OrderDetails != null && order.OrderDetails.Count > 0
                    ? order.OrderDetails
                        .Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                        .Sum(d => d.Quantity * (d.SingleFinalPrice > 0 ? d.SingleFinalPrice : d.SinglePrice))
                    : 0m;

                return products + order.DeliveryFee;
            }

            return 0m;
        }

        private static decimal CalculateProductsTotal(Order order)
        {
            if (order.OrderDetails != null && order.OrderDetails.Count > 0)
            {
                return order.OrderDetails
                    .Where(d => d.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                                d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                                d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled)
                    .Sum(d => d.Quantity * (d.SingleFinalPrice > 0 ? d.SingleFinalPrice : d.SinglePrice));
            }
            return 0m;
        }

        private static decimal CalculateCaptainEarning(Order order)
        {
            if (order.CaptainCompensationType == CaptainCompensationType.SalariedEmployee)
            {
                return 0m;
            }
            return order.CaptainEarning;
        }

        private static string FormatCompensationDisplay(CaptainCompensationType type, decimal rate)
        {
            return type switch
            {
                CaptainCompensationType.SalariedEmployee => "موظف براتب شهري",
                CaptainCompensationType.PerKilometer => $"{rate:N0} ل.س / كم",
                CaptainCompensationType.Percentage => $"{rate:N0}% من التوصيل",
                _ => "غير محدد"
            };
        }
    
        /// <summary>
        /// Explicit endpoint to re-sync unposted legacy batches into double-entry ledger
        /// </summary>
        [HttpPost("SyncUnpostedBatches")]
        public async Task<ActionResult<int>> SyncUnpostedBatches()
        {
            var count = await SyncUnpostedSettlementBatchesAsync();
            return Ok(count);
        }

        private async Task<int> SyncUnpostedSettlementBatchesAsync()
        {
            try
            {
                var unpostedBatches = await _accountingDb.DailySettlementBatches
                    .Where(b => !_accountingDb.JournalTransactions.Any(jt => jt.Id == b.SettlementTransactionId))
                    .ToListAsync();

                if (unpostedBatches.Count == 0) return 0;

                var vaultAcc = await _ledgerService.GetOrCreateSystemAccountAsync(
                    SystemAccountCodes.CompanyMainVault,
                    "Company Cash Vault",
                    AccountType.Asset,
                    "SYP");

                int synced = 0;
                foreach (var batch in unpostedBatches)
                {
                    try
                    {
                        var driver = await _userManager.FindByIdAsync(batch.CaptainUserId.ToString());
                        var driverName = driver?.FullName ?? driver?.UserName ?? $"الكابتن {batch.CaptainUserId}";

                        var wagesToOffset = Math.Min(batch.TotalCashCollected, batch.TotalWagesEarned);
                        var netDueToCompany = batch.NetCashRemitted > 0 ? batch.NetCashRemitted : (batch.TotalCashCollected - wagesToOffset);

                        var floatAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                            batch.CaptainUserId,
                            AccountType.Asset,
                            SystemAccountCodes.CaptainCashFloatPrefix,
                            $"Cash Float - {driverName}",
                            "SYP");

                        var wagesAcc = await _ledgerService.GetOrCreateUserAccountAsync(
                            batch.CaptainUserId,
                            AccountType.Liability,
                            SystemAccountCodes.CaptainEarningsPrefix,
                            $"Earnings - {driverName}",
                            "SYP");

                        var txnRequest = new PostTransactionRequest
                        {
                            ReferenceType = "CaptainSettlement",
                            ReferenceId = batch.BatchCode,
                            IdempotencyKey = $"SettlementBatch-{batch.BatchCode}",
                            Description = $"تسوية وردية الكابتن {driverName} - دفعة {batch.BatchCode} - مزامنة تلقائية",
                            Entries = new List<PostLedgerEntryRequest>()
                        };

                        if (netDueToCompany > 0)
                        {
                            txnRequest.Entries.Add(new PostLedgerEntryRequest
                            {
                                AccountId = vaultAcc.Id,
                                Debit = netDueToCompany,
                                Credit = 0m,
                                Currency = "SYP",
                                Memo = $"توريد نقدي لخزينة الشركة من الكابتن {driverName} - تسوية {batch.BatchCode}"
                            });
                        }

                        if (wagesToOffset > 0)
                        {
                            txnRequest.Entries.Add(new PostLedgerEntryRequest
                            {
                                AccountId = wagesAcc.Id,
                                Debit = wagesToOffset,
                                Credit = 0m,
                                Currency = "SYP",
                                Memo = $"اقتطاع مستحقات توصيل الكابتن {driverName} من العهدة - تسوية {batch.BatchCode}"
                            });
                        }

                        if (batch.TotalCashCollected > 0)
                        {
                            txnRequest.Entries.Add(new PostLedgerEntryRequest
                            {
                                AccountId = floatAcc.Id,
                                Debit = 0m,
                                Credit = batch.TotalCashCollected,
                                Currency = "SYP",
                                Memo = $"تفريغ وتسوية عهدة الكابتن {driverName} - تسوية {batch.BatchCode}"
                            });
                        }

                        if (txnRequest.Entries.Count > 0)
                        {
                            var txnDto = await _ledgerService.PostTransactionAsync(txnRequest);
                            batch.SettlementTransactionId = txnDto.Id;
                        }

                        var hasPayment = await _accountingDb.Payments.AnyAsync(p =>
                            p.ByUserId == batch.CaptainUserId &&
                            p.Amount == (batch.NetCashRemitted > 0 ? batch.NetCashRemitted : batch.TotalCashCollected) &&
                            p.HandoverDate >= batch.BatchDate.AddMinutes(-5) &&
                            p.HandoverDate <= batch.BatchDate.AddMinutes(5));

                        if (!hasPayment)
                        {
                            var adminUser = await _userManager.FindByIdAsync(batch.HandledByAdminId.ToString());
                            var adminName = adminUser?.FullName ?? adminUser?.UserName ?? "مسؤول النظام";
                            _accountingDb.Payments.Add(new Payment
                            {
                                ByUserId = batch.CaptainUserId,
                                ByUser = driverName,
                                ToUserId = batch.HandledByAdminId != Guid.Empty ? batch.HandledByAdminId : Guid.NewGuid(),
                                ToUser = adminName,
                                Amount = batch.NetCashRemitted > 0 ? batch.NetCashRemitted : batch.TotalCashCollected,
                                NewBalance = 0m,
                                HandoverDate = batch.BatchDate
                            });
                        }

                        await _accountingDb.SaveChangesAsync();
                        synced++;

                        if (_notifications != null && driver != null)
                        {
                            try
                            {
                                await _notifications.SendSettlementCompleted(
                                    new[] { driver.Id },
                                    batch.BatchCode,
                                    batch.TotalCashCollected > 0 ? batch.TotalCashCollected : batch.NetCashRemitted);
                            }
                            catch { }
                        }
                    }
                    catch
                    {
                        // Continue with next batch
                    }
                }

                return synced;
            }
            catch
            {
                return 0;
            }
        }
}
}
