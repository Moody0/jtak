using App.ApiModels;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.AdminPermission))]
    public class AuditLogsController : SolApiController
    {
        private readonly IAdminAuditService _auditService;

        public AuditLogsController(IAdminAuditService auditService)
        {
            _auditService = auditService;
        }

        /// <summary>
        /// Global KPI summary of admin operations
        /// </summary>
        [HttpGet]
        [Route("Summary")]
        public async Task<ActionResult<AdminAuditLogSummaryDto>> Summary()
        {
            var summary = await _auditService.GetSummaryAsync();
            return Ok(summary);
        }

        /// <summary>
        /// Paginated, filterable admin audit trail table
        /// </summary>
        [HttpPost]
        [Route("DataTable")]
        public async Task<ActionResult<TableResponseModel<AdminAuditLogDto>>> DataTable(
            [FromBody] MetronicTable request,
            [FromQuery] string module = null,
            [FromQuery] string action = null,
            [FromQuery] string result = null,
            [FromQuery] Guid? adminUserId = null,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null)
        {
            var filter = new AdminAuditLogFilter
            {
                Module = module,
                Action = action,
                Result = result,
                AdminUserId = adminUserId,
                FromDate = fromDate,
                ToDate = toDate
            };
            var data = await _auditService.GetDataTableAsync(request, filter);
            return Ok(data);
        }

        /// <summary>
        /// Get detailed audit log entry snapshot
        /// </summary>
        [HttpGet]
        [Route("{id}")]
        public async Task<ActionResult<AdminAuditLogDto>> GetById(Guid id)
        {
            var item = await _auditService.GetByIdAsync(id);
            if (item == null) return NotFound();
            return Ok(item);
        }
    }
}
