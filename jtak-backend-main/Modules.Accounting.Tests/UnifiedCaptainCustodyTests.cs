using App.Orders.Data;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class UnifiedCaptainCustodyTests
{
    [Fact]
    public async Task SummaryStatementAndDriverBalanceFollowAdvanceAndMerchantPayment()
    {
        using var db = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        await db.Database.EnsureCreatedAsync();
        var ledger = new LedgerService(db, NullLogger<LedgerService>.Instance);
        var reconciliation = new EodReconciliationService(db, ledger, null,
            NullLogger<EodReconciliationService>.Instance);
        var driver = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 12, CaptainUserId = driver, CaptainName = "Driver",
            DeliveryFee = 81m, CaptainEarning = 0m,
            MerchantSplits = new()
            {
                new() { MerchantId = 27, MerchantTitle = "Store", TotalAmount = 2745m,
                    MerchantAmount = 2500m, PlatformCommission = 245m },
            },
        });
        var before = Assert.Single(await reconciliation.GetFleetSettlementSummariesAsync());
        Assert.Equal(2826m, before.CashFloatBalance);
        Assert.Equal(1, before.TotalDeliveredOrders);

        var cash = await ledger.GetOrCreateUserAccountAsync(driver, AccountType.Asset,
            SystemAccountCodes.CaptainCashFloatPrefix, "Driver cash");
        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
            "Vault", AccountType.Asset);
        await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "CaptainCashAdvance", ReferenceId = "advance", IdempotencyKey = "advance",
            Entries = new()
            {
                new() { AccountId = cash.Id, Debit = 174m },
                new() { AccountId = vault.Id, Credit = 174m },
            },
        });
        var afterAdvance = Assert.Single(await reconciliation.GetFleetSettlementSummariesAsync());
        Assert.Equal(3000m, afterAdvance.CashFloatBalance);
        Assert.Equal(1, afterAdvance.TotalDeliveredOrders);

        await ledger.PostCaptainToMerchantPaymentAsync(driver, 27, 470m, "payment-8");
        // Retrying the same payment must not debit custody a second time.
        await ledger.PostCaptainToMerchantPaymentAsync(driver, 27, 470m, "payment-8");
        var summary = Assert.Single(await reconciliation.GetFleetSettlementSummariesAsync());
        Assert.Equal(2530m, summary.CashFloatBalance);
        Assert.Equal(2530m, summary.ExpectedNetCashDue);
        Assert.Equal(1, summary.TotalDeliveredOrders);
        var statement = await reconciliation.GetCaptainShiftDetailsAsync(driver);
        Assert.Equal(summary.CashFloatBalance, statement.CashFloatBalance);
        Assert.Equal(3, statement.FloatStatement.Count);
        var driverBalance = await new SettlementRequestService(db, ledger,
            NullLogger<SettlementRequestService>.Instance).GetCaptainBalanceAsync(driver);
        Assert.Equal(summary.CashFloatBalance, driverBalance.GrossAmount);
        Assert.Equal(summary.ExpectedNetCashDue, driverBalance.NetCashDue);

        var settled = await reconciliation.SettleCaptainShiftAsync(new()
        {
            CaptainUserId = driver, PhysicalCashReceived = 2530m, Currency = "SYP",
        }, Guid.NewGuid());
        Assert.Equal(2530m, settled.ExpectedNetCash);
        Assert.Equal(0m, settled.DiscrepancyAmount);
        var afterSettlement = Assert.Single(await reconciliation.GetFleetSettlementSummariesAsync());
        Assert.Equal(0m, afterSettlement.CashFloatBalance);
        Assert.Equal(1, afterSettlement.TotalDeliveredOrders);
    }

    [Fact]
    public async Task LedgerFallbackOrderCountTranslatesToRelationalSql()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        using var db = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseSqlite(connection).Options, null);
        await db.Database.EnsureCreatedAsync();
        var ledger = new LedgerService(db, NullLogger<LedgerService>.Instance);
        var driver = Guid.NewGuid();
        await ledger.PostOrderDeliveredSplitAsync(new()
        {
            OrderId = 15, CaptainUserId = driver, DeliveryFee = 100m, CaptainEarning = 40m,
            MerchantSplits = new()
            {
                new() { MerchantId = 12, MerchantTitle = "Market", TotalAmount = 1000m,
                    MerchantAmount = 900m, PlatformCommission = 100m },
            },
        });
        var cash = await ledger.GetOrCreateUserAccountAsync(driver, AccountType.Asset,
            SystemAccountCodes.CaptainCashFloatPrefix, "Driver cash");
        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
            "Vault", AccountType.Asset);
        await ledger.PostTransactionAsync(new()
        {
            ReferenceType = "CaptainCashAdvance", ReferenceId = "advance",
            Entries = new() { new() { AccountId = cash.Id, Debit = 200m }, new() { AccountId = vault.Id, Credit = 200m } },
        });
        // SQLite cannot SUM decimal balances. Isolate the new count SQL query;
        // the financial-flow test above uses the real ledger for all balances.
        var balances = new Mock<ILedgerService>();
        balances.Setup(x => x.GetAccountBalanceAsync(It.IsAny<Guid>())).ReturnsAsync(0m);
        var summary = Assert.Single(await new EodReconciliationService(db, balances.Object, null,
            NullLogger<EodReconciliationService>.Instance).GetFleetSettlementSummariesAsync());
        Assert.Equal(1, summary.TotalDeliveredOrders);
    }

    [Fact]
    public async Task LedgerFallbackCountsAnOrderOnceAcrossCashAndEarningsEntries()
    {
        using var db = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        var ledger = new LedgerService(db, NullLogger<LedgerService>.Instance);
        await ledger.PostOrderDeliveredSplitAsync(new()
        {
            OrderId = 15, CaptainUserId = Guid.NewGuid(), DeliveryFee = 100m, CaptainEarning = 40m,
            MerchantSplits = new()
            {
                new() { MerchantId = 12, MerchantTitle = "Market", TotalAmount = 1000m,
                    MerchantAmount = 900m, PlatformCommission = 100m },
            },
        });
        var summary = Assert.Single(await new EodReconciliationService(db, ledger, null,
            NullLogger<EodReconciliationService>.Instance).GetFleetSettlementSummariesAsync());
        Assert.Equal(1, summary.TotalDeliveredOrders);
        Assert.Equal(40m, summary.WagesEarnedBalance);
        Assert.Equal(1060m, summary.ExpectedNetCashDue);
    }

    [Fact]
    public async Task AuthoritativeOrderCountIncludesPrepaidDeliveriesAndExcludesUnfinishedOrders()
    {
        using var db = new AccountingDbContext(new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        using var orders = new OrdersDbContext(new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, null);
        var driver = Guid.NewGuid();
        orders.Orders.AddRange(
            new Order { Id = 1, DeliveryId = driver, DeliveredAt = DateTime.UtcNow, ActualCashCollected = 100m },
            new Order { Id = 2, DeliveryId = driver, DeliveredAt = DateTime.UtcNow, ActualCashCollected = 0m },
            new Order { Id = 3, DeliveryId = driver },
            new Order { Id = 4, DeliveryId = Guid.NewGuid(), DeliveredAt = DateTime.UtcNow });
        await orders.SaveChangesAsync();
        var ledger = new LedgerService(db, NullLogger<LedgerService>.Instance);
        await ledger.GetOrCreateUserAccountAsync(driver, AccountType.Asset,
            SystemAccountCodes.CaptainCashFloatPrefix, "Driver cash");
        var summary = Assert.Single(await new EodReconciliationService(db, ledger, null,
            NullLogger<EodReconciliationService>.Instance, ordersContext: orders)
            .GetFleetSettlementSummariesAsync());
        Assert.Equal(2, summary.TotalDeliveredOrders);
        Assert.Equal(0m, summary.CashFloatBalance);
    }
}
