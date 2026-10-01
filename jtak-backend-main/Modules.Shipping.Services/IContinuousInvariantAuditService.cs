using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    public class InvariantAuditTelemetryResult
    {
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
        public int TotalIssuesFound { get; set; }
        public bool IsHealthy => TotalIssuesFound == 0;
        public Dictionary<string, int> IssueBreakdown { get; set; } = new Dictionary<string, int>();
        public List<string> CriticalAlerts { get; set; } = new List<string>();
        public decimal TotalDiscrepancyAmount { get; set; }
    }

    public interface IContinuousInvariantAuditService
    {
        /// <summary>
        /// Runs a scheduled audit sweep across all 10 invariant dimensions and returns structured health metrics.
        /// </summary>
        Task<InvariantAuditTelemetryResult> PerformAuditSweepAsync();
    }
}
