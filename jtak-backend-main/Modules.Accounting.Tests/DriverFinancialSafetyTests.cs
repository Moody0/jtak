using App.Orders.Data;
using App.Services;
using App.Shared.Data.App;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests;

public class DriverFinancialSafetyTests
{
    private sealed class Fixture : IDisposable
    {
        public Guid Driver { get; } = Guid.NewGuid();
        public AccountingDbContext Accounting { get; } = new(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        public AppDbContext App { get; } = new(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        public OrdersDbContext Orders { get; } = new(new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        public LedgerService Ledger { get; }
        public DriverFinancialSafetyService Safety { get; }
        public SettlementRequestService Settlements { get; }
        public EodReconciliationService Eod { get; }
        public Fixture() {
            Ledger = new(Accounting, NullLogger<LedgerService>.Instance);
            Safety = new(Accounting, Ledger, App, Orders);
            Settlements = new(Accounting, Ledger, NullLogger<SettlementRequestService>.Instance, Orders, Safety);
            Eod = new(Accounting, Ledger, null, NullLogger<EodReconciliationService>.Instance, Safety);
        }
        public async Task Seed(decimal cash = 100m, decimal earnings = 0m) {
            var account = await Ledger.GetOrCreateUserAccountAsync(Driver, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Driver cash");
            var wages = await Ledger.GetOrCreateUserAccountAsync(Driver, AccountType.Liability, SystemAccountCodes.CaptainEarningsPrefix, "Wages");
            var vault = await Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
            var expense = await Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.OperationalExpense, "Wages cost", AccountType.Expense);
            var entries = new List<PostLedgerEntryRequest> {
                new() { AccountId=account.Id, Debit=cash }, new() { AccountId=vault.Id, Credit=cash }};
            if (earnings>0) { entries.Add(new() { AccountId=expense.Id, Debit=earnings }); entries.Add(new() { AccountId=wages.Id, Credit=earnings }); }
            await Ledger.PostTransactionAsync(new() { IdempotencyKey="seed", Entries=entries });
        }
        public async Task<SupportMessage> Errand(ErrandStatus status, decimal price = 50m, Guid? driver = null) {
            var request=new SupportMessage { Title="Test purchase", ErrandStatus=status, ErrandDriverUserId=driver ?? Driver,
                ErrandItemPrice=price, ErrandDeliveryFee=10m, ErrandDeliveryCode="123456", ErrandPurchaseCost=status==ErrandStatus.Purchased?30m:null };
            App.SupportMessages.Add(request); await App.SaveChangesAsync(); return request;
        }
        public void Dispose() { Accounting.Dispose(); App.Dispose(); Orders.Dispose(); }
    }

    [Fact]
    public async Task AssignedPurchasesReserveCash_CompletedAndOtherDriversDoNot() {
        using var f=new Fixture(); await f.Seed();
        await f.Errand(ErrandStatus.Assigned, 35m); await f.Errand(ErrandStatus.Assigned, 25m);
        await f.Errand(ErrandStatus.Purchased, 90m); await f.Errand(ErrandStatus.Delivered, 999m);
        await f.Errand(ErrandStatus.Assigned, 999m, Guid.NewGuid());
        var position=await f.Safety.GetPositionAsync(f.Driver);
        Assert.Equal(60m,position.ReservedForPurchases);
        Assert.Equal(40m,position.SpendableCash);
        Assert.Equal(180m,position.ExpectedCollections);
        var balance=await f.Settlements.GetCaptainBalanceAsync(f.Driver);
        Assert.Equal(60m,balance.ReservedPurchaseAmount);
        Assert.Equal(40m,balance.AvailableAmount);
        var handover=await f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new());
        Assert.Equal(40m,handover.Amount);
        Assert.Equal(0m,(await f.Safety.GetPositionAsync(f.Driver)).SpendableCash);
    }

    [Fact]
    public async Task PurchaseCannotSpendCashReservedForAnotherPurchaseOrHandover() {
        using var f=new Fixture(); await f.Seed();
        var first=await f.Errand(ErrandStatus.Assigned,60m);
        await f.Errand(ErrandStatus.Assigned,50m);
        var service=new ErrandSettlementService(f.App,f.Accounting,f.Ledger,null,f.Safety);
        var result=await service.RecordPurchaseAsync(first,60m,"receipt");
        Assert.False(result.Success);
        Assert.Equal(ErrandStatus.Assigned,first.ErrandStatus);
        Assert.Equal(100m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        // A durable handover reservation also reduces money available to buy.
        f.App.SupportMessages.RemoveRange(f.App.SupportMessages); await f.App.SaveChangesAsync();
        await f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new() {Amount=70m});
        var newPurchase=await f.Errand(ErrandStatus.Assigned,50m);
        Assert.False((await service.RecordPurchaseAsync(newPurchase,40m,"receipt")).Success);
    }

    [Theory]
    [InlineData(ErrandStatus.PurchasePending)]
    [InlineData(ErrandStatus.DeliveryPending)]
    [InlineData(ErrandStatus.ReturnPending)]
    public async Task UnfinishedErrandAccountingBlocksBothWalletsAndEod(ErrandStatus status) {
        using var f=new Fixture(); await f.Seed(100m,20m); await f.Errand(status);
        Assert.True((await f.Settlements.GetCaptainBalanceAsync(f.Driver)).HasPendingAccountingOrders);
        Assert.Equal(0m,(await f.Settlements.GetCaptainEarningsAsync(f.Driver)).AvailableAmount);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new()));
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateCaptainEarningsRequestAsync(f.Driver,"Driver","",new()));
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Eod.SettleCaptainShiftAsync(new() {CaptainUserId=f.Driver,PhysicalCashReceived=80m},Guid.NewGuid()));
        Assert.Equal(100m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
    }

    [Theory]
    [InlineData(OrderAccountingStatus.PendingAccounting)]
    [InlineData(OrderAccountingStatus.Failed)]
    public async Task OrdinaryAccountingFailureAlsoBlocksMoneyOperations(OrderAccountingStatus status) {
        using var f=new Fixture(); await f.Seed(100m,20m);
        f.Orders.Orders.Add(new Order {DeliveryId=f.Driver,AccountingStatus=status}); await f.Orders.SaveChangesAsync();
        Assert.True((await f.Safety.GetPositionAsync(f.Driver)).HasUnfinishedAccounting);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateCaptainEarningsRequestAsync(f.Driver,"Driver","",new()));
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Eod.SettleCaptainShiftAsync(new() {CaptainUserId=f.Driver,PhysicalCashReceived=80m},Guid.NewGuid()));
    }

    [Fact]
    public async Task OrdinaryCodAndErrandsBothCountAgainstFutureCustody() {
        using var f=new Fixture(); await f.Seed(); await f.Errand(ErrandStatus.Assigned,50m);
        var order=new Order {DeliveryId=f.Driver,OrderStatus=OrderStatus.Success,PaymentMethod=PaymentMethod.PayOnDelivery,DeliveryFee=5m,
            OrderDetails=new List<OrderDetail> {new() {Quantity=2,SinglePrice=20m,SingleFinalPrice=0m,OrderDetailStatus=OrderDetailStatus.ReadyForPickup}}};
        f.Orders.Orders.Add(order); await f.Orders.SaveChangesAsync();
        Assert.Equal(105m,(await f.Safety.GetPositionAsync(f.Driver)).ExpectedCollections);
        Assert.Equal(60m,(await f.Safety.GetPositionAsync(f.Driver,excludeOrderId:order.Id)).ExpectedCollections);
    }

    [Theory]
    [InlineData("retain_driver_debt",5,0)]
    [InlineData("write_off",0,5)]
    public async Task ShortageTreatmentEitherRetainsDebtOrRecordsApprovedExpense(string treatment,int debt,int expense) {
        using var f=new Fixture(); await f.Seed(100m,20m);
        var result=await f.Eod.SettleCaptainShiftAsync(new() {CaptainUserId=f.Driver,PhysicalCashReceived=75m,
            DiscrepancyReason="Counted shortage",ShortageTreatment=treatment},Guid.NewGuid());
        Assert.Equal(-5m,result.DiscrepancyAmount);
        Assert.Equal(debt,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(0m,await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
        var loss=await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashShortageExpense,"Shortage",AccountType.Expense);
        Assert.Equal(expense,await f.Ledger.GetAccountBalanceAsync(loss.Id));
        var batch=await f.Accounting.DailySettlementBatches.SingleAsync();
        Assert.Contains(treatment,batch.Notes);
        var txn=await f.Accounting.JournalTransactions.Include(x=>x.Entries).SingleAsync(x=>x.ReferenceType=="FleetSettlement");
        Assert.Equal(txn.Entries.Sum(x=>x.Debit),txn.Entries.Sum(x=>x.Credit));
    }

    [Fact]
    public async Task ShortageRequiresReasonAndExplicitTreatmentBeforeAnyMoneyMoves() {
        using var f=new Fixture(); await f.Seed(100m,20m);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Eod.SettleCaptainShiftAsync(new() {CaptainUserId=f.Driver,PhysicalCashReceived=75m,
            ShortageTreatment="write_off"},Guid.NewGuid()));
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Eod.SettleCaptainShiftAsync(new() {CaptainUserId=f.Driver,PhysicalCashReceived=75m,
            DiscrepancyReason="Shortage"},Guid.NewGuid()));
        Assert.Equal(100m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Empty(f.Accounting.DailySettlementBatches);
    }
}
