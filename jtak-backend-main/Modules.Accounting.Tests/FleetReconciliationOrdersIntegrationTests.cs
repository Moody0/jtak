using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.Orders.Data;
using App.Shared.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class FleetReconciliationOrdersIntegrationTests
    {
        private AccountingDbContext CreateInMemoryAccountingContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .AddInterceptors(new LedgerImmutabilityInterceptor())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private OrdersDbContext CreateInMemoryOrdersContext()
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private Mock<UserManager<AppUser>> CreateMockUserManager(AppUser user)
        {
            var store = new Mock<IUserStore<AppUser>>();
            var mock = new Mock<UserManager<AppUser>>(store.Object, null, null, null, null, null, null, null, null);
            mock.Setup(m => m.FindByIdAsync(It.IsAny<string>()))
                .ReturnsAsync((string id) => id == user.Id.ToString() ? user : null);
            return mock;
        }

        [Fact]
        public async Task GetCaptainOrders_ReturnsDeliveredOrders_WithAccurateBreakdown()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var captainId = Guid.NewGuid();
            var captainUser = new AppUser { Id = captainId, UserName = "captain1", FullName = "Captain One", PhoneNumber = "+963911111111" };
            var userManagerMock = CreateMockUserManager(captainUser);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(accountingDb, ledgerService, userManagerMock.Object, NullLogger<EodReconciliationService>.Instance);

            // Add delivered orders for the captain
            ordersDb.Set<Order>().AddRange(
                new Order
                {
                    Id = 501,
                    DeliveryId = captainId,
                    User = "Customer A",
                    Phonenumber = "0911223344",
                    DeliveredAt = DateTime.UtcNow.AddHours(-2),
                    DeliveryFee = 1500m,
                    CaptainEarning = 1200m,
                    ActualCashCollected = 25000m,
                    PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                    IsSettled = false,
                    OrderDetails = new List<OrderDetail>
                    {
                        new OrderDetail { SinglePrice = 23500m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                    }
                },
                new Order
                {
                    Id = 502,
                    DeliveryId = captainId,
                    User = "Customer B",
                    Phonenumber = "0922334455",
                    DeliveredAt = DateTime.UtcNow.AddHours(-1),
                    DeliveryFee = 2000m,
                    CaptainEarning = 1800m,
                    ActualCashCollected = 10000m,
                    PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                    IsSettled = false,
                    OrderDetails = new List<OrderDetail>
                    {
                        new OrderDetail { SinglePrice = 8000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                    }
                }
            );
            await ordersDb.SaveChangesAsync();

            var controller = new FleetReconciliationController(
                eodService,
                userManagerMock.Object,
                null,
                null,
                null,
                ledgerService,
                null,
                accountingDb,
                ordersDb: ordersDb);

            var actionResult = await controller.GetCaptainOrders(captainId);
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var items = Assert.IsType<List<CaptainDeliveredOrderItemDto>>(okResult.Value);

            Assert.Equal(2, items.Count);
            Assert.Contains(items, o => o.OrderId == 501 && o.CashCollected == 25000m && o.CaptainEarning == 1200m && !o.IsSettled);
            Assert.Contains(items, o => o.OrderId == 502 && o.CashCollected == 10000m && o.CaptainEarning == 1800m && !o.IsSettled);
        }

        [Fact]
        public async Task SettleShift_ClearsBalances_AndAutomaticallyStampsDeliveredOrders()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            using var ordersDb = CreateInMemoryOrdersContext();

            var adminId = Guid.NewGuid();
            var captainId = Guid.NewGuid();
            var captainUser = new AppUser { Id = captainId, UserName = "captain1", FullName = "Captain One", PhoneNumber = "+963911111111" };
            var userManagerMock = CreateMockUserManager(captainUser);

            var ledgerService = new LedgerService(accountingDb, NullLogger<LedgerService>.Instance);
            var eodService = new EodReconciliationService(accountingDb, ledgerService, userManagerMock.Object, NullLogger<EodReconciliationService>.Instance);

            // Seed ledger position: Float = 35,000, Wages = 3,000, Net = 32,000
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 501,
                CaptainUserId = captainId,
                CaptainName = "Captain One",
                DeliveryFee = 3000m,
                Currency = "SYP",
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem { MerchantId = 1, MerchantTitle = "Shop", TotalAmount = 32000m, MerchantAmount = 32000m }
                }
            });

            // Add delivered order to orders db
            var order = new Order
            {
                Id = 501,
                DeliveryId = captainId,
                User = "Customer A",
                Phonenumber = "0911223344",
                DeliveredAt = DateTime.UtcNow.AddHours(-2),
                DeliveryFee = 3000m,
                CaptainEarning = 3000m,
                ActualCashCollected = 35000m,
                PaymentMethod = Modules.Orders.Entities.PaymentMethod.PayOnDelivery,
                IsSettled = false
            };
            ordersDb.Set<Order>().Add(order);
            await ordersDb.SaveChangesAsync();

            var controller = new FleetReconciliationController(
                eodService,
                userManagerMock.Object,
                null,
                null,
                null,
                ledgerService,
                null,
                accountingDb,
                ordersDb: ordersDb);

            var userClaims = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, adminId.ToString()),
            }, "TestAuth"));
            controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = userClaims } };

            var settleReq = new SettleCaptainShiftRequest
            {
                CaptainUserId = captainId,
                PhysicalCashReceived = 32000m,
                Currency = "SYP",
                Notes = "تسوية نهاية الوردية"
            };

            var actionResult = await controller.SettleShift(settleReq);
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var settlementResult = Assert.IsType<SettlementResultDto>(okResult.Value);

            Assert.NotNull(settlementResult.BatchCode);

            // Verify order in ordersDb was auto-stamped
            var refreshedOrder = await ordersDb.Set<Order>().FindAsync(501);
            Assert.True(refreshedOrder.IsSettled);
            Assert.NotNull(refreshedOrder.SettledAt);
            Assert.Equal(settlementResult.BatchCode, refreshedOrder.SettlementBatchId);
        }
    }
}
