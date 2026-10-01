using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiControllers.V1.Warehouse;
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
using Modules.Catalog.Services;
using Modules.Shipping.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class PaymentsControllerTests
    {
        [Fact]
        public async Task RecivePayment_BackfillsLedgerForAlreadyHandedOverPaymentWithoutRepeatingLegacyDeductions()
        {
            using var accounting = new AccountingDbContext(
                new DbContextOptionsBuilder<AccountingDbContext>()
                    .UseInMemoryDatabase($"payment-recovery-{Guid.NewGuid()}").Options,
                new HttpContextAccessor());
            using var app = new AppDbContext(
                new DbContextOptionsBuilder<AppDbContext>()
                    .UseInMemoryDatabase($"payment-recovery-app-{Guid.NewGuid()}").Options,
                new HttpContextAccessor());

            var captainId = Guid.NewGuid();
            var merchantUserId = Guid.NewGuid();
            var captain = new AppUser { Id = captainId, FullName = "Reham" };
            var merchantUser = new AppUser { Id = merchantUserId, FullName = "Meat Station" };
            app.Users.AddRange(captain, merchantUser);
            await app.SaveChangesAsync();

            var payment = new Payment
            {
                Id = 2,
                ByUserId = captainId,
                ToUserId = merchantUserId,
                Amount = 40m,
                HandoverDate = DateTime.UtcNow.AddMinutes(-5)
            };
            accounting.Payments.Add(payment);
            await accounting.SaveChangesAsync();

            var ledger = new LedgerService(accounting, NullLogger<LedgerService>.Instance);
            var captainFloat = await ledger.GetOrCreateUserAccountAsync(
                captainId, AccountType.Asset, SystemAccountCodes.CaptainCashFloatPrefix, "Captain cash float");
            var openingEquity = await ledger.GetOrCreateSystemAccountAsync("3999-PAYMENT-TEST", "Opening equity", AccountType.Equity);
            await ledger.PostTransactionAsync(new PostTransactionRequest
            {
                IdempotencyKey = "payment-recovery-opening-float",
                Entries = new List<PostLedgerEntryRequest>
                {
                    new() { AccountId = captainFloat.Id, Debit = 100m },
                    new() { AccountId = openingEquity.Id, Credit = 100m }
                }
            });

            var merchantService = new Mock<IMerchantService>();
            merchantService.Setup(x => x.GetMerchantIds(merchantUserId)).ReturnsAsync(new[] { 42 });
            var paymentService = new Mock<IPaymentService>();
            paymentService.Setup(x => x.Queryable()).Returns(accounting.Payments);
            var balanceService = new Mock<IBalanceService>();
            balanceService.Setup(x => x.GetBalance(merchantUserId))
                .ReturnsAsync(new BalanceDto { Id = merchantUserId, Amount = 100m });
            var userManager = new Mock<UserManager<AppUser>>(
                new Mock<IUserStore<AppUser>>().Object, null, null, null, null, null, null, null, null);
            userManager.SetupGet(x => x.Users).Returns(app.Users);

            var controller = new PaymentsController(
                null,
                new AccountingUnitOfWork(accounting),
                null,
                userManager.Object,
                merchantService.Object,
                null,
                paymentService.Object,
                null,
                balanceService.Object,
                ledger,
                null)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext
                    {
                        User = new ClaimsPrincipal(new ClaimsIdentity(
                            new[] { new Claim(ClaimTypes.NameIdentifier, merchantUserId.ToString()) }, "test"))
                    }
                }
            };

            var result = await controller.RecivePayment(payment.Id);
            var retryResult = await controller.RecivePayment(payment.Id);

            Assert.True(result.Value);
            Assert.True(retryResult.Value);
            var journal = await accounting.JournalTransactions
                .Include(x => x.Entries)
                .SingleAsync(x => x.IdempotencyKey == "CaptainToMerchantPayment-Payment-2");
            Assert.Equal(2, journal.Entries.Count);
            Assert.Contains(journal.Entries, x => x.Debit == 40m);
            Assert.Contains(journal.Entries, x => x.Credit == 40m);
            Assert.Equal(60m, await ledger.GetUserCashFloatBalanceAsync(captainId));
            balanceService.Verify(x => x.DecreaseAppBalance(It.IsAny<Guid>(), It.IsAny<decimal>(), It.IsAny<string>(), It.IsAny<decimal>()), Times.Never);
            Assert.NotNull(payment.HandoverDate);
        }
    }
}
