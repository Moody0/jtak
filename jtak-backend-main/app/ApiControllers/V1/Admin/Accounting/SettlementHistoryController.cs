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
using System.Collections.Generic;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [Route("api/v{version:apiVersion}/Admin/Reconciliation/History")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class SettlementHistoryController : SolApiController
    {
        private readonly ISettlementHistoryService _service;

        public SettlementHistoryController(ISettlementHistoryService service)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
        }

        /// <summary>
        /// Get server-side filtered, searched, and paged settlement payment history (POST)
        /// </summary>
        [HttpPost("DataTable")]
        public async Task<ActionResult<SettlementHistoryDataTableResultDto>> GetDataTable([FromBody] SettlementHistoryDataTableRequest request)
        {
            var result = await _service.GetDataTableAsync(request);
            return Ok(result);
        }

        /// <summary>
        /// Get server-side filtered, searched, and paged settlement payment history (GET)
        /// </summary>
        [HttpGet("DataTable")]
        public async Task<ActionResult<SettlementHistoryDataTableResultDto>> GetDataTableGet(
            [FromQuery] string searchTerm = null,
            [FromQuery] SettlementHistoryPartyFilter partyFilter = SettlementHistoryPartyFilter.All,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortColumn = "CompletedAt",
            [FromQuery] string sortDirection = "DESC")
        {
            var request = new SettlementHistoryDataTableRequest
            {
                SearchTerm = searchTerm,
                PartyFilter = partyFilter,
                FromDate = fromDate,
                ToDate = toDate,
                Page = page,
                PageSize = pageSize,
                SortColumn = sortColumn,
                SortDirection = sortDirection
            };
            var result = await _service.GetDataTableAsync(request);
            return Ok(result);
        }

        /// <summary>
        /// Get authoritative summary totals for completed settlement payments
        /// </summary>
        [HttpGet("Summary")]
        public async Task<ActionResult<SettlementHistorySummaryDto>> GetSummary(
            [FromQuery] SettlementHistoryPartyFilter partyFilter = SettlementHistoryPartyFilter.All,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null,
            [FromQuery] string searchTerm = null)
        {
            var result = await _service.GetSummaryAsync(partyFilter, fromDate, toDate, searchTerm);
            return Ok(result);
        }

        /// <summary>
        /// Get printable receipt for a legitimately completed settlement
        /// </summary>
        [HttpGet("{id}/Receipt")]
        public async Task<ActionResult<SettlementReceiptDto>> GetReceipt(string id)
        {
            try
            {
                var result = await _service.GetReceiptAsync(id);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        /// <summary>
        /// Get complete active filtered dataset formatted for printing/export (max 1000 items)
        /// </summary>
        [HttpPost("PrintData")]
        public async Task<ActionResult<List<SettlementHistoryItemDto>>> GetPrintData([FromBody] SettlementHistoryDataTableRequest request)
        {
            var result = await _service.GetPrintDataAsync(request);
            return Ok(result);
        }

        [HttpGet("PrintData")]
        public async Task<ActionResult<List<SettlementHistoryItemDto>>> GetPrintDataGet(
            [FromQuery] string searchTerm = null,
            [FromQuery] SettlementHistoryPartyFilter partyFilter = SettlementHistoryPartyFilter.All,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null,
            [FromQuery] string sortColumn = "CompletedAt",
            [FromQuery] string sortDirection = "DESC")
        {
            var request = new SettlementHistoryDataTableRequest
            {
                SearchTerm = searchTerm,
                PartyFilter = partyFilter,
                FromDate = fromDate,
                ToDate = toDate,
                Page = 1,
                PageSize = 1000,
                SortColumn = sortColumn,
                SortDirection = sortDirection
            };
            var result = await _service.GetPrintDataAsync(request);
            return Ok(result);
        }
    }
}
