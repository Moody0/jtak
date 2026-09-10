using URF.Core.Abstractions.Services;
using URF.Core.Services;
using System.Linq;
using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using App.Shared.Entities;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;

namespace App.Shared.Services
{
    public interface ISmsLogService : IService<SmsLog>
    {
        Task<int> GetSMSResendWaitTime(Guid? uid);
    }

    public class SmsLogService : Service<SmsLog>, ISmsLogService
    {
        public SmsLogService(ITrackableRepository<SmsLog, AppDbContext> repository) : base(repository)
        {
        }

        public async Task<int> GetSMSResendWaitTime(Guid? uid)
        {
            if (!uid.HasValue) return 0;
            var lastDaySmsCount = Repository.Queryable().Count(x => x.UserId == uid && MySqlDbFunctionsExtensions.DateDiffHour(EF.Functions, DateTime.UtcNow, x.CreatedDate) < 24);

            if (lastDaySmsCount == 0) return 0;

            var waitTimeInSecs = lastDaySmsCount < 3 ? 30 :
                                    lastDaySmsCount == 3 ? 120 :
                                    lastDaySmsCount == 4 ? 600 :
                                    lastDaySmsCount == 5 ? 1800 :
                                    lastDaySmsCount == 6 ? 3600 : 86400;


            var lastSms = await Repository.Queryable().Where(x => x.UserId == uid).OrderByDescending(x => MySqlDbFunctionsExtensions.DateDiffHour(EF.Functions, DateTime.UtcNow, x.CreatedDate)).FirstOrDefaultAsync();

            var waitTimeLeft = waitTimeInSecs - (int)(DateTime.UtcNow - lastSms.CreatedDate).TotalSeconds;

            return waitTimeLeft;
        }
    }
}