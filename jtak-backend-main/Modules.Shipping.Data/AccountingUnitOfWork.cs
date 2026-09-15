using App.Shared.Data.MultiContext;

namespace Modules.Accounting.Data
{
    public interface IAccountingUnitOfWork : IUnitOfWork<AccountingDbContext>
    {
        AccountingDbContext Context { get; }
    }
    public class AccountingUnitOfWork : UnitOfWork<AccountingDbContext>, IAccountingUnitOfWork
    {
        public new AccountingDbContext Context { get; }
        public AccountingUnitOfWork(AccountingDbContext context) : base(context)
        {
            Context = context;
        }
    }
}
