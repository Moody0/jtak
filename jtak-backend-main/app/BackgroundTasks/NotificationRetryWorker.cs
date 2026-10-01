using System;
using System.Threading;
using System.Threading.Tasks;
using App.Shared.Services;
using App.Shared.Services.BackroundTasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace App.BackgroundTasks
{
    public sealed class NotificationRetryWorker : SolScheduledService
    {
        private readonly IServiceProvider _services;
        public NotificationRetryWorker(IServiceProvider services, ILogger<NotificationRetryWorker> logger)
            : base(TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(20), logger, nameof(NotificationRetryWorker)) => _services = services;
        public override async Task ScheduledTask(CancellationToken cancellationToken)
        {
            using var scope = _services.CreateScope();
            await scope.ServiceProvider.GetRequiredService<INotificationService>().RetryPendingNotificationsAsync(cancellationToken);
        }
    }
}
