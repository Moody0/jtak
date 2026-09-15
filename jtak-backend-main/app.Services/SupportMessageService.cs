using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities.Domain;
using Solf.Base;

namespace App.Shared.Services
{
    public interface ISupportMessageService : ISolService<SupportMessage, SupportMessageDto>
    {
        Task<SupportMessageStatsDto> GetStatsAsync();
        Task<bool> UpdateStatusAsync(int id, SupportMessageStatus status, string adminNotes = null);
    }

    public class SupportMessageService : SolService<SupportMessage, SupportMessageDto>, ISupportMessageService
    {
        private readonly IAppUnitOfWork _unitOfWork;

        public SupportMessageService(
            ITrackableRepository<SupportMessage, AppDbContext> repository,
            IAppUnitOfWork unitOfWork) : base(repository)
        {
            _unitOfWork = unitOfWork;
        }

        public async Task<SupportMessageStatsDto> GetStatsAsync()
        {
            var total = await Repository.Queryable().CountAsync();
            var newCount = await Repository.Queryable().CountAsync(x => x.Status == SupportMessageStatus.New);
            var inProgress = await Repository.Queryable().CountAsync(x => x.Status == SupportMessageStatus.Read);
            var resolved = await Repository.Queryable().CountAsync(x => x.Status == SupportMessageStatus.Resolved);

            return new SupportMessageStatsDto
            {
                TotalCount = total,
                NewCount = newCount,
                InProgressCount = inProgress,
                ResolvedCount = resolved
            };
        }

        public async Task<bool> UpdateStatusAsync(int id, SupportMessageStatus status, string adminNotes = null)
        {
            var msg = await Repository.Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (msg == null) return false;

            msg.Status = status;
            if (adminNotes != null) msg.AdminNotes = adminNotes;
            if (status == SupportMessageStatus.Resolved)
            {
                msg.ResolvedDate = DateTime.UtcNow;
            }
            else
            {
                msg.ResolvedDate = null;
            }

            Repository.Update(msg);
            await _unitOfWork.SaveChangesAsync();
            return true;
        }
    }
}
