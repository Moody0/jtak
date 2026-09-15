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
            return Ok(new
            {
                id = uid.Value,
                amount = balance.GrossAmount,
                pendingAmount = balance.PendingAmount,
                availableAmount = balance.AvailableAmount,
                hasPendingSettlement = balance.HasPendingRequest,
                maxCashFloat = 500000m,
                currency = balance.Currency
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
                var admins = (await _userManager.GetUsersInRoleAsync(AppRoleName.Admin.ToString())).Where(x => x.IsActive).Select(x => x.Id).ToArray();
                if (admins.Length > 0)
                    await _notifications.SendNewSettlementRequest(admins, result.RequestNumber, result.RequestedByName, result.Amount, false);
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
    }
}
