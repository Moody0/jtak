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

namespace App.ApiControllers.V1.Admin
{
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
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
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

        public FleetReconciliationController(
            IEodReconciliationService reconciliationService,
            UserManager<AppUser> userManager,
            IOrderService orderService,
            IBillService billService,
            IMerchantService merchantService,
            ILedgerService ledgerService,
            IBalanceService balanceService,
            AccountingDbContext accountingDb)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
            _orderService = orderService;
            _billService = billService;
            _merchantService = merchantService;
            _ledgerService = ledgerService;
            _balanceService = balanceService;
            _accountingDb = accountingDb;
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
                return Ok(result);
            }
            catch (Exception ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
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
