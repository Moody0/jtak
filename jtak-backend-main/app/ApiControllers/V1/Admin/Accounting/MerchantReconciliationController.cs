using App.ApiModels;
using App.Extensions;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [Route("api/v{version:apiVersion}/Admin/Reconciliation/Merchants")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class MerchantReconciliationController : SolApiController
    {
        private readonly IMerchantReconciliationService _reconciliationService;

        public MerchantReconciliationController(IMerchantReconciliationService reconciliationService)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
        }

        /// <summary>
        /// Get authoritative summary of merchant payables, reserved settlement amounts, and platform commissions
        /// </summary>
        [HttpGet("Summary")]
        public async Task<ActionResult<MerchantReconciliationSummaryDto>> GetSummary()
        {
            var result = await _reconciliationService.GetSummaryAsync();
            return Ok(result);
        }

        /// <summary>
        /// Get server-side paged and filtered merchant reconciliation table
        /// </summary>
        [HttpPost("DataTable")]
        public async Task<ActionResult<MerchantReconciliationDataTableResultDto>> GetDataTable([FromBody] MerchantReconciliationDataTableRequest request)
        {
            var result = await _reconciliationService.GetDataTableAsync(request);
            return Ok(result);
        }

        [HttpGet("DataTable")]
        public async Task<ActionResult<MerchantReconciliationDataTableResultDto>> GetDataTableGet(
            [FromQuery] string searchTerm = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortColumn = null,
            [FromQuery] string sortDirection = "ASC")
        {
            var request = new MerchantReconciliationDataTableRequest
            {
                SearchTerm = searchTerm,
                Page = page,
                PageSize = pageSize,
                SortColumn = sortColumn,
                SortDirection = sortDirection
            };
            var result = await _reconciliationService.GetDataTableAsync(request);
            return Ok(result);
        }

        /// <summary>
        /// Get detailed financial statement for a specific merchant with chronological running balance, newest-first ordering, and order traceability
        /// </summary>
        [HttpPost("{merchantId}/Statement")]
        public async Task<ActionResult<MerchantStatementDto>> GetMerchantStatement(int merchantId, [FromBody] MerchantStatementRequestDto request)
        {
            try
            {
                var result = await _reconciliationService.GetMerchantStatementAsync(merchantId, request);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        [HttpGet("{merchantId}/Statement")]
        public async Task<ActionResult<MerchantStatementDto>> GetMerchantStatementGet(
            int merchantId,
            [FromQuery] string searchTerm = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null)
        {
            try
            {
                var request = new MerchantStatementRequestDto
                {
                    SearchTerm = searchTerm,
                    Page = page,
                    PageSize = pageSize,
                    FromDate = fromDate,
                    ToDate = toDate
                };
                var result = await _reconciliationService.GetMerchantStatementAsync(merchantId, request);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }
    }
}
