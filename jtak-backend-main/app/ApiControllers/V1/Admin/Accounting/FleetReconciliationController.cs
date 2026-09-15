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

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class FleetReconciliationController : SolApiController
    {
        private readonly IEodReconciliationService _reconciliationService;
        private readonly UserManager<AppUser> _userManager;

        public FleetReconciliationController(
            IEodReconciliationService reconciliationService,
            UserManager<AppUser> userManager)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
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
            await Task.CompletedTask;
            return BadRequest(ApiErr.Create("يجب أن يرسل المندوب طلب تسوية أولاً، ثم يتم قبوله من قائمة طلبات التسوية."));
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
    }
}
