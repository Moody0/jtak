using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Xunit;

namespace Modules.Accounting.Tests;

public class SettlementRequestServiceTests
{
    private static AccountingDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .AddInterceptors(new LedgerImmutabilityInterceptor())
            .Options;
        return new AccountingDbContext(options, null);
    }

    [Fact]
    public async Task FullCycle_CaptainRemitsCash_ThenMerchantReceivesPayout()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var captainId = Guid.NewGuid();
        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 8123,
            CaptainUserId = captainId,
            CaptainName = "Captain One",
            DeliveryFee = 5_000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 44, MerchantTitle = "External Store", TotalAmount = 100_000m, MerchantAmount = 90_000m, PlatformCommission = 10_000m }
            }
        });

        var captainRequest = await service.CreateCaptainRequestAsync(captainId, "Captain One", "0900000000", new CreateSettlementRequestDto());
        Assert.Equal(105_000m, captainRequest.Amount);
        var captainCompleted = await service.AcceptAsync(captainRequest.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Completed, captainCompleted.Status);
        Assert.Equal(0m, await ledger.GetUserCashFloatBalanceAsync(captainId));

        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        Assert.Equal(105_000m, await ledger.GetAccountBalanceAsync(vault.Id));

        var merchantRequest = await service.CreateMerchantRequestAsync(
            merchantOwnerId,
            "External Store Owner",
            "0911111111",
            new[] { new MerchantSettlementSource { MerchantId = 44, MerchantTitle = "External Store" } },
            new CreateSettlementRequestDto { Amount = 90_000m, Method = "cash_in_store", AccountDetails = "Store cashier" });
        Assert.Equal(SettlementRequestStatus.Pending, merchantRequest.Status);

        var approved = await service.AcceptAsync(merchantRequest.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Approved, approved.Status);
        Assert.Equal(90_000m, await ledger.GetMerchantPayableBalanceAsync(44));

        var completed = await service.CompleteMerchantPayoutAsync(merchantRequest.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Completed, completed.Status);
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(44));
        Assert.Equal(15_000m, await ledger.GetAccountBalanceAsync(vault.Id));
    }

    [Fact]
    public async Task ActiveMerchantRequest_ReservesAvailableBalance()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var captainId = Guid.NewGuid();
        var ownerId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 9123,
            CaptainUserId = captainId,
            DeliveryFee = 0m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 9, MerchantTitle = "Shop", TotalAmount = 50_000m, MerchantAmount = 45_000m, PlatformCommission = 5_000m }
            }
        });

        await service.CreateMerchantRequestAsync(ownerId, "Owner", null,
            new[] { new MerchantSettlementSource { MerchantId = 9, MerchantTitle = "Shop" } },
            new CreateSettlementRequestDto { Amount = 20_000m });

        var balance = await service.GetMerchantBalanceAsync(new[] { 9 });
        Assert.Equal(45_000m, balance.GrossAmount);
        Assert.Equal(20_000m, balance.PendingAmount);
        Assert.Equal(25_000m, balance.AvailableAmount);
    }

    [Fact]
    public async Task MerchantPayout_CannotCompleteUntilVaultHasEnoughCash()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var ownerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 10123,
            CaptainUserId = Guid.NewGuid(),
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 19, MerchantTitle = "Shop", TotalAmount = 50_000m, MerchantAmount = 45_000m, PlatformCommission = 5_000m }
            }
        });

        var request = await service.CreateMerchantRequestAsync(ownerId, "Owner", null,
            new[] { new MerchantSettlementSource { MerchantId = 19, MerchantTitle = "Shop" } },
            new CreateSettlementRequestDto { Amount = 45_000m });
        await service.AcceptAsync(request.Id, adminId);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CompleteMerchantPayoutAsync(request.Id, adminId));
        Assert.Contains("رصيد خزينة جيتك غير كافٍ", error.Message);
        Assert.Equal(45_000m, await ledger.GetMerchantPayableBalanceAsync(19));
    }

    [Fact]
    public async Task JtakMarketSale_DoesNotCreateMerchantPayable()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var captainId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 11123,
            CaptainUserId = captainId,
            TotalsIncludeDeliveryFee = true,
            DeliveryFee = 5_000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new()
                {
                    MerchantId = 1,
                    MerchantTitle = "JTAK Market",
                    TotalAmount = 100_000m,
                    MerchantAmount = 80_000m,
                    PlatformCommission = 20_000m,
                    CaptainEarningAmount = 5_000m,
                    IsPlatformOwned = true
                }
            }
        });

        Assert.Equal(100_000m, await ledger.GetUserCashFloatBalanceAsync(captainId));
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(1));
        var marketRevenue = await ledger.GetOrCreateSystemAccountAsync(
            SystemAccountCodes.JtakMarketSalesRevenue, "JTAK Market Sales Revenue", AccountType.Revenue);
        Assert.Equal(95_000m, await ledger.GetAccountBalanceAsync(marketRevenue.Id));
    }

    [Fact]
    public async Task CaptainSettlement_DoesNotDrainSubsequentCollections()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var captainId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // Step 1: Captain delivers Order 1 and collects 100_000 COD
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 12001,
            CaptainUserId = captainId,
            DeliveryFee = 5_000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 44, MerchantTitle = "External Store", TotalAmount = 95_000m, MerchantAmount = 85_000m, PlatformCommission = 10_000m }
            }
        });
        Assert.Equal(100_000m, await ledger.GetUserCashFloatBalanceAsync(captainId));

        // Step 2: Captain requests settlement for exactly 100_000
        var captainRequest = await service.CreateCaptainRequestAsync(captainId, "Captain One", "0900000000", new CreateSettlementRequestDto { Amount = 100_000m });
        Assert.Equal(100_000m, captainRequest.Amount);

        // Step 3: While request is pending, Captain delivers Order 2 and collects an additional 50_000 COD
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 12002,
            CaptainUserId = captainId,
            DeliveryFee = 5_000m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 44, MerchantTitle = "External Store", TotalAmount = 45_000m, MerchantAmount = 40_000m, PlatformCommission = 5_000m }
            }
        });
        // Live float is now 150_000
        Assert.Equal(150_000m, await ledger.GetUserCashFloatBalanceAsync(captainId));

        // Step 4: Admin accepts the settlement request
        var completed = await service.AcceptAsync(captainRequest.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Completed, completed.Status);
        Assert.Equal(100_000m, completed.Amount); // Amount remains 100_000, not overwritten to 150_000

        // Step 5: Vault has gained exactly 100_000, Captain retains exactly 50_000 in cash float
        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        Assert.Equal(100_000m, await ledger.GetAccountBalanceAsync(vault.Id));
        Assert.Equal(50_000m, await ledger.GetUserCashFloatBalanceAsync(captainId));
    }
}
