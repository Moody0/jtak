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
        Assert.Contains("غير كافٍ لإتمام التسوية", error.Message);
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

    [Fact]
    public async Task MerchantConfirmation_Idempotent_PostsAccountingOnlyUponReceipt()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var captainId = Guid.NewGuid();
        var merchantOwnerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // 1. Order Delivered (COD)
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 13001,
            CaptainUserId = captainId,
            CaptainName = "Captain One",
            DeliveryFee = 500m,
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 26, MerchantTitle = "Meat Station", TotalAmount = 1_200m, MerchantAmount = 1_125m, PlatformCommission = 75m }
            }
        });

        // 2. Captain settles shift into vault
        var capReq = await service.CreateCaptainRequestAsync(captainId, "Captain One", "0900000000", new CreateSettlementRequestDto { Amount = 1_700m });
        await service.AcceptAsync(capReq.Id, adminId);
        var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault, "Vault", AccountType.Asset);
        Assert.Equal(1_700m, await ledger.GetAccountBalanceAsync(vault.Id));

        // 3. Merchant checks balance: Gross = 1,125, Pending = 0, Available = 1,125
        var preBalance = await service.GetMerchantBalanceAsync(new[] { 26 });
        Assert.Equal(1_125m, preBalance.GrossAmount);
        Assert.Equal(0m, preBalance.PendingAmount);
        Assert.Equal(1_125m, preBalance.AvailableAmount);

        // 4. Merchant creates settlement request for 1,125
        var request = await service.CreateMerchantRequestAsync(
            merchantOwnerId, "Meat Station Owner", "0933333333",
            new[] { new MerchantSettlementSource { MerchantId = 26, MerchantTitle = "Meat Station" } },
            new CreateSettlementRequestDto { Amount = 1_125m, Method = "Cash", AccountDetails = "Cash at Store" });

        Assert.Equal(SettlementRequestStatus.Pending, request.Status);
        // Reservation: Available is now 0, Pending is 1,125, Gross is 1,125
        var postReqBalance = await service.GetMerchantBalanceAsync(new[] { 26 });
        Assert.Equal(1_125m, postReqBalance.GrossAmount);
        Assert.Equal(1_125m, postReqBalance.PendingAmount);
        Assert.Equal(0m, postReqBalance.AvailableAmount);
        // NO ledger movement yet, Vault is untouched
        Assert.Equal(1_700m, await ledger.GetAccountBalanceAsync(vault.Id));
        Assert.Equal(1_125m, await ledger.GetMerchantPayableBalanceAsync(26));

        // 5. Admin Approves the request
        var approved = await service.AcceptAsync(request.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Approved, approved.Status);
        // Still NO ledger movement, Vault is untouched
        Assert.Equal(1_700m, await ledger.GetAccountBalanceAsync(vault.Id));
        Assert.Equal(1_125m, await ledger.GetMerchantPayableBalanceAsync(26));

        // 6. Merchant confirms receipt
        var confirmed = await service.ConfirmMerchantReceiptAsync(request.Id, merchantOwnerId);
        Assert.Equal(SettlementRequestStatus.Completed, confirmed.Status);
        Assert.NotNull(confirmed.CompletedAt);
        Assert.NotNull(confirmed.LedgerTransactionId);

        // Financials atomically posted:
        // Vault decreased by exactly 1,125: 1,700 - 1,125 = 575
        Assert.Equal(575m, await ledger.GetAccountBalanceAsync(vault.Id));
        // Merchant Payable cleared by exactly 1,125: 1,125 - 1,125 = 0
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(26));
        var postConfirmBalance = await service.GetMerchantBalanceAsync(new[] { 26 });
        Assert.Equal(0m, postConfirmBalance.GrossAmount);
        Assert.Equal(0m, postConfirmBalance.PendingAmount);
        Assert.Equal(0m, postConfirmBalance.AvailableAmount);

        // 7. Idempotency test: Re-confirming does NOT post another transaction or double-decrease vault
        var reconfirmed = await service.ConfirmMerchantReceiptAsync(request.Id, merchantOwnerId);
        Assert.Equal(SettlementRequestStatus.Completed, reconfirmed.Status);
        Assert.Equal(575m, await ledger.GetAccountBalanceAsync(vault.Id));
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(26));

        // 8. Admin Complete idempotent call also returns safely
        var adminComplete = await service.CompleteMerchantPayoutAsync(request.Id, adminId);
        Assert.Equal(SettlementRequestStatus.Completed, adminComplete.Status);
        Assert.Equal(575m, await ledger.GetAccountBalanceAsync(vault.Id));
    }

    [Fact]
    public async Task MerchantConfirmation_RejectsUnauthorizedOrPrematureCalls()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var ownerId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();

        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 14001,
            CaptainUserId = Guid.NewGuid(),
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 30, MerchantTitle = "Bakery", TotalAmount = 5_000m, MerchantAmount = 4_500m, PlatformCommission = 500m }
            }
        });

        var request = await service.CreateMerchantRequestAsync(
            ownerId, "Bakery Owner", null,
            new[] { new MerchantSettlementSource { MerchantId = 30, MerchantTitle = "Bakery" } },
            new CreateSettlementRequestDto { Amount = 4_500m });

        // Cannot confirm before approval
        var exPremature = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.ConfirmMerchantReceiptAsync(request.Id, ownerId));
        Assert.Contains("يجب قبول واعتماد طلب التسوية", exPremature.Message);

        // Admin approves
        await service.AcceptAsync(request.Id, Guid.NewGuid());

        // Unauthorized user cannot confirm
        var exUnauth = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.ConfirmMerchantReceiptAsync(request.Id, otherUserId));
        Assert.Contains("لا يمكنك تأكيد استلام", exUnauth.Message);
    }

    [Fact]
    public async Task MerchantPayout_UsesBankSourceAccount_WhenMethodIsBank()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var ownerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // Merchant has 50,000 payable
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 15001,
            CaptainUserId = Guid.NewGuid(),
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 55, MerchantTitle = "Supermarket", TotalAmount = 60_000m, MerchantAmount = 50_000m, PlatformCommission = 10_000m }
            }
        });

        // Bank account is funded with 100,000
        var bank = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.BankMain, "Bank", AccountType.Asset);
        await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "CapitalInjection",
            ReferenceId = "CAP-001",
            IdempotencyKey = "CAP-001",
            Description = "Fund bank account",
            Entries = new List<PostLedgerEntryRequest>
            {
                new() { AccountId = bank.Id, Debit = 100_000m, Currency = "SYP" },
                new() { AccountId = (await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashOverageRevenue, "Equity", AccountType.Revenue)).Id, Credit = 100_000m, Currency = "SYP" }
            }
        });

        var request = await service.CreateMerchantRequestAsync(
            ownerId, "Supermarket Owner", "0944444444",
            new[] { new MerchantSettlementSource { MerchantId = 55, MerchantTitle = "Supermarket" } },
            new CreateSettlementRequestDto { Amount = 50_000m, Method = "bank_transfer", AccountDetails = "IBAN: SY12345678" });

        await service.AcceptAsync(request.Id, adminId);
        var confirmed = await service.ConfirmMerchantReceiptAsync(request.Id, ownerId);

        Assert.Equal(SettlementRequestStatus.Completed, confirmed.Status);
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(55));
        // Bank balance decreased from 100,000 to 50,000
        Assert.Equal(50_000m, await ledger.GetAccountBalanceAsync(bank.Id));
    }

    [Fact]
    public async Task MerchantPayout_UsesCashSafeSourceAccount_WhenMethodIsCashSafe()
    {
        using var context = CreateContext();
        var ledger = new LedgerService(context, NullLogger<LedgerService>.Instance);
        var service = new SettlementRequestService(context, ledger, NullLogger<SettlementRequestService>.Instance);
        var ownerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();

        // Merchant has 30,000 payable
        await ledger.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
        {
            OrderId = 15002,
            CaptainUserId = Guid.NewGuid(),
            MerchantSplits = new List<MerchantSplitItem>
            {
                new() { MerchantId = 56, MerchantTitle = "Boutique", TotalAmount = 35_000m, MerchantAmount = 30_000m, PlatformCommission = 5_000m }
            }
        });

        // Cash Safe account is funded with 50,000
        var safe = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyCashSafe, "Safe", AccountType.Asset);
        await ledger.PostTransactionAsync(new PostTransactionRequest
        {
            ReferenceType = "FundSafe",
            ReferenceId = "SAFE-001",
            IdempotencyKey = "SAFE-001",
            Description = "Fund safe account",
            Entries = new List<PostLedgerEntryRequest>
            {
                new() { AccountId = safe.Id, Debit = 50_000m, Currency = "SYP" },
                new() { AccountId = (await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CashOverageRevenue, "Equity", AccountType.Revenue)).Id, Credit = 50_000m, Currency = "SYP" }
            }
        });

        var request = await service.CreateMerchantRequestAsync(
            ownerId, "Boutique Owner", "0955555555",
            new[] { new MerchantSettlementSource { MerchantId = 56, MerchantTitle = "Boutique" } },
            new CreateSettlementRequestDto { Amount = 30_000m, Method = "cash_safe", AccountDetails = "Branch Safe" });

        await service.AcceptAsync(request.Id, adminId);
        var confirmed = await service.ConfirmMerchantReceiptAsync(request.Id, ownerId);

        Assert.Equal(SettlementRequestStatus.Completed, confirmed.Status);
        Assert.Equal(0m, await ledger.GetMerchantPayableBalanceAsync(56));
        // Safe balance decreased from 50,000 to 20,000
        Assert.Equal(20_000m, await ledger.GetAccountBalanceAsync(safe.Id));
    }
}
