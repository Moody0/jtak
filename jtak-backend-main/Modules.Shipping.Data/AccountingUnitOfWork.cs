using App.Shared.Data.MultiContext;

namespace Modules.Accounting.Data
{
    public interface IAccountingUnitOfWork : IUnitOfWork<AccountingUnitOfWork>
    {
    }
    public class AccountingUnitOfWork : UnitOfWork<AccountingDbContext>, IAccountingUnitOfWork
    {
        public AccountingUnitOfWork(AccountingDbContext context) : base(context)
        {
        }
    }
}
