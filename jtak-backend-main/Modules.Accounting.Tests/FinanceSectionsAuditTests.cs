using System.Security.Claims;
using System.Text.Json;
using App.ApiControllers.V1.Admin;
using App.ApiControllers.V1.Admin.Accounting;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Moq;
using Solf.Models;
using AdminPayments=App.ApiControllers.V1.Admin.PaymentsController;
using WarehousePayments=App.ApiControllers.V1.Warehouse.PaymentsController;
using Merchant=Modules.Catalog.Entities.Merchant;

namespace Modules.Accounting.Tests;

public class FinanceSectionsAuditTests
{
    sealed class Fixture:IDisposable {
        public readonly AccountingDbContext Db=new(new DbContextOptionsBuilder<AccountingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options,null);
        public readonly AppDbContext App=new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options,null);
        public readonly OrdersDbContext Orders=new(new DbContextOptionsBuilder<OrdersDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options,null);
        public readonly CatalogDbContext Catalog=new(new DbContextOptionsBuilder<CatalogDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options,null);
        public readonly Guid Driver=Guid.NewGuid(),Owner=Guid.NewGuid(),Admin=Guid.NewGuid();
        public readonly LedgerService Ledger;
        public readonly SettlementRequestService Settlements;
        public readonly Mock<UserManager<AppUser>> Users;
        public readonly Mock<IMerchantService> Merchants=new();
        public readonly Mock<IBalanceService> Balances=new();
        public readonly PaymentService Payments;
        public Fixture() {
            Ledger=new(Db,NullLogger<LedgerService>.Instance);
            Settlements=new(Db,Ledger,NullLogger<SettlementRequestService>.Instance,Orders,new DriverFinancialSafetyService(Db,Ledger,App,Orders));
            Payments=new(new TrackableRepository<Payment,AccountingDbContext>(Db));
            var users=new[]{new AppUser {Id=Driver,FullName="Driver",IsActive=true},new AppUser {Id=Owner,FullName="Owner",IsActive=true},new AppUser {Id=Admin,FullName="Admin",IsActive=true}};
            App.Users.AddRange(users);App.SaveChanges();
            Users=new(new Mock<IUserStore<AppUser>>().Object,null,null,null,null,null,null,null,null);
            Users.SetupGet(u=>u.Users).Returns(App.Users);
            Users.Setup(u=>u.FindByIdAsync(It.IsAny<string>())).ReturnsAsync((string id)=>users.FirstOrDefault(u=>u.Id.ToString()==id));
            Users.Setup(u=>u.GetUsersInRoleAsync(It.IsAny<string>())).ReturnsAsync(new List<AppUser>{users[0]});
            Users.Setup(u=>u.IsInRoleAsync(It.IsAny<AppUser>(),It.IsAny<string>())).ReturnsAsync((AppUser u,string role)=>u.Id==Driver && role==AppRoleName.Delivery.ToString());
            Catalog.Merchants.AddRange(new Merchant{Id=30,Title="First store",OwnerId=Owner,Active=true},new Merchant{Id=31,Title="Second store",OwnerId=Owner,Active=true});Catalog.SaveChanges();
            Merchants.Setup(m=>m.Queryable()).Returns(Catalog.Merchants);
            Merchants.Setup(m=>m.GetMerchantIds(Owner)).ReturnsAsync(new[]{30,31});
            Balances.Setup(b=>b.GetBalance(It.IsAny<Guid>())).ReturnsAsync((Guid id)=>new BalanceDto{Id=id,Amount=99999m});
        }
        public async Task Seed(decimal cash=1100m,decimal earnings=40m) {
            var floatAccount=await Ledger.GetOrCreateUserAccountAsync(Driver,AccountType.Asset,SystemAccountCodes.CaptainCashFloatPrefix,"Driver cash");
            var wages=await Ledger.GetOrCreateUserAccountAsync(Driver,AccountType.Liability,SystemAccountCodes.CaptainEarningsPrefix,"Driver earnings");
            var equity=await Ledger.GetOrCreateSystemAccountAsync("TEST-OPENING","Opening",AccountType.Equity);
            var expense=await Ledger.GetOrCreateSystemAccountAsync("TEST-EXPENSE","Opening expense",AccountType.Expense);
            var first=await Ledger.GetOrCreateMerchantAccountAsync(30,"First store");var second=await Ledger.GetOrCreateMerchantAccountAsync(31,"Second store");
            var entries=new List<PostLedgerEntryRequest>{new(){AccountId=first.Id,Credit=900m},new(){AccountId=second.Id,Credit=500m},new(){AccountId=expense.Id,Debit=1400m}};
            if(cash>0){entries.Add(new(){AccountId=floatAccount.Id,Debit=cash});entries.Add(new(){AccountId=equity.Id,Credit=cash});}
            if(earnings>0){entries.Add(new(){AccountId=wages.Id,Credit=earnings});entries.Add(new(){AccountId=expense.Id,Debit=earnings});}
            await Ledger.PostTransactionAsync(new(){IdempotencyKey="opening",Entries=entries});
        }
        public AdminPayments Controller()=>new(new AppUnitOfWork(App),new AccountingUnitOfWork(Db),null,Users.Object,Merchants.Object,null,Payments,null,Balances.Object,Ledger,new SettlementHistoryService(Db),null,ordersDb:Orders);
        public PaymentDto Request(decimal amount=400m)=>new(){ByUserId=Driver,ToUserId=Owner,MerchantId=31,Amount=amount,RequestKey="operation-1"};
        public WarehousePayments Warehouse()=>new(null,new AccountingUnitOfWork(Db),new Mock<global::App.Shared.Services.INotificationService>().Object,Users.Object,Merchants.Object,null,Payments,null,Balances.Object,Ledger,null){ControllerContext=new(){HttpContext=new DefaultHttpContext{User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim(ClaimTypes.NameIdentifier,Owner.ToString())},"test"))}}};
        public DriverFinancialSafetyService Safety()=>new(Db,Ledger,App,Orders);
        public CaptainSettlementsController Captain()=>new(Orders,Db,Users.Object,Ledger,appDb:App){ControllerContext=new(){HttpContext=new DefaultHttpContext{User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim(ClaimTypes.NameIdentifier,Admin.ToString())},"test"))}}};
        public void Dispose(){Db.Dispose();App.Dispose();Catalog.Dispose();Orders.Dispose();}
    }
    static JsonElement Json(object value)=>JsonSerializer.SerializeToElement(value,new JsonSerializerOptions{PropertyNamingPolicy=JsonNamingPolicy.CamelCase});

    [Fact]
    public async Task RecoveredNetZeroBatchDoesNotInventCashRemittanceOrLoseRemainingBalance() {
        using var f=new Fixture();await f.Seed(500m,100m);
        f.Db.DailySettlementBatches.Add(new(){BatchCode="recover",CaptainUserId=f.Driver,HandledByAdminId=f.Admin,BatchDate=DateTime.UtcNow,TotalCashCollected=100m,TotalWagesEarned=100m,NetCashRemitted=0m});await f.Db.SaveChangesAsync();
        await f.Settlements.GetCaptainBalanceAsync(f.Driver,"SYP");var payment=Assert.Single(f.Db.Payments);Assert.Equal(0m,payment.Amount);Assert.Equal(400m,payment.NewBalance);Assert.Equal(400m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
    }

    [Fact]
    public async Task PrintedSettlementHistoryIsCompleteAndCurrenciesAreNotAddedTogether() {
        using var f=new Fixture();
        for(var i=0;i<1001;i++) f.Db.SettlementRequests.Add(new(){Id=Guid.NewGuid(),RequestedByUserId=f.Driver,RequestedByName="Driver",PartyType=SettlementPartyType.CaptainEarnings,Amount=1m,Currency=i==0 ? "USD" : "SYP",Status=SettlementRequestStatus.Completed,RequestNumber=$"paid-{i}",CompletedAt=DateTime.UtcNow});
        await f.Db.SaveChangesAsync();var print=await new SettlementHistoryService(f.Db).GetPrintDataAsync(new());Assert.Equal(1001,print.Count);
        var historySummary=await new SettlementHistoryService(f.Db).GetSummaryAsync();Assert.Equal(1000m,historySummary.TotalCompletedAmount);Assert.Equal(2,historySummary.CurrencyTotals.Count);
        var data=Json(Assert.IsType<OkObjectResult>((await f.Controller().DataTable(new(){PageNumber=1,PageSize=10})).Result).Value!);var summary=data.GetProperty("summary");
        Assert.Equal(1000m,summary.GetProperty("totalPaid").GetDecimal());Assert.Equal(2,summary.GetProperty("currencyTotals").GetArrayLength());Assert.Equal(1,summary.GetProperty("uniqueRecipients").GetInt32());
    }

    [Theory]
    [InlineData("purchase")][InlineData("handover")][InlineData("earnings")][InlineData("unfinished")][InlineData("selection")]
    public async Task CaptainSettlementCannotUseReservedMoneyOrSilentlyChangeSelection(string scenario) {
        using var f=new Fixture();await f.Seed(1000m,40m);
        f.Orders.Orders.Add(new Order{Id=1,DeliveryId=f.Driver,DeliveredAt=DateTime.UtcNow,OrderStatus=OrderStatus.Success,ActualCashCollected=1000m,CaptainEarning=40m,CaptainCompensationType=CaptainCompensationType.Percentage,
            AccountingStatus=scenario=="unfinished" ? OrderAccountingStatus.PendingAccounting : OrderAccountingStatus.Posted,
            OrderDetails=new List<OrderDetail>{new(){Quantity=1,SingleFinalPrice=900m,OrderDetailStatus=OrderDetailStatus.Delivered}}});await f.Orders.SaveChangesAsync();
        if(scenario=="purchase") { f.App.SupportMessages.Add(new(){ErrandDriverUserId=f.Driver,ErrandStatus=ErrandStatus.Assigned,ErrandItemPrice=1m});await f.App.SaveChangesAsync(); }
        if(scenario=="handover" || scenario=="earnings") { f.Db.SettlementRequests.Add(new(){Id=Guid.NewGuid(),RequestedByUserId=f.Driver,PartyType=scenario=="handover" ? SettlementPartyType.Captain : SettlementPartyType.CaptainEarnings,Amount=scenario=="handover" ? 0m : 1m,Currency="SYP",Status=SettlementRequestStatus.Pending,RequestNumber="reserved"});await f.Db.SaveChangesAsync(); }
        var result=await f.Captain().ConfirmSettlement(new(){CaptainId=f.Driver,OrderIds=scenario=="selection" ? new(){1,999} : new(){1}});
        Assert.IsType<BadRequestObjectResult>(result.Result);Assert.False(f.Orders.Orders.Single().IsSettled);Assert.Empty(f.Db.DailySettlementBatches);Assert.Equal(1000m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
    }

    [Fact]
    public void AdministrativeFinancialEndpointsRequireAdministrativePermission() {
        foreach(var type in new[]{typeof(AdminPayments),typeof(BillsController),typeof(BalancesController),typeof(CaptainSettlementsController),typeof(DriverCashAdvancesController),typeof(FleetReconciliationController),typeof(SettlementRequestsController)})
            Assert.Equal(nameof(AppPermissionKey.AdminPermission),type.GetCustomAttributes(typeof(AuthorizeAttribute),true).Cast<AuthorizeAttribute>().Single().Policy);
    }
    [Fact]
    public async Task MerchantPaymentStaysPendingUntilMerchantConfirmsThenDebitsOnce() {
        using var f=new Fixture();await f.Seed();var c=f.Controller();var request=f.Request();
        Assert.IsType<OkObjectResult>((await c.Create(request)).Result);Assert.IsType<OkObjectResult>((await c.Create(request)).Result);
        var payment=Assert.Single(f.Db.Payments);Assert.Null(payment.HandoverDate);
        // Admin created it, but nothing has moved yet: courier, merchant and app balances are untouched.
        Assert.Equal(1100m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));Assert.Equal(900m,await f.Ledger.GetMerchantPayableBalanceAsync(30));Assert.Equal(500m,await f.Ledger.GetMerchantPayableBalanceAsync(31));
        Assert.Empty(await f.Db.JournalTransactions.Where(t=>t.ReferenceType=="CaptainToMerchantPayment").ToListAsync());
        f.Balances.Verify(b=>b.UpdateAppBalance(It.IsAny<BalanceDto>()),Times.Never);
        // The amount is reserved on both sides so it cannot be spent or withdrawn twice.
        Assert.Equal(700m,(await f.Safety().GetPositionAsync(f.Driver)).SpendableCash);
        var available=Json(Assert.IsType<OkObjectResult>((await c.AvailableBalances(f.Driver,31)).Result).Value!);
        Assert.Equal(700m,available.GetProperty("deliveryBalance").GetDecimal());Assert.Equal(100m,available.GetProperty("merchantBalance").GetDecimal());
        // Merchant confirms receipt: only now are the accounts updated, and only once.
        var merchantSide=f.Warehouse();Assert.True((await merchantSide.RecivePayment(payment.Id)).Value);Assert.True((await merchantSide.RecivePayment(payment.Id)).Value);
        Assert.NotNull(f.Db.Payments.Single().HandoverDate);
        Assert.Equal(700m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));Assert.Equal(900m,await f.Ledger.GetMerchantPayableBalanceAsync(30));Assert.Equal(100m,await f.Ledger.GetMerchantPayableBalanceAsync(31));
        Assert.Single(await f.Db.JournalTransactions.Where(t=>t.ReferenceType=="CaptainToMerchantPayment").ToListAsync());
        Assert.Equal(700m,(await f.Safety().GetPositionAsync(f.Driver)).SpendableCash);
    }
    [Fact]
    public async Task PendingPaymentReservesCourierCashAgainstASecondPayment() {
        using var f=new Fixture();await f.Seed();var c=f.Controller();Assert.IsType<OkObjectResult>((await c.Create(f.Request())).Result);
        var second=f.Request(800m);second.RequestKey="operation-2";
        Assert.IsType<BadRequestObjectResult>((await c.Create(second)).Result);Assert.Single(f.Db.Payments);
    }
    [Fact]
    public async Task MerchantCannotWithdrawDuesReservedByPendingCourierPayment() {
        using var f=new Fixture();await f.Seed();Assert.IsType<OkObjectResult>((await f.Controller().Create(f.Request())).Result);
        var source=new[]{new MerchantSettlementSource{MerchantId=31,MerchantTitle="Second store"}};
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateMerchantRequestAsync(f.Owner,"Owner","",source,new(){Amount=300m}));
        Assert.Empty(f.Db.SettlementRequests);
        await f.Settlements.CreateMerchantRequestAsync(f.Owner,"Owner","",source,new(){Amount=100m});
    }
    [Theory][InlineData(0)][InlineData(-1)][InlineData(1.005)][InlineData(1000000001)]
    public async Task InvalidPaymentAmountsNeverCreateRecords(decimal amount) {
        using var f=new Fixture();await f.Seed();Assert.IsType<BadRequestObjectResult>((await f.Controller().Create(f.Request(amount))).Result);Assert.Empty(f.Db.Payments);
    }
    [Fact]
    public async Task AmbiguousOwnerCannotSilentlyPayTheFirstStore() {
        using var f=new Fixture();await f.Seed();var request=f.Request();request.MerchantId=0;
        Assert.IsType<BadRequestObjectResult>((await f.Controller().Create(request)).Result);Assert.Empty(f.Db.Payments);
    }
    [Theory][InlineData(true)][InlineData(false)]
    public async Task PaymentCannotConsumeReservedMerchantDuesOrDriverCash(bool merchant) {
        using var f=new Fixture();await f.Seed();var reservation=new SettlementRequest{Id=Guid.NewGuid(),RequestNumber="reserved",RequestedByUserId=merchant?f.Owner:f.Driver,PartyType=merchant?SettlementPartyType.Merchant:SettlementPartyType.Captain,Amount=merchant?300m:800m,Currency="SYP",Status=SettlementRequestStatus.Pending};
        if(merchant)reservation.MerchantAllocations.Add(new(){MerchantId=31,Amount=300m});f.Db.SettlementRequests.Add(reservation);await f.Db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>((await f.Controller().Create(f.Request())).Result);Assert.Empty(f.Db.Payments);
    }
    [Fact]
    public async Task CorrectMerchantPaymentCannotBeReallocatedAgainFromTreasury() {
        using var f=new Fixture();await f.Seed();var c=f.Controller();await c.Create(f.Request());Assert.True((await f.Warehouse().RecivePayment(f.Db.Payments.Single().Id)).Value);var count=f.Db.JournalTransactions.Count();
        Assert.IsType<OkObjectResult>((await c.ReconcileToMerchant(f.Db.Payments.Single().Id)).Result);Assert.Equal(count,f.Db.JournalTransactions.Count());
    }
    [Fact]
    public async Task CreatedPaymentsAppearInHistoryAndGlobalSummaryDoesNotDependOnPage() {
        using var f=new Fixture();await f.Seed();var c=f.Controller();await c.Create(f.Request(100m));var second=f.Request(50.25m);second.RequestKey="operation-2";await c.Create(second);
        foreach(var pending in f.Db.Payments.ToList())Assert.True((await f.Warehouse().RecivePayment(pending.Id)).Value);
        var a=Json(Assert.IsType<OkObjectResult>((await c.DataTable(new(){PageNumber=1,PageSize=1})).Result).Value!);
        var b=Json(Assert.IsType<OkObjectResult>((await c.DataTable(new(){PageNumber=2,PageSize=1})).Result).Value!);
        Assert.Equal(2,a.GetProperty("totalRecords").GetInt32());Assert.Equal(150.25m,a.GetProperty("summary").GetProperty("totalPaid").GetDecimal());Assert.Equal(a.GetProperty("summary").ToString(),b.GetProperty("summary").ToString());Assert.Single(a.GetProperty("items").EnumerateArray());
    }
    [Fact]
    public async Task ZeroCashNetHandoverStillBlocksAnotherPendingRequest() {
        using var f=new Fixture();await f.Seed(100m,100m);
        await f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new(){Amount=0m,Method="cash_to_admin_net"});
        Assert.True((await f.Settlements.GetCaptainBalanceAsync(f.Driver)).HasPendingRequest);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new(){Amount=0m,Method="cash_to_admin_net"}));
    }
    [Theory][InlineData(-1)][InlineData(0)][InlineData(1.005)]
    public async Task InvalidCustodyHandoverAmountsAreNotReplacedWithFullBalance(decimal amount) {
        using var f=new Fixture();await f.Seed();await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new(){Amount=amount}));Assert.Empty(f.Db.SettlementRequests);
    }
    [Fact]
    public async Task NetOffsetPreservesCashReservedForPurchases() {
        using var f=new Fixture();await f.Seed(100m,100m);
        f.App.SupportMessages.Add(new(){Title="Purchase",ErrandDriverUserId=f.Driver,ErrandStatus=App.Shared.Entities.Domain.ErrandStatus.Assigned,ErrandItemPrice=40m});await f.App.SaveChangesAsync();
        var request=await f.Settlements.CreateCaptainRequestAsync(f.Driver,"Driver","",new(){Amount=0m,Method="cash_to_admin_net"});await f.Settlements.AcceptAsync(request.Id,f.Admin);
        Assert.Equal(40m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));Assert.Equal(40m,await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
    }
    [Fact]
    public async Task SubCentLedgerAmountsAreRejectedBeforeDatabaseRounding() {
        using var f=new Fixture();await f.Seed();var accounts=f.Db.Accounts.Take(2).ToArray();var count=f.Db.JournalTransactions.Count();
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Ledger.PostTransactionAsync(new(){Entries=new(){new(){AccountId=accounts[0].Id,Debit=1.005m},new(){AccountId=accounts[1].Id,Credit=1.005m}}}));Assert.Equal(count,f.Db.JournalTransactions.Count());
    }
    [Fact]
    public async Task BillFilterAndSummaryIncludeEveryMatchingPage() {
        using var f=new Fixture();f.Db.Bills.AddRange(new Bill{Id=1,MerchantId=30,TotalAmount=100.5m,MerchantAmount=90.25m,IsAddedToDues=true},new Bill{Id=2,MerchantId=30,TotalAmount=200m,MerchantAmount=180m,IsAddedToDues=true},new Bill{Id=3,MerchantId=30,TotalAmount=300m,MerchantAmount=270m,IsAddedToDues=false});await f.Db.SaveChangesAsync();
        var service=new BillService(new TrackableRepository<Bill,AccountingDbContext>(f.Db));var table=await service.GetDataTableAsync(new(){PageSize=1,PageNumber=1},null,null,true);var summary=await service.GetSummaryAsync(new(),null,true);
        Assert.Equal(2,table.TotalRecords);Assert.Single(table.Items);Assert.Equal(300.5m,summary.TotalBilled);Assert.Equal(270.25m,summary.MerchantShare);Assert.Equal(30.25m,summary.PlatformRevenue);
        Assert.Equal(1,(await service.GetDataTableAsync(new(),null,null,false)).TotalRecords);
    }
    [Fact]
    public async Task PartialCaptainSettlementsHaveUniqueReferencesAndClearBothAmounts() {
        using var f=new Fixture();await f.Seed(2000m,0m);
        for(var id=1;id<=2;id++)f.Orders.Orders.Add(new Order{Id=id,DeliveryId=f.Driver,DeliveredAt=DateTime.UtcNow,OrderStatus=OrderStatus.Success,ActualCashCollected=1000m,DeliveryFee=100m,CaptainCompensationType=CaptainCompensationType.SalariedEmployee,
            OrderDetails=new List<OrderDetail>{new(){Quantity=1,SingleFinalPrice=900m,OrderDetailStatus=OrderDetailStatus.Delivered}}});
        await f.Orders.SaveChangesAsync();var c=f.Captain();
        var a=Assert.IsType<SettlementBatchReceiptDto>(Assert.IsType<OkObjectResult>((await c.ConfirmSettlement(new(){CaptainId=f.Driver,OrderIds=new(){1}})).Result).Value);
        var b=Assert.IsType<SettlementBatchReceiptDto>(Assert.IsType<OkObjectResult>((await c.ConfirmSettlement(new(){CaptainId=f.Driver,OrderIds=new(){2}})).Result).Value);
        Assert.NotEqual(a.BatchId,b.BatchId);Assert.Matches("-[0-9a-f]{32}$",b.BatchId);Assert.Equal(0m,await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(1000m,f.Db.Payments.First().NewBalance);Assert.Equal(2,await f.Db.JournalTransactions.CountAsync(t=>t.ReferenceType=="CaptainSettlement"));
        var history=Json(Assert.IsType<OkObjectResult>((await f.Controller().DataTable(new(){PageNumber=1,PageSize=10})).Result).Value!);
        Assert.Equal(2,history.GetProperty("totalRecords").GetInt32());Assert.Equal(2000m,history.GetProperty("summary").GetProperty("totalPaid").GetDecimal());
    }
    [Fact]
    public async Task PrepaidOrderReceiptKeepsUnpaidEarningsSeparateFromCashOffset() {
        using var f=new Fixture();await f.Seed(0m,40m);
        f.Orders.Orders.Add(new Order{Id=1,DeliveryId=f.Driver,DeliveredAt=DateTime.UtcNow,ActualCashCollected=0m,DeliveryFee=100m,CaptainEarning=40m,CaptainCompensationType=CaptainCompensationType.Percentage,
            OrderStatus=OrderStatus.Success,OrderDetails=new List<OrderDetail>{new(){Quantity=1,SingleFinalPrice=900m,OrderDetailStatus=OrderDetailStatus.Delivered}}});await f.Orders.SaveChangesAsync();
        var c=f.Captain();var first=Assert.IsType<SettlementBatchReceiptDto>(Assert.IsType<OkObjectResult>((await c.ConfirmSettlement(new(){CaptainId=f.Driver,OrderIds=new(){1}})).Result).Value);
        var later=Assert.IsType<SettlementBatchReceiptDto>(Assert.IsType<OkObjectResult>((await c.GetBatchReceipt(first.BatchId)).Result).Value);
        Assert.Equal(40m,first.TotalCaptainEarnings);Assert.Equal(0m,first.WagesOffset);Assert.Equal(first.WagesOffset,later.WagesOffset);Assert.Equal(first.TotalCaptainEarnings,later.TotalCaptainEarnings);
        Assert.Equal(0m,first.NetDueToCompany);Assert.Equal(40m,await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));Assert.Equal(0m,f.Db.Payments.Single().Amount);
    }
    [Fact]
    public async Task MerchantReceiptCannotFinishWhileAccountingIsPending() {
        using var f=new Fixture();await f.Seed();
        var request=await f.Settlements.CreateMerchantRequestAsync(f.Owner,"Owner","",new[]{new MerchantSettlementSource{MerchantId=31,MerchantTitle="Second store"}},new(){Amount=50m});
        await f.Settlements.AcceptAsync(request.Id,f.Admin);
        f.Orders.Orders.Add(new Order{Id=1,AccountingStatus=OrderAccountingStatus.PendingAccounting,OrderDetails=new List<OrderDetail>{new(){MerchantId=31}}});await f.Orders.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(()=>f.Settlements.ConfirmMerchantReceiptAsync(request.Id,f.Owner));Assert.Equal(500m,await f.Ledger.GetMerchantPayableBalanceAsync(31));
    }
}
