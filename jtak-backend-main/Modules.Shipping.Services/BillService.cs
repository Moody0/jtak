using App.Shared.Data.MultiContext;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Solf.Base;

namespace Modules.Accounting.Services
{
    public interface IBillService : ISolService<Bill, BillDto>
    {
    }
    public class BillService : SolService<Bill, BillDto>, IBillService
    {
        public BillService(ITrackableRepository<Bill, AccountingDbContext> repo) : base(repo)
        {
        }
    }
}
