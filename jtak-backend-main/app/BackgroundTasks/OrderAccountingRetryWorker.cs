using System;
using System.Threading;
using System.Threading.Tasks;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Modules.Shipping.Services;

namespace App.BackgroundTasks
{
    public class OrderAccountingRetryWorker : SolScheduledService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<OrderAccountingRetryWorker> _logger;

        public OrderAccountingRetryWorker(
            IServiceProvider services,
            ILogger<OrderAccountingRetryWorker> logger)
            : base(TimeSpan.FromSeconds(15),
                   TimeSpan.FromMinutes(2),
                   logger,
                   nameof(OrderAccountingRetryWorker))
        {
            _services = services ?? throw new ArgumentNullException(nameof(services));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            try
            {
                using var scope = _services.CreateScope();
                var featureFlags = scope.ServiceProvider.GetRequiredService<IOrderFeatureFlagService>();
                if (!featureFlags.IsPeriodicAccountingRetryEnabled()) return;

                var retryService = scope.ServiceProvider.GetRequiredService<IOrderAccountingRetryService>();
                var result = await retryService.RetryPendingAccountingOrdersAsync(maxBatchSize: 50);
                if (result != null && result.TotalFound > 0)
                {
                    _logger.LogInformation(
                        "Pending order accounting retry completed: found {Total}, succeeded {Succeeded}, failed {Failed}.",
                        result.TotalFound,
                        result.Succeeded,
                        result.Failed);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during pending order accounting retry.");
            }
        }
    }
}
