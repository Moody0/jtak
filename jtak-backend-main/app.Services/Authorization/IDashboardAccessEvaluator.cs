using System.Security.Claims;
using System.Threading.Tasks;
namespace App.Shared.Services
{
    public interface IDashboardAccessEvaluator
    {
        Task<bool> HasAsync(ClaimsPrincipal principal, string permission);
    }
}
