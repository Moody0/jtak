using App.ApiModels;
using App.Extensions;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
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
    [Route("api/v{version:apiVersion}/Admin/Reconciliation/Production")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [ApiVersion("1")]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = App.Helpers.Authorization.DashboardAccessService.Policy)]
    public class ProductionReconciliationController : SolApiController
    {
        private readonly IProductionReconciliationService _reconciliationService;
        private readonly IAdminAuditService _auditService;
        private readonly bool _writesEnabled;

        public ProductionReconciliationController(
            IProductionReconciliationService reconciliationService,
            IAdminAuditService auditService = null,
            IConfiguration configuration = null)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
            _auditService = auditService;
            _writesEnabled = configuration?.GetValue<bool>("ProductionReconciliation:AllowWrites") == true;
        }

        private ActionResult WritesDisabled() => StatusCode(
            StatusCodes.Status423Locked,
            ApiErr.Create("إصلاحات المطابقة المالية مقفلة حالياً. الاكتشاف والتقارير فقط متاحان حتى اعتماد المالية للسياسة الجديدة."));

        /// <summary>
        /// Runs read-only discovery queries across the 10 critical production invariant dimensions.
        /// Zero database mutations occur during discovery.
        /// </summary>
        [HttpPost("Discovery")]
        public async Task<ActionResult<ReconciliationDiscoveryReportDto>> RunDiscovery([FromBody] ReconciliationDiscoveryOptions options = null)
        {
            var report = await _reconciliationService.RunDiscoveryAsync(options);
            return Ok(report);
        }

        /// <summary>
        /// Stages identified discrepancies into a persistent reconciliation batch with before/after state snapshots.
        /// Zero operational data is mutated at this stage; awaits Finance approval.
        /// </summary>
        [HttpPost("Stage")]
        public async Task<ActionResult<ReconciliationBatchDto>> StageCorrections([FromBody] StageCorrectionsRequest request)
        {
            if (!_writesEnabled) return WritesDisabled();
            if (request == null)
            {
                return BadRequest(ApiErr.Create("يجب تقديم طلب المطابقة وجدولة التصحيحات."));
            }

            var operatorName = User?.Identity?.Name ?? "Admin";
            var batch = await _reconciliationService.StageCorrectionsAsync(request, operatorName);

            if (_auditService != null)
            {
                await _auditService.LogAsync(new AdminAuditLogEntry
                {
                    Module = "Reconciliation",
                    Action = "StageBatch",
                    EntityType = "ReconciliationBatch",
                    EntityId = batch.Id.ToString(),
                    Description = $"جدولة دفعة مطابقة محاسبية جديدة #{batch.BatchNumber} تتضمن {batch.TotalStagedCorrections} تصحيح مرحلي.",
                    Result = "Success",
                    AfterState = batch
                });
            }

            return Ok(batch);
        }

        /// <summary>
        /// Gets all historical reconciliation batches.
        /// </summary>
        [HttpGet("Batches")]
        public async Task<ActionResult<List<ReconciliationBatchSummaryDto>>> GetBatches()
        {
            var batches = await _reconciliationService.GetBatchesAsync();
            return Ok(batches);
        }

        /// <summary>
        /// Gets a specific reconciliation batch by ID with all staged before/after corrections.
        /// </summary>
        [HttpGet("Batches/{id}")]
        public async Task<ActionResult<ReconciliationBatchDto>> GetBatch(Guid id)
        {
            var batch = await _reconciliationService.GetBatchAsync(id);
            if (batch == null)
            {
                return NotFound(ApiErr.Create("دفعة المطابقة غير موجودة."));
            }

            return Ok(batch);
        }

        /// <summary>
        /// Approves a staged reconciliation batch for execution (Finance approval gate).
        /// </summary>
        [HttpPost("Batches/{id}/Approve")]
        public async Task<ActionResult<ReconciliationBatchDto>> ApproveBatch(Guid id, [FromBody] ApproveReconciliationBatchRequest request)
        {
            if (!_writesEnabled) return WritesDisabled();
            try
            {
                var approverName = User?.Identity?.Name ?? "Finance Admin";
                var batch = await _reconciliationService.ApproveBatchAsync(id, approverName, request?.Notes);

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Reconciliation",
                        Action = "ApproveBatch",
                        EntityType = "ReconciliationBatch",
                        EntityId = batch.Id.ToString(),
                        Description = $"تمت الموافقة المالية على دفعة المطابقة #{batch.BatchNumber} بواسطة {approverName}.",
                        Result = "Success",
                        AfterState = batch
                    });
                }

                return Ok(batch);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        /// <summary>
        /// Idempotently executes approved corrections for a reconciliation batch.
        /// Never mutates settled ledger history; posts explicit immutable adjustment entries.
        /// </summary>
        [HttpPost("Batches/{id}/Execute")]
        public async Task<ActionResult<ReconciliationBatchExecutionResultDto>> ExecuteBatch(Guid id)
        {
            if (!_writesEnabled) return WritesDisabled();
            try
            {
                var operatorName = User?.Identity?.Name ?? "Admin";
                var result = await _reconciliationService.ExecuteRepairsAsync(id, operatorName);

                if (_auditService != null)
                {
                    await _auditService.LogAsync(new AdminAuditLogEntry
                    {
                        Module = "Reconciliation",
                        Action = "ExecuteRepairs",
                        EntityType = "ReconciliationBatch",
                        EntityId = id.ToString(),
                        Description = $"تم تنفيذ إصلاحات دفعة المطابقة #{result.BatchNumber}: نجح {result.AppliedCount}، فشل {result.FailedCount}، تخطى {result.SkippedCount}.",
                        Result = result.FailedCount == 0 ? "Success" : "PartialFailure",
                        AfterState = result
                    });
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiErr.Create(ex.Message));
            }
        }

        /// <summary>
        /// Generates an exportable/printable reconciliation financial summary for a batch.
        /// </summary>
        [HttpGet("Batches/{id}/Report")]
        public async Task<ActionResult<ReconciliationBatchDto>> GetBatchReport(Guid id)
        {
            var batch = await _reconciliationService.GetBatchAsync(id);
            if (batch == null)
            {
                return NotFound(ApiErr.Create("دفعة المطابقة غير موجودة."));
            }

            return Ok(batch);
        }
    }
}
