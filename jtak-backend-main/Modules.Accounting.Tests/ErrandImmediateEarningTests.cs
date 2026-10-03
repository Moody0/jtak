using App.ApiControllers.V1.Admin;
using App.Services;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class ErrandImmediateEarningTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task SeventyFiveIsRetainedImmediatelyAndCannotBePaidAgain(bool adminFallback)
    {
        using var f = new Fixture();
        var request = new SupportMessage { Title = "طلبات - اطلب أي شيء", ErrandRequestKey = Guid.NewGuid(), ErrandStatus = ErrandStatus.Assigned,
            ErrandDriverUserId = f.Driver, ErrandItemPrice = 500m, ErrandDeliveryFee = 150m,
            ErrandDriverEarning = 75m, ErrandDeliveryCode = "123456" };
        f.App.SupportMessages.Add(request);
        await f.App.SaveChangesAsync();
        await f.SeedCustody(2856m);
        var settlement = new ErrandSettlementService(f.App, f.Db, f.Ledger, null);
        Assert.True((await settlement.RecordPurchaseAsync(request, 500m, "receipt")).Success);
        Assert.Equal(2356m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        if (adminFallback)
        {
            var users = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            var controller = new ErrandRequestsController(f.App, f.Db, f.Ledger, users.Object, null,
                NullLogger<ErrandRequestsController>.Instance);
            var delivered = new DeliverErrandDto { CollectedAmount = 650m, DeliveryCode = "123456",
                CustomerReceived = true, CashCollected = true, RecoveryReason = "Admin recovery" };
            Assert.IsType<OkObjectResult>((await controller.Deliver(request.Id, delivered)).Result);
            Assert.IsType<OkObjectResult>((await controller.Deliver(request.Id, delivered)).Result);
        }
        else
        {
            Assert.True((await settlement.RecordDeliveryAsync(request, 650m, "123456", true, true)).Success);
            Assert.True((await settlement.RecordDeliveryAsync(request, 650m, "123456", true, true)).Success);
        }
        Assert.Equal(2931m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(0m, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
        Assert.Equal(650m, request.ErrandCashCollected);
        var journal = await f.Db.JournalTransactions.Include(x => x.Entries).ThenInclude(x => x.Account)
            .SingleAsync(x => x.IdempotencyKey == $"ErrandDelivery-{request.Id}");
        Assert.Equal(575m, Assert.Single(journal.Entries.Where(x =>
            x.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix))).Debit);
        Assert.Equal(journal.Entries.Sum(x => x.Debit), journal.Entries.Sum(x => x.Credit));
        var wallet = await f.Wallet.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(75m, wallet.TotalEarned);
        Assert.Equal(75m, wallet.TotalPaid);
        Assert.Equal(0m, wallet.AvailableAmount);
        Assert.Equal(2931m, wallet.NetCashDue);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Wallet.CreateCaptainEarningsRequestAsync(
            f.Driver, "Driver", null, new() { Amount = 75m }));
    }

    [Theory]
    [InlineData(0, 1100, 0, 100, 0)]
    [InlineData(75, 1025, 0, 25, 0)]
    [InlineData(100, 1000, 0, 0, 0)]
    [InlineData(150, 950, 0, 0, 50)]
    [InlineData(1200, 0, 100, 0, 1100)]
    public async Task NetCollectionAndWageSubsidyStayBalancedAndIdempotent(decimal wage,
        decimal cash, decimal unpaid, decimal feeRevenue, decimal subsidy)
    {
        using var f = new Fixture();
        var goods = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandGoodsInTransit, "Goods", AccountType.Asset);
        var vault = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        await f.Ledger.PostTransactionAsync(new() { IdempotencyKey = "purchase-seed", Entries = new() {
            new() { AccountId = goods.Id, Debit = 800m }, new() { AccountId = vault.Id, Credit = 800m } } });
        var first = await ErrandDeliveryPosting.PostAsync(f.Ledger, 17, f.Driver, 1000m, 100m, 800m, wage);
        var repeat = await ErrandDeliveryPosting.PostAsync(f.Ledger, 17, f.Driver, 1000m, 100m, 800m, wage);
        Assert.Equal(first.Id, repeat.Id);
        Assert.Equal(cash, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(unpaid, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
        Assert.Equal(0m, await f.Ledger.GetAccountBalanceAsync(goods.Id));
        Assert.Equal(first.Entries.Sum(x => x.Debit), first.Entries.Sum(x => x.Credit));
        Assert.Equal(feeRevenue, first.Entries.Where(x => x.AccountCode == SystemAccountCodes.ErrandDeliveryFeeRevenue).Sum(x => x.Credit));
        Assert.Equal(subsidy, first.Entries.Where(x => x.AccountCode == SystemAccountCodes.DriverEarningSubsidyExpense).Sum(x => x.Debit));
        var wallet = await f.Wallet.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(wage, wallet.TotalEarned);
        Assert.Equal(Math.Min(wage, 1100m), wallet.TotalPaid);
        Assert.Equal(unpaid, wallet.AvailableAmount);
    }

    [Fact]
    public async Task RelationalPostingCommitsNetCustodyAndPaidWageInOneJournal()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        using var db = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseSqlite(connection).Options, new HttpContextAccessor());
        await db.Database.EnsureCreatedAsync();
        var ledger = new LedgerService(db, NullLogger<LedgerService>.Instance);
        var driver = Guid.NewGuid();
        var first = await ErrandDeliveryPosting.PostAsync(ledger, 17, driver, 1000m, 100m, 800m, 75m);
        db.ChangeTracker.Clear();
        var repeat = await ErrandDeliveryPosting.PostAsync(ledger, 17, driver, 1000m, 100m, 800m, 75m);
        Assert.Equal(first.Id, repeat.Id);
        var journal = await db.JournalTransactions.Include(x => x.Entries).ThenInclude(x => x.Account).SingleAsync();
        Assert.Equal(journal.Entries.Sum(x => x.Debit), journal.Entries.Sum(x => x.Credit));
        Assert.Equal(1025m, journal.Entries.Where(x => x.Account.AccountCode.StartsWith(
            SystemAccountCodes.CaptainCashFloatPrefix)).Sum(x => x.Debit - x.Credit));
        var wages = journal.Entries.Where(x => x.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix)).ToArray();
        Assert.Equal(2, wages.Length);
        Assert.Equal(75m, wages.Sum(x => x.Credit));
        Assert.Equal(75m, wages.Sum(x => x.Debit));
    }

    [Fact]
    public async Task OldUnpaidEarningsAreNotMistakenForAnImmediateCashPayment()
    {
        using var f = new Fixture();
        var cash = await f.Ledger.GetOrCreateUserAccountAsync(f.Driver, AccountType.Asset,
            SystemAccountCodes.CaptainCashFloatPrefix, "Cash");
        var wage = await f.Ledger.GetOrCreateUserAccountAsync(f.Driver, AccountType.Liability,
            SystemAccountCodes.CaptainEarningsPrefix, "Earnings");
        await f.Ledger.PostTransactionAsync(new() { IdempotencyKey = "old-errand",
            ReferenceType = "ErrandDelivery", ReferenceId = "2", Entries = new() {
                new() { AccountId = cash.Id, Debit = 75m }, new() { AccountId = wage.Id, Credit = 75m } } });
        var wallet = await f.Wallet.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(75m, wallet.TotalEarned);
        Assert.Equal(0m, wallet.TotalPaid);
        Assert.Equal(75m, wallet.AvailableAmount);
    }

    private sealed class Fixture : IDisposable
    {
        public Guid Driver { get; } = Guid.NewGuid();
        public AppDbContext App { get; }
        public AccountingDbContext Db { get; }
        public LedgerService Ledger { get; }
        public SettlementRequestService Wallet { get; }
        public Fixture()
        {
            var accessor = new HttpContextAccessor();
            App = new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, accessor);
            Db = new(new DbContextOptionsBuilder<AccountingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, accessor);
            Ledger = new(Db, NullLogger<LedgerService>.Instance);
            Wallet = new(Db, Ledger, NullLogger<SettlementRequestService>.Instance);
        }
        public async Task SeedCustody(decimal amount)
        {
            var cash = await Ledger.GetOrCreateUserAccountAsync(Driver, AccountType.Asset,
                SystemAccountCodes.CaptainCashFloatPrefix, "Cash");
            var vault = await Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            await Ledger.PostTransactionAsync(new() { IdempotencyKey = "seed", Entries = new() {
                new() { AccountId = cash.Id, Debit = amount }, new() { AccountId = vault.Id, Credit = amount } } });
        }
        public void Dispose() { App.Dispose(); Db.Dispose(); }
    }
}
