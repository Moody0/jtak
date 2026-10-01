using App.Shared.Services.Pricing;
using App.Shared.Services.Extentions;
using App.Shared.Entities;
using App.Shared.Services;
using System;
using System.Linq;
using System.Threading.Tasks;
using App.Orders.Data;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Moq;
using Solf.Base;
using Xunit;

namespace Modules.Accounting.Tests;

public sealed class DriverEarningsWalletTests
{
    private sealed class Fixture : IDisposable
    {
        public readonly Guid Driver = Guid.NewGuid();
        public readonly Guid Admin = Guid.NewGuid();
        public readonly AccountingDbContext Db = new(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).AddInterceptors(new LedgerImmutabilityInterceptor()).Options, null);
        public LedgerService Ledger { get; }
        public SettlementRequestService Service { get; }
        public Fixture()
        {
            Ledger = new(Db, NullLogger<LedgerService>.Instance);
            Service = new(Db, Ledger, NullLogger<SettlementRequestService>.Instance);
        }
        public Task Deliver(int id = 61, decimal wage = 50m, bool isCod = false) => Ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = id, CaptainUserId = Driver, CaptainEarning = wage, DeliveryFee = 100m, IsCod = isCod,
            MerchantSplits = new() { new() { MerchantId = 44, TotalAmount = 1887m, MerchantAmount = 1700m, PlatformCommission = 187m } }
        });
        public Task<SettlementRequestDto> Request(decimal? amount = null) => Service.CreateCaptainEarningsRequestAsync(
            Driver, "QA Driver", "0900000000", new() { Amount = amount });
        public async Task Remit()
        {
            var request = await Service.CreateCaptainRequestAsync(Driver, "QA Driver", null, new());
            await Service.AcceptAsync(request.Id, Admin);
        }
        public void Dispose() => Db.Dispose();
    }

    [Theory]
    [InlineData(0)] [InlineData(50)] [InlineData(100)] [InlineData(150)]
    public async Task DriverWageNeverChangesCustomerCash(decimal wage)
    {
        using var f = new Fixture();
        var calc = new OrderMoneyCalculationService();
        var money = calc.CalculateOrderMoney(new[] { new OrderDetailDto
            { Quantity = 1, SingleFinalPrice = 1887m, MerchantId = 44, OrderDetailStatus = OrderDetailStatus.Delivered } },
            100m, PaymentMethod.PayOnDelivery, captainEarning: wage);
        Assert.Equal(1987m, money.CashToCollect);
        Assert.Equal(1987m, money.GrandTotal);
        await f.Deliver(wage: wage, isCod: true);
        Assert.Equal(1987m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(wage, (await f.Service.GetCaptainEarningsAsync(f.Driver)).TotalEarned);
        var entries = await f.Db.LedgerEntries.ToListAsync();
        Assert.Equal(entries.Sum(x => x.Debit), entries.Sum(x => x.Credit));
    }

    [Fact]
    public async Task FullFlow_ApprovalOnlyReserves_ActualPaymentChangesWagesAndVault_NotCustody()
    {
        using var f = new Fixture();
        await f.Deliver(wage: 50m, isCod: false);
        var request = await f.Request(25m);
        Assert.Equal(SettlementPartyType.CaptainEarnings, request.PartyType);
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.TotalEarned); Assert.Equal(25m, wallet.AvailableAmount);
        Assert.Equal(25m, wallet.PendingAmount); Assert.Equal(0m, wallet.TotalPaid);
        await f.Service.AcceptAsync(request.Id, f.Admin);
        Assert.Equal(50m, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
        Assert.Equal(0m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));

        var vault = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        var revenue = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "Revenue", AccountType.Revenue);
        await f.Ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "Funding", ReferenceId = "F1", Entries = new()
            {
                new() { AccountId = vault.Id, Debit = 100m }, new() { AccountId = revenue.Id, Credit = 100m }
            }
        });

        var completed = await f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin);
        Assert.Equal(SettlementRequestStatus.Completed, completed.Status);
        var again = await f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin);
        Assert.Equal(completed.LedgerTransactionId, again.LedgerTransactionId);
        wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.TotalEarned); Assert.Equal(25m, wallet.TotalPaid);
        Assert.Equal(25m, wallet.GrossAmount); Assert.Equal(25m, wallet.AvailableAmount);
        Assert.Equal(0m, wallet.PendingAmount);
        Assert.Equal(0m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(75m, await f.Ledger.GetAccountBalanceAsync(vault.Id));
        Assert.Single(await f.Db.JournalTransactions.Where(x => x.ReferenceType == "CaptainEarningsPayout").ToListAsync());
    }

    [Theory]
    [InlineData(false)] [InlineData(true)]
    public async Task RejectBeforePaymentReleasesReservation(bool approveFirst)
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false);
        var request = await f.Request();
        if (approveFirst) await f.Service.AcceptAsync(request.Id, f.Admin);
        await f.Service.RejectAsync(request.Id, f.Admin, "QA rejection");
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.AvailableAmount); Assert.Equal(0m, wallet.TotalPaid);
        Assert.False(wallet.HasPendingRequest);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin));
    }

    [Theory]
    [InlineData(0)] [InlineData(-1)] [InlineData(51)] [InlineData(1.001)]
    public async Task InvalidAmountsCannotBeReserved(decimal amount)
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Request(amount));
        Assert.Empty(await f.Db.SettlementRequests.ToListAsync());
    }

    [Fact]
    public async Task NoWagesOrAnotherDriverCashCannotFundWithdrawal()
    {
        using var f = new Fixture();
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Request());
        await f.Deliver(wage: 50m, isCod: false);
        var other = await f.Service.GetCaptainEarningsAsync(Guid.NewGuid());
        Assert.Equal(0m, other.TotalEarned); Assert.Empty(other.Requests);
        await f.Request(20m);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Request(20m));
        Assert.Equal(20m, (await f.Service.GetCaptainEarningsAsync(f.Driver)).PendingAmount);
    }

    [Fact]
    public async Task InsufficientVaultAndUnapprovedRequestNeverPostPayout()
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false); var request = await f.Request();
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin));
        await f.Service.AcceptAsync(request.Id, f.Admin);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin));
        Assert.Equal(50m, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
        Assert.Equal(0m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Empty(await f.Db.JournalTransactions.Where(x => x.ReferenceType == "CaptainEarningsPayout").ToListAsync());
    }

    [Fact]
    public async Task EodCannotSpendReservedWages_OffsetOnceReleasedIsReportedAsPaid()
    {
        using var f = new Fixture();
        await f.Deliver(wage: 50m, isCod: false);
        var request = await f.Request(25m);
        // Driver delivers a COD order of 1987 cash float, 0 wage
        await f.Deliver(62, wage: 0m, isCod: true);
        var eod = new EodReconciliationService(f.Db, f.Ledger, null, NullLogger<EodReconciliationService>.Instance);
        var settlement = new SettleCaptainShiftRequest { CaptainUserId = f.Driver, PhysicalCashReceived = 1962m };
        // Active payout request prevents EOD reconciliation
        await Assert.ThrowsAsync<InvalidOperationException>(() => eod.SettleCaptainShiftAsync(settlement, f.Admin));
        Assert.Equal(1987m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        // Rejecting payout releases the reserved 25 wages
        await f.Service.RejectAsync(request.Id, f.Admin);
        // EOD can now offset all 50 wages against the 1987 float: expected physical cash = 1987 - 50 = 1937
        settlement.PhysicalCashReceived = 1937m;
        await eod.SettleCaptainShiftAsync(settlement, f.Admin);
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.TotalEarned); Assert.Equal(50m, wallet.TotalPaid);
        Assert.Equal(0m, wallet.GrossAmount); Assert.Equal(0m, wallet.AvailableAmount);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Request());
    }

    [Fact]
    public async Task FreshDeliveryAfterReservationIsNotConsumedByOldRequest_HistoryIsPayoutNotDeposit()
    {
        using var f = new Fixture();
        await f.Deliver(wage: 50m, isCod: false);
        var request = await f.Request();
        await f.Service.AcceptAsync(request.Id, f.Admin);
        await f.Deliver(62, 75m, isCod: false);
        var vault = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        var revenue = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "Revenue", AccountType.Revenue);
        await f.Ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "Funding", ReferenceId = "F2", Entries = new()
            {
                new() { AccountId = vault.Id, Debit = 100m }, new() { AccountId = revenue.Id, Credit = 100m }
            }
        });
        await f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin);
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(125m, wallet.TotalEarned); Assert.Equal(50m, wallet.TotalPaid);
        Assert.Equal(75m, wallet.AvailableAmount);
        var history = new SettlementHistoryService(f.Db);
        var receipt = await history.GetReceiptAsync(request.Id.ToString());
        Assert.Equal(SettlementPartyType.CaptainEarnings, receipt.PartyType);
        Assert.Contains("صرف مستحقات سائق", receipt.ReceiptTitle);
        Assert.Null(receipt.CaptainCashFloatAccount);
        var page = await history.GetDataTableAsync(new() { PartyFilter = SettlementHistoryPartyFilter.Captain });
        Assert.Contains(page.Items, x => x.Id == request.Id.ToString() && x.DriverId == f.Driver && x.OperationType == "صرف مستحقات سائق");
    }

    [Fact]
    public async Task ConcurrentRequestsAcrossRelationalContextsReserveOnlyOnce()
    {
        var connectionString = new SqliteConnectionStringBuilder
        { DataSource = $"wallet-{Guid.NewGuid():N}", Mode = SqliteOpenMode.Memory, Cache = SqliteCacheMode.Shared }.ToString();
        await using var keepAlive = new SqliteConnection(connectionString);
        await keepAlive.OpenAsync();
        AccountingDbContext Context() => new(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseSqlite(connectionString).AddInterceptors(new LedgerImmutabilityInterceptor()).Options, null);
        await using var setup = Context(); await setup.Database.EnsureCreatedAsync();
        var driver = Guid.NewGuid();
        var ledger = new LedgerService(setup, NullLogger<LedgerService>.Instance);
        var wages = await ledger.GetOrCreateUserAccountAsync(driver, AccountType.Liability,
            SystemAccountCodes.CaptainEarningsPrefix, "QA wages");
        var expense = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.DriverEarningSubsidyExpense, "Expense", AccountType.Expense);
        await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "OrderDelivery", ReferenceId = "QA", Entries = new()
            {
                new() { AccountId = expense.Id, Debit = 50m }, new() { AccountId = wages.Id, Credit = 50m }
            }
        });
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<bool> Submit()
        {
            await start.Task;
            await using var context = Context();
            var service = new SettlementRequestService(context,
                new LedgerService(context, NullLogger<LedgerService>.Instance), NullLogger<SettlementRequestService>.Instance);
            try { await service.CreateCaptainEarningsRequestAsync(driver, "QA", null, new()); return true; }
            catch (InvalidOperationException) { return false; }
            catch (SqliteException ex) when (ex.SqliteErrorCode == 5 || ex.SqliteErrorCode == 6) { return false; }
        }
        var first = Task.Run(Submit); var second = Task.Run(Submit);
        start.SetResult();
        var results = await Task.WhenAll(first, second);
        Assert.Single(results.Where(x => x));
        await using var verify = Context();
        var requests = await verify.SettlementRequests.AsNoTracking().ToListAsync();
        Assert.Single(requests); Assert.Equal(50m, requests[0].Amount);

        // SQLite cannot translate SUM(decimal). Adapt only that aggregate in
        // the test double; accounts, journals, indexes and transactions are real.
        ILedgerService PaymentLedger(AccountingDbContext db)
        {
            var actual = new LedgerService(db, NullLogger<LedgerService>.Instance);
            var mock = new Mock<ILedgerService>(MockBehavior.Strict);
            mock.Setup(x => x.GetUserCashFloatBalanceAsync(It.IsAny<Guid>(), It.IsAny<string>()))
                .Returns(async (Guid userId, string currency) => {
                    var cash = await db.Accounts.FirstOrDefaultAsync(x => x.OwnerUserId == userId &&
                        x.Type == AccountType.Asset && x.Currency == currency &&
                        x.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
                    if (cash == null) return 0m;
                    var entries = await db.LedgerEntries.Where(x => x.AccountId == cash.Id).ToListAsync();
                    return entries.Sum(x => x.Debit - x.Credit);
                });
            mock.Setup(x => x.GetOrCreateUserAccountAsync(It.IsAny<Guid>(), It.IsAny<AccountType>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns((Guid id, AccountType type, string prefix, string name, string currency) => actual.GetOrCreateUserAccountAsync(id, type, prefix, name, currency));
            mock.Setup(x => x.GetOrCreateSystemAccountAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<AccountType>(), It.IsAny<string>()))
                .Returns((string code, string name, AccountType type, string currency) => actual.GetOrCreateSystemAccountAsync(code, name, type, currency));
            mock.Setup(x => x.PostTransactionAsync(It.IsAny<PostTransactionRequest>())).Returns((PostTransactionRequest r) => actual.PostTransactionAsync(r));
            mock.Setup(x => x.GetAccountBalanceAsync(It.IsAny<Guid>())).Returns(async (Guid id) =>
            {
                var account = await db.Accounts.SingleAsync(x => x.Id == id);
                var entries = await db.LedgerEntries.Where(x => x.AccountId == id).ToListAsync();
                var debitBalance = entries.Sum(x => x.Debit - x.Credit);
                return account.Type == AccountType.Asset || account.Type == AccountType.Expense ? debitBalance : -debitBalance;
            });
            return mock.Object;
        }
        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "QA vault", AccountType.Asset);
        var revenue = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.PlatformDeliveryFeeRevenue, "QA revenue", AccountType.Revenue);
        await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "QA funding", ReferenceId = "QA", Entries = new()
            {
                new() { AccountId = vault.Id, Debit = 100m }, new() { AccountId = revenue.Id, Credit = 100m }
            }
        });
        var review = new SettlementRequestService(verify, PaymentLedger(verify), NullLogger<SettlementRequestService>.Instance);
        await review.AcceptAsync(requests[0].Id, Guid.NewGuid());
        var payStart = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<Guid?> Pay()
        {
            await payStart.Task;
            await using var context = Context();
            var service = new SettlementRequestService(context, PaymentLedger(context), NullLogger<SettlementRequestService>.Instance);
            try { return (await service.CompleteCaptainEarningsPayoutAsync(requests[0].Id, Guid.NewGuid())).LedgerTransactionId; }
            catch (SqliteException ex) when (ex.SqliteErrorCode == 5 || ex.SqliteErrorCode == 6) { return null; }
        }
        var payment1 = Task.Run(Pay); var payment2 = Task.Run(Pay); payStart.SetResult();
        var payments = await Task.WhenAll(payment1, payment2);
        Assert.Contains(payments, x => x.HasValue);
        Assert.Single(payments.Where(x => x.HasValue).Distinct());
        await using var final = Context();
        Assert.Single(await final.JournalTransactions.Where(x => x.ReferenceType == "CaptainEarningsPayout").ToListAsync());
        var finalEntries = await final.LedgerEntries.Where(x => x.AccountId == wages.Id).ToListAsync();
        Assert.Equal(0m, finalEntries.Sum(x => x.Credit - x.Debit));
        var vaultEntries = await final.LedgerEntries.Where(x => x.AccountId == vault.Id).ToListAsync();
        Assert.Equal(50m, vaultEntries.Sum(x => x.Debit - x.Credit));
    }

    [Fact]
    public async Task EarningsApprovalNotificationNeverClaimsPayment_AndTargetsOnlyDeliveryApp()
    {
        Notification? captured = null;
        var notifications = new Mock<INotificationService>();
        notifications.Setup(x => x.SendPushNotification(It.IsAny<Notification>(), It.IsAny<Guid[]>(), It.IsAny<bool>(), It.IsAny<bool>()))
            .Callback<Notification, Guid[], bool, bool>((n, _, _, _) => captured = n).Returns(Task.CompletedTask);
        await notifications.Object.SendDeliveryEarningsStatus(Guid.NewGuid(), "QA", 25.5m, "approved");
        Assert.Equal("delivery", captured!.AudienceApp);
        Assert.Contains("لم يتم الدفع بعد", captured.TextAr);
        Assert.Equal("driver-earnings:QA:approved", captured.EventKey);
        await notifications.Object.SendDeliveryEarningsStatus(Guid.NewGuid(), "QA", 25.5m, "completed");
        Assert.Contains("تم تسجيل دفع", captured!.TextAr);
        Assert.Equal("driver-earnings:QA:completed", captured.EventKey);
    }

    [Fact]
    public async Task CancellationReversalRemovesWages_NotReportedAsPaid_AndCannotCompleteReservedRequest()
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false); var request = await f.Request();
        await f.Service.AcceptAsync(request.Id, f.Admin);
        await f.Ledger.PostOrderCancellationReversalAsync(61, "QA reversal");
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(0m, wallet.TotalEarned); Assert.Equal(0m, wallet.TotalPaid);
        Assert.Equal(0m, wallet.AvailableAmount);
        await Assert.ThrowsAsync<InvalidOperationException>(() => f.Service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin));
        await f.Service.RejectAsync(request.Id, f.Admin);
        Assert.False((await f.Service.GetCaptainEarningsAsync(f.Driver)).HasPendingRequest);
    }

    [Fact]
    public async Task WagesWithNoCashCustodyMustUsePayout_NotEmptyEodJournal()
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false);
        var eod = new EodReconciliationService(f.Db, f.Ledger, null, NullLogger<EodReconciliationService>.Instance);
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => eod.SettleCaptainShiftAsync(
            new() { CaptainUserId = f.Driver, PhysicalCashReceived = 0m }, f.Admin));
        Assert.Contains("طلب صرف مستحقات", error.Message);
        Assert.Equal(50m, (await f.Service.GetCaptainEarningsAsync(f.Driver)).AvailableAmount);
    }

    [Fact]
    public async Task PendingAccountingBlocksReservationApprovalAndPayment_UntilItCompletes()
    {
        using var f = new Fixture(); await f.Deliver(wage: 50m, isCod: false);
        using var orders = new OrdersDbContext(new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        var pending = new Order { Id = 991, UserId = Guid.NewGuid(), DeliveryId = f.Driver,
            AccountingStatus = OrderAccountingStatus.PendingAccounting };
        orders.Orders.Add(pending); await orders.SaveChangesAsync();
        var service = new SettlementRequestService(f.Db, f.Ledger, NullLogger<SettlementRequestService>.Instance, orders);
        var wallet = await service.GetCaptainEarningsAsync(f.Driver);
        Assert.True(wallet.HasPendingAccountingOrders); Assert.Equal(0m, wallet.AvailableAmount);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateCaptainEarningsRequestAsync(f.Driver, "QA", null, new()));
        pending.AccountingStatus = OrderAccountingStatus.Posted; await orders.SaveChangesAsync();
        var request = await service.CreateCaptainEarningsRequestAsync(f.Driver, "QA", null, new());
        pending.AccountingStatus = OrderAccountingStatus.PendingAccounting; await orders.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.AcceptAsync(request.Id, f.Admin));
        pending.AccountingStatus = OrderAccountingStatus.Posted; await orders.SaveChangesAsync();
        await service.AcceptAsync(request.Id, f.Admin);
        pending.AccountingStatus = OrderAccountingStatus.PendingAccounting; await orders.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CompleteCaptainEarningsPayoutAsync(request.Id, f.Admin));
        Assert.Equal(50m, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));
    }

    [Fact]
    public async Task SmartNetting_CustodyCoveringEarnings_DisablesPayoutAndComputesNet()
    {
        using var f = new Fixture();
        // Driver collects 1,987 COD cash and earns 50 wage
        await f.Deliver(wage: 50m, isCod: true);

        var balance = await f.Service.GetCaptainBalanceAsync(f.Driver);
        Assert.Equal(1987m, balance.GrossAmount);
        Assert.Equal(1987m, balance.CustodyBalance);
        Assert.Equal(50m, balance.WagesOffset);
        Assert.Equal(1937m, balance.NetCashDue);
        Assert.True(balance.IsCoveredByCustody);

        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.GrossAmount);
        Assert.Equal(1987m, wallet.CustodyBalance);
        Assert.Equal(50m, wallet.WagesOffset);
        Assert.Equal(1937m, wallet.NetCashDue);
        Assert.True(wallet.IsCoveredByCustody);

        // Driver cannot request payout because it is covered by custody
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => f.Request());
        Assert.Contains("مستحقاتك مغطاة بالكامل من العهدة النقدية", ex.Message);
    }

    [Fact]
    public async Task SmartNetting_CustodyHandoverWithNetRemittance_ClearsBothFloatAndWages()
    {
        using var f = new Fixture();
        // Driver collects 1,987 COD cash and earns 50 wage
        await f.Deliver(wage: 50m, isCod: true);

        // Request custody handover - defaults to net remittance (1937)
        var request = await f.Service.CreateCaptainRequestAsync(f.Driver, "QA Driver", null, new() { Amount = 1937m });
        Assert.Equal(1937m, request.Amount);

        // Admin accepts custody handover
        var result = await f.Service.AcceptAsync(request.Id, f.Admin);
        Assert.Equal(SettlementRequestStatus.Completed, result.Status);

        // Check balances: both cash float AND driver earnings are now ZERO
        Assert.Equal(0m, await f.Ledger.GetUserCashFloatBalanceAsync(f.Driver));
        Assert.Equal(0m, await f.Ledger.GetUserEarningsBalanceAsync(f.Driver));

        // Company vault received the net physical cash (1937)
        var vault = await f.Ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        Assert.Equal(1937m, await f.Ledger.GetAccountBalanceAsync(vault.Id));

        // Wallet reflects that 50 wages was paid / offset
        var wallet = await f.Service.GetCaptainEarningsAsync(f.Driver);
        Assert.Equal(50m, wallet.TotalEarned);
        Assert.Equal(50m, wallet.TotalPaid);
        Assert.Equal(0m, wallet.GrossAmount);
        Assert.Equal(0m, wallet.AvailableAmount);
    }

    [Fact]
    public async Task SmartNetting_CustodyLessThanEarnings_CanOnlyRequestUncoveredPortion()
    {
        using var f = new Fixture();
        var driver2 = Guid.NewGuid();
        await f.Ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 999, CaptainUserId = driver2, CaptainEarning = 250m, DeliveryFee = 20m, IsCod = true,
            MerchantSplits = new() { new() { MerchantId = 44, TotalAmount = 80m, MerchantAmount = 70m, PlatformCommission = 10m } }
        });
        // Driver2 collected 100 COD cash and earned 250 wage.
        var balance = await f.Service.GetCaptainBalanceAsync(driver2);
        Assert.Equal(100m, balance.GrossAmount);
        Assert.Equal(100m, balance.WagesOffset);
        Assert.Equal(0m, balance.NetCashDue);
        Assert.False(balance.IsCoveredByCustody);

        var wallet = await f.Service.GetCaptainEarningsAsync(driver2);
        Assert.Equal(250m, wallet.GrossAmount);
        Assert.Equal(100m, wallet.WagesOffset);
        Assert.False(wallet.IsCoveredByCustody);

        // Driver cannot request 250 (which would include the 100 already held in cash float)
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            f.Service.CreateCaptainEarningsRequestAsync(driver2, "Driver 2", null, new() { Amount = 250m }));
        Assert.Contains("المبلغ المطلوب يتجاوز المستحقات غير المغطاة بالعهدة النقدية", ex.Message);

        // Driver can request uncovered portion (250 - 100 = 150)
        var req = await f.Service.CreateCaptainEarningsRequestAsync(driver2, "Driver 2", null, new() { Amount = 150m });
        Assert.Equal(150m, req.Amount);
    }

    [Fact]
    public async Task SmartNetting_CustodyHandoverWithZeroNetRemittance_ClearsBothFloatAndWages()
    {
        using var f = new Fixture();
        var driver3 = Guid.NewGuid();
        await f.Ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 1001, CaptainUserId = driver3, CaptainEarning = 100m, DeliveryFee = 20m, IsCod = true,
            MerchantSplits = new() { new() { MerchantId = 44, TotalAmount = 80m, MerchantAmount = 70m, PlatformCommission = 10m } }
        });
        // Driver collected 100 COD cash and earned 100 wage.
        var balance = await f.Service.GetCaptainBalanceAsync(driver3);
        Assert.Equal(100m, balance.GrossAmount);
        Assert.Equal(100m, balance.WagesOffset);
        Assert.Equal(0m, balance.NetCashDue);
        Assert.True(balance.IsCoveredByCustody);

        // Driver requests net custody handover (0 SYP)
        var request = await f.Service.CreateCaptainRequestAsync(driver3, "Driver 3", null, new() { Method = "cash_to_admin_net" });
        Assert.Equal(0m, request.Amount);
        Assert.Equal("cash_to_admin_net", request.Method);

        // Admin accepts the zero-cash net handover
        var result = await f.Service.AcceptAsync(request.Id, f.Admin);
        Assert.Equal(SettlementRequestStatus.Completed, result.Status);

        // Float and wages both cleared to zero
        Assert.Equal(0m, await f.Ledger.GetUserCashFloatBalanceAsync(driver3));
        Assert.Equal(0m, await f.Ledger.GetUserEarningsBalanceAsync(driver3));

        // Wallet reflects full 100 wage was settled via custody offset
        var wallet = await f.Service.GetCaptainEarningsAsync(driver3);
        Assert.Equal(100m, wallet.TotalPaid);
        Assert.Equal(0m, wallet.AvailableAmount);
    }
}
