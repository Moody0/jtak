using App.ApiModels;
using App.Extensions;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

using Modules.Accounting.Data;
using Modules.Orders.Services;
using Modules.Shipping.Services;
using Modules.Catalog.Services;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using App.Shared.Services;
using Microsoft.Extensions.Configuration;
using App.Orders.Data;
using Modules.Orders.Entities;

namespace App.ApiControllers.V1.Admin
{
    public class CaptainDeliveredOrderItemDto
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

    public class DeliveredOrderReconciliationSummaryDto
    {
        public int TotalDeliveredOrdersEvaluated { get; set; }
        public int AlreadyReconciledCount { get; set; }
        public int RecoveredSplitsCount { get; set; }
        public List<int> RecoveredOrderIds { get; set; } = new List<int>();
        public List<string> Errors { get; set; } = new List<string>();
    }

    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    public class FleetReconciliationController : SolApiController
    {
        private readonly IEodReconciliationService _reconciliationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IOrderService _orderService;
        private readonly IBillService _billService;
        private readonly IMerchantService _merchantService;
        private readonly ILedgerService _ledgerService;
        private readonly IBalanceService _balanceService;
        private readonly AccountingDbContext _accountingDb;
        private readonly OrdersDbContext _ordersDb;
        private readonly IAdminAuditService _auditService;
        private readonly IConfiguration _configuration;

        public FleetReconciliationController(
            IEodReconciliationService reconciliationService,
            UserManager<AppUser> userManager,
            IOrderService orderService,
            IBillService billService,
            IMerchantService merchantService,
            ILedgerService ledgerService,
            IBalanceService balanceService,
            AccountingDbContext accountingDb,
            OrdersDbContext ordersDb = null,
            IAdminAuditService auditService = null,
            IConfiguration configuration = null)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
            _orderService = orderService;
            _billService = billService;
            _merchantService = merchantService;
            _ledgerService = ledgerService;
            _balanceService = balanceService;
            _accountingDb = accountingDb;
            _ordersDb = ordersDb;
            _auditService = auditService;
            _configuration = configuration;
        }

        /// <summary>
        /// Get real-time EOD financial position for all delivery fleet captains
        /// </summary>
        [HttpGet("Captains")]
        public async Task<ActionResult<List<CaptainSettlementSummaryDto>>> GetCaptains()
        {
            var result = await _reconciliationService.GetFleetSettlementSummariesAsync();
            return Ok(result);
        }

        /// <summary>
        /// Get shift details and ledger statement for a specific captain
        /// </summary>
        [HttpGet("Captain/{captainId}/Statement")]
        public async Task<ActionResult<CaptainShiftDetailsDto>> GetCaptainStatement(Guid captainId)
        {
            var result = await _reconciliationService.GetCaptainShiftDetailsAsync(captainId);
            return Ok(result);
        }

        /// <summary>
        /// Get delivered orders breakdown for a specific captain
        /// </summary>
        [HttpGet("Captain/{captainId}/Orders")]
        public async Task<ActionResult<List<CaptainDeliveredOrderItemDto>>> GetCaptainOrders(
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

            var query = (_ordersDb != null ? _ordersDb.Set<Order>() : _orderService.Queryable())
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

            var orderItems = orders.Select(o => new CaptainDeliveredOrderItemDto
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

            return Ok(orderItems);
        }

        /// <summary>
        /// Execute EOD shift cash settlement for a courier (clears float, pays wages, records discrepancy)
        /// </summary>
        [HttpPost("Settle")]
        public async Task<ActionResult<SettlementResultDto>> SettleShift([FromBody] SettleCaptainShiftRequest request)
        {
            var adminId = User.GetUserId();
            if (!adminId.HasValue) return Unauthorized();
            if (request == null || request.CaptainUserId == Guid.Empty)
                return BadRequest(ApiErr.Create("يجب تحديد الكابتن والمبلغ المستلم."));

            try
            {
                var result = await _reconciliationService.SettleCaptainShiftAsync(request, adminId.Value);

                // Automatically link and stamp unsettled delivered orders for this captain with the settlement batch
                if (_ordersDb != null && result != null && !string.IsNullOrWhiteSpace(result.BatchCode))
                {
                    try
                    {
                        var unsettledOrders = await _ordersDb.Set<Order>()
                            .Where(o => o.DeliveryId == request.CaptainUserId && o.DeliveredAt != null && !o.IsSettled)
                            .ToListAsync();

                        if (unsettledOrders.Count > 0)
                        {
                            var nowUtc = DateTime.UtcNow;
                            foreach (var o in unsettledOrders)
                            {
                                o.IsSettled = true;
                                o.SettledAt = nowUtc;
                                o.SettlementBatchId = result.BatchCode;
                            }
                            await _ordersDb.SaveChangesAsync();
                        }
                    }
                    catch
                    {
                        // Stamping orders is best-effort and must not fail completed settlement
                    }
                }

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "CaptainRemittance",
                        EntityType = "CaptainShift",
                        EntityId = request.CaptainUserId.ToString(),
                        Description = $"تسوية عهدة كابتن {request.CaptainUserId} بمبلغ نقدي {request.PhysicalCashReceived:N0} ل.س (رقم الدفعة #{result?.BatchCode})",
                        Result = "Success",
                        AfterState = result
                    });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Settlements",
                        Action = "CaptainRemittance",
                        EntityType = "CaptainShift",
                        EntityId = request.CaptainUserId.ToString(),
                        Description = $"فشل تسوية عهدة كابتن {request.CaptainUserId}",
                        Result = "Failed",
                        FailureReason = ex.Message
                    });
                }
                return BadRequest(ApiErr.Create(ex.Message));
            }
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

        /// <summary>
        /// Get historical EOD settlement batches
        /// </summary>
        [HttpGet("History")]
        public async Task<ActionResult<List<DailySettlementBatchDto>>> GetHistory([FromQuery] int count = 50)
        {
            var result = await _reconciliationService.GetSettlementHistoryAsync(count);
            return Ok(result);
        }

        /// <summary>
        /// Durable recovery endpoint: Reconciles unposted/failed order splits for delivered orders using deterministic idempotency keys
        /// </summary>
        [HttpPost("ReconcileDeliveredOrders")]
        public async Task<ActionResult<DeliveredOrderReconciliationSummaryDto>> ReconcileDeliveredOrders([FromQuery] int lookbackDays = 30)
        {
            var enableLegacy = _configuration?.GetValue<bool>("Features:EnableLegacyReconciliation") ?? false;
            if (!enableLegacy)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiErr.Create("Manual order reconciliation is paused pending canonical money contract rollout. Set Features:EnableLegacyReconciliation to true to bypass."));
            }

            var cutoff = DateTime.UtcNow.AddDays(-Math.Abs(lookbackDays));
            var deliveredOrders = await _orderService.Queryable()
                .Include(o => o.OrderDetails)
                .Where(o => o.DeliveredAt != null && o.DeliveredAt >= cutoff)
                .ToListAsync();

            var summary = new DeliveredOrderReconciliationSummaryDto
            {
                TotalDeliveredOrdersEvaluated = deliveredOrders.Count
            };

            foreach (var order in deliveredOrders)
            {
                var idempotencyKey = $"OrderDelivered-{order.Id}";
                var existingTxn = await _accountingDb.JournalTransactions
                    .AnyAsync(t => t.IdempotencyKey == idempotencyKey);

                if (existingTxn)
                {
                    summary.AlreadyReconciledCount++;
                    continue;
                }

                try
                {
                    var bills = await _billService.Queryable().Where(x => x.OrderId == order.Id).ToArrayAsync();
                    if (bills.Length == 0)
                    {
                        summary.Errors.Add($"Order #{order.Id} has no billing records.");
                        continue;
                    }

                    var isCod = order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery;
                    bool isCompanyCash = false;
                    Guid captainUserId = order.DeliveryId ?? Guid.Empty;
                    string captainName = order.DeliveryUser ?? "Unassigned";

                    if (isCod && (!order.DeliveryId.HasValue || order.DeliveryId.Value == Guid.Empty))
                    {
                        isCompanyCash = true;
                        captainUserId = Guid.Empty;
                        captainName = "Company Cash Vault";
                    }

                    var merchantSplits = new List<MerchantSplitItem>();
                    foreach (var b in bills)
                    {
                        var m = await _merchantService.FindAsync(b.MerchantId);
                        merchantSplits.Add(new MerchantSplitItem
                        {
                            MerchantId = b.MerchantId,
                            MerchantTitle = m?.Title ?? $"Merchant #{b.MerchantId}",
                            TotalAmount = b.TotalAmount,
                            MerchantAmount = b.MerchantAmount,
                            PlatformCommission = b.JTakAmount,
                            IsPlatformOwned = m?.MerchantKind == App.Shared.Entities.Enums.MerchantKind.DarkStore,
                            CaptainEarningAmount = b.JTakAdditionalAmount
                        });
                    }

                    var splitReq = new OrderDeliveredSplitRequest
                    {
                        OrderId = order.Id,
                        CaptainUserId = captainUserId,
                        CaptainName = captainName,
                        DeliveryFee = bills.Sum(x => x.JTakAdditionalAmount),
                        TotalsIncludeDeliveryFee = true,
                        Currency = "SYP",
                        IsCod = isCod,
                        IsCompanyCash = isCompanyCash,
                        MerchantSplits = merchantSplits
                    };

                    await _ledgerService.PostOrderDeliveredSplitAsync(splitReq);

                    foreach (var b in bills)
                    {
                        if (!b.IsAddedToDues)
                        {
                            b.IsAddedToDues = true;
                            _billService.Update(b);
                        }
                    }

                    if (isCod && !isCompanyCash && captainUserId != Guid.Empty)
                    {
                        var recivedAmount = bills.Where(x => x.PaymentMethod == 0).Sum(x => x.TotalAmount);
                        if (recivedAmount > 0)
                        {
                            await _balanceService.IncreaseAppBalance(captainUserId, recivedAmount, captainName);
                        }
                    }

                    summary.RecoveredSplitsCount++;
                    summary.RecoveredOrderIds.Add(order.Id);
                }
                catch (Exception ex)
                {
                    summary.Errors.Add($"Order #{order.Id}: {ex.Message}");
                }
            }

            return Ok(summary);
        }
    }
}
