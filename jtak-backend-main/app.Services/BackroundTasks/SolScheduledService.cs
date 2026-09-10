using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace App.Shared.Services.BackroundTasks
{
    public abstract class SolScheduledService : BackgroundService
    {
        private readonly TimeSpan dueTime;
        private readonly TimeSpan period;
        private DateTime _nextRun;
        private readonly string serviceName;
        private readonly ILogger<SolScheduledService> logger;

        public SolScheduledService(TimeSpan dueTime, TimeSpan period, ILogger<SolScheduledService> logger, string serviceName)
        {
            this.dueTime = dueTime;
            this.period = period;
            this._nextRun = DateTime.Now.Add(dueTime);
            this.logger = logger;
            this.serviceName = serviceName;
        }

        public override async Task StartAsync(CancellationToken cancellationToken)
        {
            logger.LogInformation($"[Service Started] \"{serviceName}\" ({DateTime.UtcNow:O}){Environment.NewLine}dueTime:{dueTime.TotalSeconds}s / period:{period.TotalSeconds}s");
            await base.StartAsync(cancellationToken);
        }
        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            logger.LogInformation($"[Service Stopped] \"{serviceName}\" ({DateTime.UtcNow:O}){Environment.NewLine}dueTime:{dueTime.TotalSeconds}s / period:{period.TotalSeconds}s");
            await base.StopAsync(cancellationToken);
        }

        protected override async Task ExecuteAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(UntilNextRun(), cancellationToken);
                try
                {
                    await ScheduledTask(cancellationToken);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error occurred executing {ScheduledTask}.", nameof(ScheduledTask));
                }
                while (_nextRun < DateTime.Now)
                {
                    _nextRun = _nextRun.Add(period);
                }
            }
        }

        public abstract Task ScheduledTask(CancellationToken cancellationToken);

        private int UntilNextRun() =>
            Math.Max(0, (int)_nextRun.Subtract(DateTime.Now).TotalMilliseconds);
    }
}
