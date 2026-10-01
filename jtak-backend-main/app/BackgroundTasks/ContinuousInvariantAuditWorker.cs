using System;
using System.Threading;
using System.Threading.Tasks;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Services;
using Modules.Shipping.Services;

namespace App.BackgroundTasks
{
    public class ContinuousInvariantAuditWorker : SolScheduledService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<ContinuousInvariantAuditWorker> _logger;

        public ContinuousInvariantAuditWorker(
            IServiceProvider services,
            ILogger<ContinuousInvariantAuditWorker> logger)
            : base(TimeSpan.FromMinutes(2),
                   TimeSpan.FromMinutes(60),
                   logger,
                   nameof(ContinuousInvariantAuditWorker))
        {
            _services = services ?? throw new ArgumentNullException(nameof(services));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            try
            {
                using var scope = _services.CreateScope();
                var flagService = scope.ServiceProvider.GetRequiredService<IOrderFeatureFlagService>();

                // Continuous Invariant Audit Sweep
                if (flagService.IsContinuousInvariantAuditEnabled())
                {
                    try
                    {
                        var auditService = scope.ServiceProvider.GetRequiredService<IContinuousInvariantAuditService>();
                        var result = await auditService.PerformAuditSweepAsync();
                        if (!result.IsHealthy)
                        {
                            _logger.LogWarning("Continuous invariant audit detected {Issues} issue(s) totaling {Amount} SYP.",
                                result.TotalIssuesFound, result.TotalDiscrepancyAmount);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error occurred during continuous invariant audit sweep.");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred in ScheduledTask for ContinuousInvariantAuditWorker.");
            }
        }
    }
}
