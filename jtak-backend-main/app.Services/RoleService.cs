using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using Solf.Identity;
using URF.Core.Abstractions.Services;
using URF.Core.Services;

namespace App.Shared.Services
{
    public interface IRoleService : IService<SolRole>
    {

    }

    public class RoleService : Service<SolRole>, IRoleService
    {
        public RoleService(ITrackableRepository<SolRole, AppDbContext> repository) : base(repository)
        {
        }
    }
}
