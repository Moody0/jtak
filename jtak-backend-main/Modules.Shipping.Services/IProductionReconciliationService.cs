using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public interface IProductionReconciliationService
    {
        /// <summary>
        /// Runs read-only discovery queries across the 10 critical production invariant dimensions.
        /// Never mutates any database state.
        /// </summary>
        Task<ReconciliationDiscoveryReportDto> RunDiscoveryAsync(ReconciliationDiscoveryOptions options = null);

        /// <summary>
        /// Stages identified discrepancies into persistent staging tables for review,
        /// generating detailed before/after state snapshots. Zero operational data is mutated.
        /// </summary>
        Task<ReconciliationBatchDto> StageCorrectionsAsync(StageCorrectionsRequest request, string operatorName);

        /// <summary>
        /// Approves a staged reconciliation batch for execution.
        /// Required prior to executing financial or inventory repairs.
        /// </summary>
        Task<ReconciliationBatchDto> ApproveBatchAsync(Guid batchId, string approverName, string approvalNotes = null);

        /// <summary>
        /// Idempotently executes approved staged corrections by generating immutable corrective journal transactions,
        /// restoring stranded inventory, and realigning balances.
        /// </summary>
        Task<ReconciliationBatchExecutionResultDto> ExecuteRepairsAsync(Guid batchId, string operatorName);

        /// <summary>
        /// Gets detailed information for a specific reconciliation batch, including staged corrections.
        /// </summary>
        Task<ReconciliationBatchDto> GetBatchAsync(Guid batchId);

        /// <summary>
        /// Gets a summary list of all historical reconciliation batches.
        /// </summary>
        Task<List<ReconciliationBatchSummaryDto>> GetBatchesAsync();
    }
}
