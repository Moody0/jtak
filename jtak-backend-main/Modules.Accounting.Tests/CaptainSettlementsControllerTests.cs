using App.ApiControllers.V1.Admin.Accounting;
using App.Orders.Data;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Orders.Entities;
using Moq;
using Modules.Accounting.Services;
using Microsoft.Extensions.Logging.Abstractions;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Xunit;
using OrderPaymentMethod = Modules.Orders.Entities.PaymentMethod;

namespace Modules.Accounting.Tests
{
    public class CaptainSettlementsControllerTests
    {
        private static OrdersDbContext CreateInMemoryOrdersContext()
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private static AccountingDbContext CreateInMemoryAccountingContext()
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private static Mock<UserManager<AppUser>> CreateUserManagerMock(List<AppUser> deliveryUsers, List<AppUser> allUsers = null)
        {
            var userStoreMock = new Mock<IUserStore<AppUser>>();
            var userManagerMock = new Mock<UserManager<AppUser>>(userStoreMock.Object, null, null, null, null, null, null, null, null);

            userManagerMock.Setup(m => m.GetUsersInRoleAsync(It.IsAny<string>()))
                .ReturnsAsync(deliveryUsers);

            var combined = (allUsers ?? deliveryUsers).ToList();
            userManagerMock.Setup(m => m.FindByIdAsync(It.IsAny<string>()))
                .ReturnsAsync((string id) => combined.FirstOrDefault(u => u.Id.ToString() == id));

            return userManagerMock;
        }

        [Fact]
        public async Task GetSummary_ReturnsCorrectAggregates_ForThreeCaptainTypes()
        {
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();

            var captainSalaried = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Ahmed (Salaried)",
                PhoneNumber = "0911111111",
                CaptainCompensationType = CaptainCompensationType.SalariedEmployee,
                CaptainRate = 0m
            };

            var captainKm = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Basel (PerKm)",
                PhoneNumber = "0922222222",
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m
            };

            var captainPct = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Sami (Percentage)",
                PhoneNumber = "0933333333",
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m
            };

            var deliveryUsers = new List<AppUser> { captainSalaried, captainKm, captainPct };
            var userManager = CreateUserManagerMock(deliveryUsers);

            var now = DateTime.UtcNow;

            // Order 1: Salaried Captain
            ordersDb.Set<Order>().Add(new Order
            {
                Id = 1,
                DeliveryId = captainSalaried.Id,
                DeliveredAt = now,
                OrderStatus = OrderStatus.Success,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                OriginalDeliveryFee = 180m,
                DeliveryFee = 180m,
                CaptainCompensationType = CaptainCompensationType.SalariedEmployee,
                CaptainRate = 0m,
                CaptainEarning = 0m,
                PaymentMethod = OrderPaymentMethod.PayOnDelivery,
                ActualCashCollected = 2680m,
                IsSettled = false,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { SingleFinalPrice = 2500m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            });

            // Order 2: PerKm Captain (25/km -> 4km * 25 = 100)
            ordersDb.Set<Order>().Add(new Order
            {
                Id = 2,
                DeliveryId = captainKm.Id,
                DeliveredAt = now,
                OrderStatus = OrderStatus.Success,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                OriginalDeliveryFee = 180m,
                DeliveryFee = 180m,
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m,
                CaptainEarning = 100m,
                PaymentMethod = OrderPaymentMethod.PayOnDelivery,
                ActualCashCollected = 2680m,
                IsSettled = false,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { SingleFinalPrice = 2500m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            });

            // Order 3: Percentage Captain (60% of 180 = 108)
            ordersDb.Set<Order>().Add(new Order
            {
                Id = 3,
                DeliveryId = captainPct.Id,
                DeliveredAt = now,
                OrderStatus = OrderStatus.Success,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                OriginalDeliveryFee = 180m,
                DeliveryFee = 180m,
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m,
                CaptainEarning = 108m,
                PaymentMethod = OrderPaymentMethod.PayOnDelivery,
                ActualCashCollected = 2680m,
                IsSettled = false,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { SingleFinalPrice = 2500m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            });

            await ordersDb.SaveChangesAsync();

            var controller = new CaptainSettlementsController(ordersDb, accountingDb, userManager.Object,
                new LedgerService(accountingDb, NullLogger<LedgerService>.Instance));

            var actionResult = await controller.GetSummary(settlementStatus: "all");
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var summary = Assert.IsType<CaptainSettlementsOverviewDto>(okResult.Value);

            Assert.Equal(3, summary.TotalOrders);
            Assert.Equal(8040m, summary.TotalCashCollected);
            Assert.Equal(540m, summary.TotalDeliveryFees);
            Assert.Equal(208m, summary.TotalCaptainEarnings); // 0 + 100 + 108 = 208
            Assert.Equal(7832m, summary.TotalNetDueToCompany); // 8040 - 208 = 7832

            var salariedItem = summary.Items.First(i => i.CaptainId == captainSalaried.Id);
            Assert.Equal(2680m, salariedItem.TotalCashCollected);
            Assert.Equal(0m, salariedItem.TotalCaptainEarnings);
            Assert.Equal(2680m, salariedItem.NetDueToCompany);
            Assert.Equal("Unsettled", salariedItem.SettlementStatus);

            var kmItem = summary.Items.First(i => i.CaptainId == captainKm.Id);
            Assert.Equal(2680m, kmItem.TotalCashCollected);
            Assert.Equal(100m, kmItem.TotalCaptainEarnings);
            Assert.Equal(2580m, kmItem.NetDueToCompany);

            var pctItem = summary.Items.First(i => i.CaptainId == captainPct.Id);
            Assert.Equal(2680m, pctItem.TotalCashCollected);
            Assert.Equal(108m, pctItem.TotalCaptainEarnings);
            Assert.Equal(2572m, pctItem.NetDueToCompany);
        }

        [Fact]
        public async Task ConfirmSettlement_LocksOrdersWithBatchCode_AndGeneratesReceipt()
        {
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();

            var captain = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Captain Basel (PerKm)",
                PhoneNumber = "0922222222",
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m
            };

            var admin = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Admin JTak",
                UserName = "admin"
            };

            var deliveryUsers = new List<AppUser> { captain };
            var allUsers = new List<AppUser> { captain, admin };
            var userManager = CreateUserManagerMock(deliveryUsers, allUsers);

            var order = new Order
            {
                Id = 42,
                DeliveryId = captain.Id,
                DeliveredAt = DateTime.UtcNow,
                OrderStatus = OrderStatus.Success,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                OriginalDeliveryFee = 180m,
                DeliveryFee = 180m,
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m,
                CaptainEarning = 100m,
                PaymentMethod = OrderPaymentMethod.PayOnDelivery,
                ActualCashCollected = 2680m,
                IsSettled = false,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { SingleFinalPrice = 2500m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            };

            ordersDb.Set<Order>().Add(order);
            await ordersDb.SaveChangesAsync();

            var controller = new CaptainSettlementsController(ordersDb, accountingDb, userManager.Object,
                new LedgerService(accountingDb, NullLogger<LedgerService>.Instance));
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, admin.Id.ToString())
                    }, "TestAuth"))
                }
            };

            var confirmRequest = new ConfirmCaptainSettlementRequest
            {
                CaptainId = captain.Id,
                Notes = "End of shift settlement"
            };

            var actionResult = await controller.ConfirmSettlement(confirmRequest);
            var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
            var receipt = Assert.IsType<SettlementBatchReceiptDto>(okResult.Value);

            Assert.NotNull(receipt.BatchId);
            Assert.StartsWith("SETTLE-", receipt.BatchId);
            Assert.Equal(1, receipt.OrdersCount);
            Assert.Equal(2680m, receipt.TotalCashCollected);
            Assert.Equal(100m, receipt.TotalCaptainEarnings);
            Assert.Equal(2580m, receipt.NetDueToCompany);

            // Verify order in database is settled
            var updatedOrder = await ordersDb.Set<Order>().FindAsync(42);
            Assert.True(updatedOrder.IsSettled);
            Assert.NotNull(updatedOrder.SettledAt);
            Assert.Equal(receipt.BatchId, updatedOrder.SettlementBatchId);

            // Verify daily batch is stored in AccountingDbContext
            var storedBatch = await accountingDb.DailySettlementBatches.FirstOrDefaultAsync(b => b.BatchCode == receipt.BatchId);
            Assert.NotNull(storedBatch);
            Assert.Equal(2580m, storedBatch.NetCashRemitted);

            // Test GetBatchReceipt retrieves same data
            var receiptActionResult = await controller.GetBatchReceipt(receipt.BatchId);
            var receiptOkResult = Assert.IsType<OkObjectResult>(receiptActionResult.Result);
            var fetchedReceipt = Assert.IsType<SettlementBatchReceiptDto>(receiptOkResult.Value);
            Assert.Equal(receipt.BatchId, fetchedReceipt.BatchId);
            Assert.Equal(2580m, fetchedReceipt.NetDueToCompany);
        }
    }
}
