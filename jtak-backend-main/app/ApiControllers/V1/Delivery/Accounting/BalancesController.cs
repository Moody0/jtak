using App.ApiModels;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using OpenIddict.Validation.AspNetCore;
using Microsoft.AspNetCore.Authorization;
using App.Shared.Entities.Enums;
using App.Extensions;
using Modules.Accounting.Services;
using Modules.Accounting.Entities;
using App.Shared.Entities;
using Microsoft.AspNetCore.Identity;
using App.Shared.Services;
using App.Shared.Services.Extentions;
using System;
using System.Linq;
using System.Collections.Generic;

namespace App.ApiControllers.V1.Delivery
{
    [Route("api/v{version:apiVersion}/Delivery/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.DeliveryPermission))]
    public class BalancesController : SolApiController
    {
        private readonly IBalanceService _service;
        private readonly ISettlementRequestService _settlements;
        private readonly UserManager<AppUser> _userManager;
        private readonly INotificationService _notifications;

        public BalancesController(IBalanceService service,
            ISettlementRequestService settlements,
            UserManager<AppUser> userManager,
            INotificationService notifications)
        {
            _service = service;
            _settlements = settlements;
            _userManager = userManager;
            _notifications = notifications;
        }


        /// <summary>
        /// Get my Balance
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        [Route("Mine")]
        public async Task<ActionResult<object>> GetMine()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var balance = await _settlements.GetCaptainBalanceAsync(uid.Value);
            var earnings = await _settlements.GetCaptainEarningsAsync(uid.Value);
            var user = await _userManager.FindByIdAsync(uid.Value.ToString());
            return Ok(new
            {
                id = uid.Value,
                amount = balance.GrossAmount,
                pendingAmount = balance.PendingAmount,
                reservedPurchaseAmount = balance.ReservedPurchaseAmount,
                hasPendingAccountingOrders = balance.HasPendingAccountingOrders,
                availableAmount = balance.AvailableAmount,
                hasPendingSettlement = balance.HasPendingRequest,
                maxCashFloat = user?.MaxCashFloat ?? 5000000m,
                currency = balance.Currency,
                custodyBalance = balance.CustodyBalance,
                wagesOffset = balance.WagesOffset,
                netCashDue = balance.NetCashDue,
                isCoveredByCustody = balance.IsCoveredByCustody,
                captainCompensationType = (int?)user?.CaptainCompensationType,
                captainRate = user?.CaptainRate,
                earnings = earnings != null ? new
                {
                    earnings.GrossAmount,
                    earnings.CustodyBalance,
                    earnings.TotalPaid,
                    earnings.TotalEarned,
                    earnings.PendingAmount,
                    earnings.AvailableAmount,
                    earnings.WagesOffset,
                    earnings.NetCashDue,
                    earnings.IsCoveredByCustody,
                    earnings.Currency,
                    earnings.HasPendingRequest,
                    earnings.HasPendingAccountingOrders,
                    earnings.Requests,
                    captainCompensationType = (int?)user?.CaptainCompensationType,
                    captainRate = user?.CaptainRate
                } : null
            });
        }

        [HttpPost]
        [Route("RequestSettlement")]
        public async Task<ActionResult<SettlementRequestDto>> RequestSettlement([FromBody] CreateSettlementRequestDto request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var user = await _userManager.GetUserAsync(User);
            try
            {
                var result = await _settlements.CreateCaptainRequestAsync(uid.Value,
                    user?.FullName ?? user?.UserName ?? "مندوب التوصيل", user?.PhoneNumber, request);
                // The reservation is committed before notification delivery.
                // A push failure must never encourage another money request.
                try {
                    var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
                    if (admins.Length > 0 && _notifications != null)
                        await _notifications.SendNewSettlementRequest(admins, result.RequestNumber, result.RequestedByName, result.Amount, false);
                } catch { /* The persisted request remains authoritative. */ }
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpGet]
        [Route("SettlementRequests")]
        public async Task<ActionResult<List<SettlementRequestDto>>> SettlementRequests()
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            return Ok(await _settlements.GetMineAsync(uid.Value, SettlementPartyType.Captain));
        }

        [HttpPost("RequestEarningsPayout")]
        public async Task<ActionResult<SettlementRequestDto>> RequestEarningsPayout([FromBody] CreateSettlementRequestDto request)
        {
            var uid = User.GetUserId();
            if (!uid.HasValue) return Unauthorized();
            var user = await _userManager.GetUserAsync(User);
            try
            {
                var result = await _settlements.CreateCaptainEarningsRequestAsync(uid.Value,
                    user?.FullName ?? user?.UserName ?? "مندوب التوصيل", user?.PhoneNumber, request);
                // The request is already committed: a push failure must not
                // report financial failure and encourage duplicate submissions.
                try
                {
                    var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString()))
                        .Where(x => x.IsActive).Select(x => x.Id).ToArray();
                    if (admins.Length > 0 && _notifications != null)
                        await _notifications.SendNewSettlementRequest(admins, result.RequestNumber,
                            result.RequestedByName, result.Amount, false, true);
                }
                catch { /* Persisted request remains authoritative. */ }
                return Ok(result);
            }
            catch (InvalidOperationException ex) { return BadRequest(ApiErr.Create(ex.Message)); }
        }
    }
}
