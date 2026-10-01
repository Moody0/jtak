using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin.Accounting;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class DriverCashAdvancesControllerTests
    {
        [Fact]
        public async Task Create_PostsBalancedAdvance_AndReplayDoesNotFundTwice()
        {
            using var accounting = NewAccountingDb();
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true, MaxCashFloat = 5000m, FullName = "Driver" };
            var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                "Company Vault", AccountType.Asset);
            var openingEquity = await ledger.GetOrCreateSystemAccountAsync("3999-TEST", "Opening Equity", AccountType.Equity);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "test-opening-vault",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = vault.Id, Debit = 1000m },
                    new() { AccountId = openingEquity.Id, Credit = 1000m }
                }
            });

            var controller = NewController(accounting, ledger, driver);
            var request = new CreateDriverCashAdvanceRequest
            {
                DriverUserId = driver.Id, Amount = 400m, Reason = "Approved errand purchase",
                IdempotencyKey = "advance-request-1"
            };

            var first = Assert.IsType<OkObjectResult>((await controller.Create(request)).Result);
            var second = Assert.IsType<OkObjectResult>((await controller.Create(request)).Result);

            Assert.Equal(400m, await ledger.GetUserCashFloatBalanceAsync(driver.Id));
            Assert.Equal(600m, await ledger.GetAccountBalanceAsync(vault.Id));
            Assert.Equal(1, await accounting.JournalTransactions.CountAsync(t => t.ReferenceType == "CaptainCashAdvance"));
            Assert.NotNull(first.Value);
            Assert.NotNull(second.Value);

            // Exercise the existing errand accounting lifecycle after the advance:
            // shop purchase reduces custody, customer cash replenishes it, and
            // cash handover returns the remaining physical cash to the vault.
            var floatAccount = await accounting.Accounts.FirstAsync(a => a.OwnerUserId == driver.Id &&
                a.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
            var goods = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandGoodsInTransit,
                "Errand Goods", AccountType.Asset);
            var margin = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.ErrandProductMarginRevenue,
                "Errand Margin", AccountType.Revenue);
            var earnings = await ledger.GetOrCreateUserAccountAsync(driver.Id, AccountType.Liability,
                SystemAccountCodes.CaptainEarningsPrefix, "Driver Earnings");
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "advance-flow-purchase",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = goods.Id, Debit = 300m },
                    new() { AccountId = floatAccount.Id, Credit = 300m }
                }
            });
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "advance-flow-delivery",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = floatAccount.Id, Debit = 350m },
                    new() { AccountId = goods.Id, Credit = 300m },
                    new() { AccountId = margin.Id, Credit = 40m },
                    new() { AccountId = earnings.Id, Credit = 10m }
                }
            });
            await ledger.PostCaptainCashHandoverAsync(driver.Id, 450m, "advance-flow-handover", driver.FullName);

            Assert.Equal(0m, await ledger.GetUserCashFloatBalanceAsync(driver.Id));
            Assert.Equal(1050m, await ledger.GetAccountBalanceAsync(vault.Id));
            Assert.Equal(40m, await ledger.GetAccountBalanceAsync(margin.Id));
            Assert.Equal(10m, await ledger.GetAccountBalanceAsync(earnings.Id));
        }

        [Fact]
        public async Task Create_RejectsAdvanceThatExceedsDriverLimitOrCompanyVault()
        {
            using var accounting = NewAccountingDb();
            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var driver = new AppUser { Id = Guid.NewGuid(), IsActive = true, MaxCashFloat = 500m, FullName = "Driver" };
            var vault = await ledger.GetOrCreateSystemAccountAsync(SystemAccountCodes.CompanyMainVault,
                "Company Vault", AccountType.Asset);
            var equity = await ledger.GetOrCreateSystemAccountAsync("3999-TEST", "Opening Equity", AccountType.Equity);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "test-opening-vault-limited",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = vault.Id, Debit = 300m },
                    new() { AccountId = equity.Id, Credit = 300m }
                }
            });
            var controller = NewController(accounting, ledger, driver);

            var overLimit = Assert.IsType<BadRequestObjectResult>((await controller.Create(new CreateDriverCashAdvanceRequest
            {
                DriverUserId = driver.Id, Amount = 501m, Reason = "Test", IdempotencyKey = "over-limit"
            })).Result);
            var overVault = Assert.IsType<BadRequestObjectResult>((await controller.Create(new CreateDriverCashAdvanceRequest
            {
                DriverUserId = driver.Id, Amount = 301m, Reason = "Test", IdempotencyKey = "over-vault"
            })).Result);

            Assert.NotNull(overLimit.Value);
            Assert.NotNull(overVault.Value);
            Assert.Equal(0m, await ledger.GetUserCashFloatBalanceAsync(driver.Id));
            Assert.Equal(0, await accounting.JournalTransactions.CountAsync(t => t.ReferenceType == "CaptainCashAdvance"));
        }

        private static AccountingDbContext NewAccountingDb() => new(
            new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase($"driver-advance-{Guid.NewGuid()}").Options,
            new HttpContextAccessor());

        private static DriverCashAdvancesController NewController(AccountingDbContext accounting,
            ILedgerService ledger, AppUser driver)
        {
            var manager = new Mock<UserManager<AppUser>>(new Mock<IUserStore<AppUser>>().Object,
                null, null, null, null, null, null, null, null);
            manager.Setup(x => x.FindByIdAsync(driver.Id.ToString())).ReturnsAsync(driver);
            manager.Setup(x => x.IsInRoleAsync(driver, AppRoleName.Delivery.ToString())).ReturnsAsync(true);
            var audit = new Mock<IAdminAuditService>();
            audit.Setup(x => x.LogAsync(It.IsAny<AdminAuditLogEntry>())).Returns(Task.CompletedTask);
            return new DriverCashAdvancesController(accounting, ledger, manager.Object, audit.Object);
        }
    }
}
