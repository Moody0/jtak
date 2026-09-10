using App.Shared.Data.MultiContext;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Solf.Base;

namespace Modules.Accounting.Services
{
    public interface IPaymentService : ISolService<Payment, PaymentDto>
    {
    }
    public class PaymentService : SolService<Payment, PaymentDto>, IPaymentService
    {
        public PaymentService(ITrackableRepository<Payment, AccountingDbContext> repo) : base(repo)
        {
        }
    }
}
