using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Entities;

namespace Modules.Accounting.Services
{
    public class ContinuousInvariantAuditService : IContinuousInvariantAuditService
    {
        private readonly IProductionReconciliationService _reconciliationService;
        private readonly ILogger<ContinuousInvariantAuditService> _logger;

        public ContinuousInvariantAuditService(
            IProductionReconciliationService reconciliationService,
            ILogger<ContinuousInvariantAuditService> logger)
        {
            _reconciliationService = reconciliationService ?? throw new ArgumentNullException(nameof(reconciliationService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<InvariantAuditTelemetryResult> PerformAuditSweepAsync()
        {
            var result = new InvariantAuditTelemetryResult();

            try
            {
                _logger.LogInformation("Starting continuous production invariant audit sweep at {Time}", result.TimestampUtc);

                var report = await _reconciliationService.RunDiscoveryAsync(new ReconciliationDiscoveryOptions
                {
                    FromDate = DateTime.UtcNow.AddDays(-90),
                    MaxResultsPerIssue = 500
                });

                result.TotalIssuesFound = report.TotalIssuesDiscovered;
                result.TotalDiscrepancyAmount = Math.Abs(report.EstimatedNetFinancialAdjustment);
                result.IssueBreakdown = report.IssueCounts ?? new Dictionary<string, int>();

                if (result.IsHealthy)
                {
                    _logger.LogInformation("Continuous invariant audit sweep completed successfully. System integrity is 100% CLEAN (0 discrepancies detected).");
                }
                else
                {
                    _logger.LogWarning("Continuous invariant audit detected {Count} discrepancies across {Dimensions} dimensions totaling {Amount} SYP.",
                        result.TotalIssuesFound, result.IssueBreakdown.Count, result.TotalDiscrepancyAmount);

                    foreach (var kvp in result.IssueBreakdown)
                    {
                        var alertMsg = $"Invariant Alert: [{kvp.Key}] detected {kvp.Value} violation(s).";
                        result.CriticalAlerts.Add(alertMsg);
                        _logger.LogWarning("{Alert}", alertMsg);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during continuous invariant audit sweep.");
                result.CriticalAlerts.Add($"Audit execution error: {ex.Message}");
            }

            return result;
        }
    }
}
