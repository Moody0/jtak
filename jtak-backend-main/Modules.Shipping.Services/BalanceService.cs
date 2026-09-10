using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Solf.Base;
using System;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    public interface IBalanceService : ISolService<Balance, BalanceDto>
    {
        Task IncreaseAppBalance(Guid Id, decimal Amount, string Name = null, decimal PendingAmount = 0);
        Task DecreaseAppBalance(Guid Id, decimal Amount, string Name = null, decimal PendingAmount = 0);
        Task UpdateAppBalance(BalanceDto balance);
        Task<BalanceDto> GetBalance(Guid id);
    }
    public class BalanceService : SolService<Balance, BalanceDto>, IBalanceService
    {
        ITrackableRepository<GenericSetting, AccountingDbContext> _setting;
        IAccountingUnitOfWork _uow;
        private readonly ILogger _logger;
        private readonly IBillService _billService;
        public BalanceService(ITrackableRepository<Balance, AccountingDbContext> repo,
                                     IAccountingUnitOfWork uow,
                                     ILogger<BalanceService> logger,
                                     IBillService billService,
                                     ITrackableRepository<GenericSetting, AccountingDbContext> setting) : base(repo)
        {
            _setting = setting;
            _logger = logger;
            _uow = uow;
            _billService = billService;
        }

        public async Task<BalanceDto> GetBalance(Guid id)
        {
            var entity = await Queryable().FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null)
                return new BalanceDto { Id = id, Amount = 0, CreatedDate = DateTime.UtcNow, PendingAmount = 0 };

            return new BalanceDto { Id = id, Amount = entity.Amount, PendingAmount = entity.PendingAmount, Name = entity.Name, CreatedDate = entity.CreatedDate };
        }

        public async Task IncreaseAppBalance(Guid Id, decimal Amount, string Name = null, decimal PendingAmount = 0)
        {
            var balance = await GetBalance(Id);
            var msg =
$@"============ Balance Change (Increase) ===============
{Name} - {Id}
{balance.Amount} => {balance.Amount + Amount}
=========================================================";
            _logger.LogError(msg);
            balance.Amount += Amount;
            balance.PendingAmount += PendingAmount;
            balance.Name = Name ?? balance.Name;

            await UpdateAppBalance(balance);
        }

        public async Task DecreaseAppBalance(Guid Id, decimal Amount, string Name = null, decimal PendingAmount = 0)
        {
            var balance = await GetBalance(Id);
            var msg =
$@"============ Balance Change (Decrease) ===============
{Name} - {Id}
{balance.Amount} => {balance.Amount + Amount}
=========================================================";
            _logger.LogError(msg);

            balance.Amount -= Amount;
            balance.PendingAmount -= PendingAmount;
            balance.Name = Name ?? balance.Name;

            await UpdateAppBalance(balance);
        }

        public async Task UpdateAppBalance(BalanceDto balance)
        {
            var entity = await Queryable().FirstOrDefaultAsync(x => x.Id == balance.Id);
            if (entity != null)
            {
                entity.Name = balance.Name ?? entity.Name;
                entity.Amount = balance.Amount;
                entity.PendingAmount = balance.PendingAmount;
            }
            else
            {
                Insert(new Balance { Id = balance.Id, Amount = balance.Amount, Name = balance.Name, PendingAmount = balance.PendingAmount });
            }
            await _uow.SaveChangesAsync();
        }

        //public async Task<bool> Delete(int id)
        //{
        //    //TODO: IncreaseAppBalance
        //    var bill = await _billService.FindAsync(id);
        //    await IncreaseAppBalance(bill.MerchantId, bill.MerchantAmount, "MERCHANT NAME"); // VERIFIED
        //    return await base.DeleteAsync(new object[] { id });
        //}
    }
}
