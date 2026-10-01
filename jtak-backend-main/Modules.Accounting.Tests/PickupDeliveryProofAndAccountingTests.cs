using App.ApiControllers.V1.Delivery;
using App.ApiModels;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using PaymentMethod = Modules.Orders.Entities.PaymentMethod;
using App.Shared.Services;
using App.Shared.Services.Hubs;
using App.Shared.Services.Pricing;
using App.Shipping.Data;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Catalog.Services;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Modules.Shipping.Entities;
using Modules.Shipping.Services;
using Moq;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class PickupDeliveryProofAndAccountingTests
    {
        private OrdersDbContext CreateInMemoryOrdersContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private AccountingDbContext CreateInMemoryAccountingContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<AccountingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new AccountingDbContext(options, null);
        }

        private ShippingDbContext CreateInMemoryShippingContext(string dbName = null)
        {
            var options = new DbContextOptionsBuilder<ShippingDbContext>()
                .UseInMemoryDatabase(databaseName: dbName ?? Guid.NewGuid().ToString())
                .Options;
            return new ShippingDbContext(options, null);
        }

        private UserManager<AppUser> CreateMockUserManager(Guid driverId, string driverName = "Captain Ahmad")
        {
            var user = new AppUser
            {
                Id = driverId,
                UserName = "captain_ahmad",
                FullName = driverName,
                Email = "captain@jtak.sy",
                IsActive = true
            };

            var userStore = new Mock<IUserStore<AppUser>>();
            var userManagerMock = new Mock<UserManager<AppUser>>(userStore.Object, null, null, null, null, null, null, null, null);

            userManagerMock.Setup(m => m.Users).Returns(new[] { user }.AsQueryable());
            userManagerMock.Setup(m => m.FindByIdAsync(driverId.ToString())).ReturnsAsync(user);
            userManagerMock.Setup(m => m.IsInRoleAsync(user, AppRoleName.Delivery.ToString())).ReturnsAsync(true);

            return userManagerMock.Object;
        }

        private DeliveryService CreateDeliveryService(ShippingDbContext shippingDb)
        {
            var uow = new ShippingUnitOfWork(shippingDb);
            var repo = new TrackableRepository<ShippingOrder, ShippingDbContext>(shippingDb);
            var memCache = new MemoryCache(new MemoryCacheOptions());
            var uService = new Mock<IUserService>().Object;
            return new DeliveryService(repo, uow, memCache, uService);
        }

        private OrderService CreateOrderService(OrdersDbContext ordersDb, UserManager<AppUser> userManager)
        {
            var ouow = new OrdersUnitOfWork(ordersDb);
            var orderRepo = new TrackableRepository<Order, OrdersDbContext>(ordersDb);
            var logRepo = new TrackableRepository<OrderStatusChangeLog, OrdersDbContext>(ordersDb);
            var detailRepo = new TrackableRepository<OrderDetail, OrdersDbContext>(ordersDb);
            var mapperMock = new Mock<IMapper>();

            return new OrderService(ouow, mapperMock.Object, userManager, orderRepo, logRepo, detailRepo);
        }

        private OrdersController CreateOrdersController(
            OrdersDbContext ordersDb,
            AccountingDbContext accountingDb,
            ShippingDbContext shippingDb,
            OrderService orderService,
            UserManager<AppUser> userManager,
            ILedgerService ledgerService = null,
            IBillService billService = null,
            Guid? currentDriverId = null)
        {
            var auow = new AccountingUnitOfWork(accountingDb);
            var ouow = new OrdersUnitOfWork(ordersDb);
            var notificationMock = new Mock<INotificationService>();
            var merchantMock = new Mock<IMerchantService>();
            var productMock = new Mock<IProductService>();
            var balanceMock = new Mock<IBalanceService>();
            var batchMock = new Mock<IInventoryBatchService>();
            var trackingHubMock = new Mock<IHubContext<TrackingHub>>();
            var mapperMock = new Mock<IMapper>();
            var deliveryService = CreateDeliveryService(shippingDb);
            var moneyService = new OrderMoneyCalculationService();

            var hubClientsMock = new Mock<IHubClients>();
            var clientProxyMock = new Mock<IClientProxy>();
            hubClientsMock.Setup(h => h.Group(It.IsAny<string>())).Returns(clientProxyMock.Object);
            trackingHubMock.Setup(h => h.Clients).Returns(hubClientsMock.Object);

            IBillService bills = billService;
            if (bills == null)
            {
                var billRepo = new TrackableRepository<Bill, AccountingDbContext>(accountingDb);
                bills = new BillService(billRepo);
            }

            ILedgerService ledger = ledgerService ?? new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);

            var controller = new OrdersController(
                unitOfWork: null,
                auow: auow,
                ouow: ouow,
                notificationService: notificationMock.Object,
                userManager: userManager,
                merchantService: merchantMock.Object,
                productService: productMock.Object,
                deliveryService: deliveryService,
                service: orderService,
                billService: bills,
                balanceService: balanceMock.Object,
                ledgerService: ledger,
                batchService: batchMock.Object,
                trackingHub: trackingHubMock.Object,
                mapper: mapperMock.Object,
                logger: new Mock<ILogger<OrdersController>>().Object,
                moneyCalculationService: moneyService,
                env: null);

            var driverId = currentDriverId ?? Guid.NewGuid();
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, driverId.ToString()),
                new Claim("sub", driverId.ToString()),
                new Claim(ClaimTypes.Name, "Captain Ahmad")
            };
            var identity = new ClaimsIdentity(claims, "TestAuth");
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }
            };

            return controller;
        }

        // =========================================================================
        // Test 1: PickupValidation_RejectsStartShipping_IfMerchantItemsNotReady
        // =========================================================================
        [Fact]
        public async Task Test01_PickupValidation_RejectsStartShipping_IfMerchantItemsNotReady()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);

            var order = new Order
            {
                Id = 101,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 1, OrderId = 101, MerchantId = 20, SingleFinalPrice = 5000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.MerchantAccepted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            // Attempting to start shipping while item is MerchantAccepted (not ReadyForPickup) throws
            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
                orderService.StartShippingOrder(order.Id, 20, driverId));
            Assert.Contains("جاهزة للاستلام", ex.Message);

            // Merchant marks ready
            await orderService.MerchantMarkReady(order.Id, 20);
            Assert.Equal(OrderDetailStatus.ReadyForPickup, order.OrderDetails.Single().OrderDetailStatus);

            // Now driver can start shipping
            var startedOrder = await orderService.StartShippingOrder(order.Id, 20, driverId);
            Assert.Equal(OrderDetailStatus.ShippingStarted, startedOrder.OrderDetails.Single().OrderDetailStatus);
        }

        // =========================================================================
        // Test 2: DeliveryValidation_RejectsDeliverOrder_IfMerchantStopsNotPickedUp
        // =========================================================================
        [Fact]
        public async Task Test02_DeliveryValidation_RejectsDeliverOrder_IfMerchantStopsNotPickedUp()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);

            // Multi-merchant order: Merchant A picked up, Merchant B still ReadyForPickup
            var order = new Order
            {
                Id = 102,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 201, OrderId = 102, MerchantId = 10, SingleFinalPrice = 3000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted },
                    new OrderDetail { Id = 202, OrderId = 102, MerchantId = 20, SingleFinalPrice = 4000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ReadyForPickup }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            // OrderService check: CanDeliverOrder is false
            var canDeliver = await orderService.CanDeliverOrder(order.Id, driverId);
            Assert.False(canDeliver);

            // OrderService DeliverOrder throws
            var ex = await Assert.ThrowsAsync<Exception>(() => orderService.DeliverOrder(order.Id, driverId));
            Assert.Contains("in transit before the order can be delivered", ex.Message);

            // Controller endpoint rejects delivery
            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, currentDriverId: driverId);
            var actionResult = await controller.DeliverOrder(order.Id);
            var badRequest = Assert.IsType<BadRequestObjectResult>(actionResult.Result);
            var apiErr = Assert.IsType<ApiErr>(badRequest.Value);
            Assert.Contains(apiErr.Errors, e => e.Contains("استلام جميع المحطات"));
        }

        // =========================================================================
        // Test 3: Wrong PINs are rate limited; legacy expiry does not invalidate the customer's PIN.
        // =========================================================================
        [Fact]
        public async Task Test03_DeliveryOtp_RateLimiting_And_LegacyExpiryIgnored()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);

            var order = new Order
            {
                Id = 103,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryOtp = "4826",
                DeliveryOtpFailedAttempts = 0,
                DeliveryOtpExpiresAt = DateTime.UtcNow.AddHours(-3),
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 301, OrderId = 103, MerchantId = 10, SingleFinalPrice = 5000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, currentDriverId: driverId);

            // 1. Wrong OTP increment and rejection
            var res1 = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999" });
            var badReq1 = Assert.IsType<BadRequestObjectResult>(res1.Result);
            var wrongErr = Assert.IsType<ApiErr>(badReq1.Value);
            Assert.Contains(wrongErr.Errors, e => e.Contains("رمز تأكيد التسليم غير صحيح"));
            Assert.DoesNotContain(wrongErr.Errors, e => e.Contains("انتهت صلاحية") || e.Contains("صورة"));
            Assert.Equal(1, order.DeliveryOtpFailedAttempts);

            // Repeat to attempt 4
            await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999" });
            await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999" });
            await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999" });
            Assert.Equal(4, order.DeliveryOtpFailedAttempts);

            // 5th failed attempt locks out the OTP
            var res5 = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999" });
            Assert.IsType<BadRequestObjectResult>(res5.Result);
            Assert.Equal(5, order.DeliveryOtpFailedAttempts);

            // Even a correct PIN is rejected after five wrong attempts; management must intervene.
            var resLocked = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "4826" });
            var badLocked = Assert.IsType<BadRequestObjectResult>(resLocked.Result);
            var lockErr = Assert.IsType<ApiErr>(badLocked.Value);
            Assert.Contains(lockErr.Errors, e => e.Contains("استنفاد محاولات رمز التحقق"));
            Assert.Contains(lockErr.Errors, e => e.Contains("الإدارة"));
            Assert.DoesNotContain(lockErr.Errors, e => e.Contains("صورة"));

            // After management resets the attempts, the same customer PIN works despite legacy expiry.
            order.DeliveryOtpFailedAttempts = 0;
            order.DeliveryOtpExpiresAt = DateTime.UtcNow.AddMinutes(-5); // Expired
            await ordersDb.SaveChangesAsync();

            var resExpired = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "4826" });
            var delivered = Assert.IsType<OkObjectResult>(resExpired.Result);
            Assert.True((bool)delivered.Value);
            Assert.Equal(OrderDetailStatus.Delivered, order.OrderDetails.Single().OrderDetailStatus);
            Assert.Equal(0, order.DeliveryOtpFailedAttempts);
        }

        // =========================================================================
        // Test 4: Photos cannot bypass the customer PIN, including after lockout.
        // =========================================================================
        [Fact]
        public async Task Test04_ProofPhoto_CannotBypassPinVerification()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);

            var order = new Order
            {
                Id = 104,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryOtp = "1234",
                DeliveryOtpFailedAttempts = 5,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 401, OrderId = 104, MerchantId = 10, SingleFinalPrice = 5000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, currentDriverId: driverId);

            // Arbitrary external URL or random string is rejected
            var resArbitrary = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { PhotoUrl = "https://unverified.com/fake.jpg" });
            var badReq = Assert.IsType<BadRequestObjectResult>(resArbitrary.Result);
            var err = Assert.IsType<ApiErr>(badReq.Value);
            Assert.Contains(err.Errors, m => m.Contains("استنفاد محاولات رمز التحقق") || m.Contains("غير صحيح"));

            // Only the order-scoped upload endpoint may mint a valid proof URL.
            await using var photoStream = new MemoryStream(new byte[] { 1, 2, 3, 4 });
            var photo = new FormFile(photoStream, 0, photoStream.Length, "file", "proof.jpg")
            {
                Headers = new HeaderDictionary(),
                ContentType = "image/jpeg"
            };
            var upload = await controller.UploadProofPhoto(order.Id, photo);
            Assert.IsType<OkObjectResult>(upload.Result);
            var validServerPhoto = order.ProofOfDeliveryPhotoUrl;
            Assert.False(string.IsNullOrWhiteSpace(validServerPhoto));
            var resLocked = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { PhotoUrl = validServerPhoto });
            Assert.IsType<BadRequestObjectResult>(resLocked.Result);
            Assert.Equal(OrderDetailStatus.ShippingStarted, order.OrderDetails.Single().OrderDetailStatus);
            Assert.Equal(validServerPhoto, order.ProofOfDeliveryPhotoUrl);
            Assert.Equal(driverId, order.ProofPhotoUploadedBy);

            order.DeliveryOtpFailedAttempts = 0;
            await ordersDb.SaveChangesAsync();
            var resMissing = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { PhotoUrl = validServerPhoto });
            var missingErr = Assert.IsType<ApiErr>(Assert.IsType<BadRequestObjectResult>(resMissing.Result).Value);
            Assert.Contains("DELIVERY_PIN_REQUIRED", missingErr.Errors);
            Assert.Equal(0, order.DeliveryOtpFailedAttempts);

            var resWrong = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "9999", PhotoUrl = validServerPhoto });
            var wrongErr = Assert.IsType<ApiErr>(Assert.IsType<BadRequestObjectResult>(resWrong.Result).Value);
            Assert.Contains("DELIVERY_PIN_INCORRECT", wrongErr.Errors);
            Assert.Equal(1, order.DeliveryOtpFailedAttempts);
            Assert.Equal(OrderDetailStatus.ShippingStarted, order.OrderDetails.Single().OrderDetailStatus);
        }

        [Theory]
        [InlineData("1439")]
        [InlineData("١٤٣٩")]
        [InlineData("۱۴۳۹")]
        [InlineData("1 4 3 9")]
        [InlineData("\u200f1439\u200e")]
        public async Task DeliveryPin_ShownToCustomer_WorksAfterLegacyExpiry(string submittedPin)
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);
            var order = new Order
            {
                Id = 110,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveryOtp = "1439",
                DeliveryOtpFailedAttempts = 2,
                DeliveryOtpExpiresAt = DateTime.UtcNow.AddDays(-2),
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 1101, OrderId = 110, MerchantId = 10, SingleFinalPrice = 5000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();
            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, currentDriverId: driverId);

            var result = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = submittedPin });

            Assert.True((bool)Assert.IsType<OkObjectResult>(result.Result).Value);
            Assert.Equal(OrderDetailStatus.Delivered, order.OrderDetails.Single().OrderDetailStatus);
            Assert.Equal(0, order.DeliveryOtpFailedAttempts);
        }

        [Theory]
        [InlineData(null, "1439", "DELIVERY_PIN_UNAVAILABLE")]
        [InlineData("1439", null, "DELIVERY_PIN_REQUIRED")]
        [InlineData("1439", "143", "DELIVERY_PIN_REQUIRED")]
        [InlineData("1439", "14390", "DELIVERY_PIN_REQUIRED")]
        public async Task DeliveryPin_MustBeAvailable_AndExactlyFourDigits(string storedPin, string submittedPin, string expectedError)
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);
            var order = new Order
            {
                Id = 111,
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveryOtp = storedPin,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 1111, OrderId = 111, MerchantId = 10, SingleFinalPrice = 5000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();
            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, currentDriverId: driverId);

            var result = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = submittedPin });

            var error = Assert.IsType<ApiErr>(Assert.IsType<BadRequestObjectResult>(result.Result).Value);
            Assert.Contains(expectedError, error.Errors);
            Assert.Equal(OrderDetailStatus.ShippingStarted, order.OrderDetails.Single().OrderDetailStatus);
            Assert.Equal(0, order.DeliveryOtpFailedAttempts);
        }

        // =========================================================================
        // Test 5: CashToCollect_ProminentlyChecked_RequiresConfirmationForDifferentAmount_AndDebitsExactCustody
        // =========================================================================
        [Fact]
        public async Task Test05_CashToCollect_RequiresConfirmationForDifferentAmount_AndRecordsDiscrepancy()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);
            var ledgerService = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await ledgerService.SeedSystemAccountsAsync();

            var order = new Order
            {
                Id = 105,
                DeliveryOtp = "1439",
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveryUser = "Captain Ahmad",
                PaymentMethod = PaymentMethod.PayOnDelivery,
                DeliveryFee = 5000m,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 501, OrderId = 105, MerchantId = 10, SingleFinalPrice = 20000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            // Total pay = 25,000 SYP (20,000 + 5,000 delivery fee)
            accountingDb.Bills.Add(new Bill
            {
                OrderId = 105,
                MerchantId = 10,
                TotalAmount = 25000m,
                MerchantAmount = 18000m,
                JTakAmount = 7000m, // 2,000 platform commission + 5,000 delivery fee included in bill total
                JTakAdditionalAmount = 5000m, // Captain earning
                PaymentMethod = 0,
                DueDate = DateTime.UtcNow
            });
            await accountingDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, ledgerService: ledgerService, currentDriverId: driverId);

            // 1. Driver collected 23,000 instead of 25,000 without confirmation -> returns 400 CONFIRM_CASH_DIFFERENCE
            var resDiff = await controller.DeliverOrder(order.Id, new DeliverOrderRequest
            {
                Otp = "1439",
                CollectedCashAmount = 23000m,
                ConfirmDifferentCashAmount = false
            });
            var badReq = Assert.IsType<BadRequestObjectResult>(resDiff.Result);
            var err = Assert.IsType<ApiErr>(badReq.Value);
            Assert.Contains("CONFIRM_CASH_DIFFERENCE", err.Errors);

            // 2. Driver confirms different cash collection of 23,000 SYP (2,000 SYP shortage)
            var resConfirm = await controller.DeliverOrder(order.Id, new DeliverOrderRequest
            {
                Otp = "1439",
                CollectedCashAmount = 23000m,
                ConfirmDifferentCashAmount = true
            });
            var ok = Assert.IsType<OkObjectResult>(resConfirm.Result);
            Assert.True((bool)ok.Value);

            // Order status is posted and actual cash is recorded
            Assert.Equal(23000m, order.ActualCashCollected);
            Assert.Equal(OrderAccountingStatus.Posted, order.AccountingStatus);

            // Verify Ledger transaction
            var txn = await accountingDb.JournalTransactions
                .Include(t => t.Entries)
                .ThenInclude(e => e.Account)
                .FirstOrDefaultAsync(t => t.ReferenceType == "OrderDelivery" && t.ReferenceId == "105");

            Assert.NotNull(txn);
            // Driver float debited exactly 23,000
            var driverFloat = txn.Entries.Single(e => e.Account.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
            Assert.Equal(23000m, driverFloat.Debit);

            // Cash Shortage expense recorded for 2,000
            var shortageEntry = txn.Entries.Single(e => e.Account.AccountCode == SystemAccountCodes.CashShortageExpense);
            Assert.Equal(2000m, shortageEntry.Debit);

            // Total debits = 23,000 + 2,000 = 25,000 == Total credits (18,000 merchant + 5,000 captain + 2,000 platform)
            Assert.Equal(txn.Entries.Sum(e => e.Debit), txn.Entries.Sum(e => e.Credit));
        }

        // =========================================================================
        // Test 6: IdempotentDelivery_RepeatedCallsProduceOneCompletionAndOneLedgerTransaction
        // =========================================================================
        [Fact]
        public async Task Test06_IdempotentDelivery_RepeatedCallsProduceOneCompletionAndOneLedgerTransaction()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);
            var ledgerService = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await ledgerService.SeedSystemAccountsAsync();

            var order = new Order
            {
                Id = 106,
                DeliveryOtp = "1439",
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveryUser = "Captain Ahmad",
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 601, OrderId = 106, MerchantId = 10, SingleFinalPrice = 10000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            accountingDb.Bills.Add(new Bill
            {
                OrderId = 106,
                MerchantId = 10,
                TotalAmount = 10000m,
                MerchantAmount = 9000m,
                JTakAmount = 1000m,
                JTakAdditionalAmount = 0m,
                PaymentMethod = 0,
                DueDate = DateTime.UtcNow
            });
            await accountingDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, ledgerService: ledgerService, currentDriverId: driverId);

            // First delivery call
            var res1 = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "1439" });
            Assert.IsType<OkObjectResult>(res1.Result);
            Assert.Equal(OrderAccountingStatus.Posted, order.AccountingStatus);

            var txnCount1 = await accountingDb.JournalTransactions.CountAsync(t => t.ReferenceType == "OrderDelivery" && t.ReferenceId == "106");
            Assert.Equal(1, txnCount1);

            // Second delivery call (re-delivery idempotent replay)
            var res2 = await controller.DeliverOrder(order.Id);
            Assert.IsType<OkObjectResult>(res2.Result);

            var txnCount2 = await accountingDb.JournalTransactions.CountAsync(t => t.ReferenceType == "OrderDelivery" && t.ReferenceId == "106");
            Assert.Equal(1, txnCount2); // Still exactly 1 transaction
        }

        // =========================================================================
        // Test 7: AccountingOutage_LeavesOrderInDeliveredPendingAccounting_AndRecoversViaRetryQueue
        // =========================================================================
        [Fact]
        public async Task Test07_AccountingOutage_LeavesOrderInDeliveredPendingAccounting_AndRecoversViaRetryQueue()
        {
            var driverId = Guid.NewGuid();
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            using var shippingDb = CreateInMemoryShippingContext();
            var userManager = CreateMockUserManager(driverId);
            var orderService = CreateOrderService(ordersDb, userManager);

            // Mock LedgerService to throw on delivery split (simulating outage)
            var ledgerMock = new Mock<ILedgerService>();
            ledgerMock.Setup(l => l.PostOrderDeliveredSplitAsync(It.IsAny<OrderDeliveredSplitRequest>()))
                .ThrowsAsync(new InvalidOperationException("DB connection timeout during ledger posting"));

            var order = new Order
            {
                Id = 107,
                DeliveryOtp = "1439",
                UserId = Guid.NewGuid(),
                DeliveryId = driverId,
                DeliveryUser = "Captain Ahmad",
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 701, OrderId = 107, MerchantId = 10, SingleFinalPrice = 8000m, Quantity = 1, OrderDetailStatus = OrderDetailStatus.ShippingStarted }
                }
            };
            ordersDb.Orders.Add(order);
            await ordersDb.SaveChangesAsync();

            accountingDb.Bills.Add(new Bill
            {
                OrderId = 107,
                MerchantId = 10,
                TotalAmount = 8000m,
                MerchantAmount = 7200m,
                JTakAmount = 800m,
                JTakAdditionalAmount = 0m,
                PaymentMethod = 0,
                DueDate = DateTime.UtcNow
            });
            await accountingDb.SaveChangesAsync();

            var controller = CreateOrdersController(ordersDb, accountingDb, shippingDb, orderService, userManager, ledgerService: ledgerMock.Object, currentDriverId: driverId);

            // Deliver order during outage
            var res = await controller.DeliverOrder(order.Id, new DeliverOrderRequest { Otp = "1439" });
            // Driver still receives 200 OK because physical delivery succeeded
            Assert.IsType<OkObjectResult>(res.Result);

            // But order accounting status is PendingAccounting with error logged
            Assert.Equal(OrderAccountingStatus.PendingAccounting, order.AccountingStatus);
            Assert.Equal(1, order.AccountingRetryCount);
            Assert.Contains("DB connection timeout", order.AccountingLastError);

            // Now recover using OrderAccountingRetryService with real ledger
            var realLedger = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await realLedger.SeedSystemAccountsAsync();

            var retryLogger = new Mock<ILogger<OrderAccountingRetryService>>();
            var retryService = new OrderAccountingRetryService(ordersDb, accountingDb, realLedger, retryLogger.Object);

            var retryResult = await retryService.RetryPendingAccountingOrdersAsync();
            Assert.Equal(1, retryResult.TotalFound);
            Assert.Equal(1, retryResult.Succeeded);
            Assert.Contains(107, retryResult.SucceededOrderIds);

            // Order status is now Posted
            Assert.Equal(OrderAccountingStatus.Posted, order.AccountingStatus);
            Assert.NotNull(order.AccountingPostedAt);
            Assert.Null(order.AccountingLastError);
        }

        // =========================================================================
        // Test 8: SettlementService_PreventsPayoutWhileAccountingIsPending
        // =========================================================================
        [Fact]
        public async Task Test08_SettlementService_PreventsPayoutWhileAccountingIsPending()
        {
            var driverId = Guid.NewGuid();
            var merchantId = 25;
            using var ordersDb = CreateInMemoryOrdersContext();
            using var accountingDb = CreateInMemoryAccountingContext();
            var ledgerService = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await ledgerService.SeedSystemAccountsAsync();

            // Seed driver float and earnings
            await ledgerService.PostOrderDeliveredSplitAsync(new OrderDeliveredSplitRequest
            {
                OrderId = 999,
                CaptainUserId = driverId,
                CaptainName = "Captain Ahmad",
                DeliveryFee = 5000m,
                TotalsIncludeDeliveryFee = true,
                Currency = "SYP",
                IsCod = true,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = merchantId,
                        MerchantTitle = "Al-Sham Sweets",
                        TotalAmount = 50000m,
                        MerchantAmount = 45000m,
                        PlatformCommission = 5000m,
                        CaptainEarningAmount = 5000m
                    }
                }
            });

            // Insert an order that is PendingAccounting for this driver & merchant
            ordersDb.Orders.Add(new Order
            {
                Id = 108,
                DeliveryId = driverId,
                AccountingStatus = OrderAccountingStatus.PendingAccounting,
                PaymentMethod = PaymentMethod.PayOnDelivery,
                OrderDetails = new List<OrderDetail>
                {
                    new OrderDetail { Id = 801, OrderId = 108, MerchantId = merchantId, OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            });
            await ordersDb.SaveChangesAsync();

            var settlementLogger = new Mock<ILogger<SettlementRequestService>>();
            var settlementService = new SettlementRequestService(accountingDb, ledgerService, settlementLogger.Object, ordersDb);

            // 1. Captain balance checks HasPendingAccountingOrders and blocks available amount
            var captainBalance = await settlementService.GetCaptainBalanceAsync(driverId);
            Assert.True(captainBalance.HasPendingAccountingOrders);
            Assert.Equal(0m, captainBalance.AvailableAmount);

            // Attempting to request settlement throws
            var capEx = await Assert.ThrowsAsync<InvalidOperationException>(() =>
                settlementService.CreateCaptainRequestAsync(driverId, "Captain Ahmad", "0912345678", new CreateSettlementRequestDto { Amount = 1000m }));
            Assert.Contains("معلقة لم تكتمل قيودها المحاسبية", capEx.Message);

            // 2. Merchant balance checks HasPendingAccountingOrders and blocks available amount
            var merchantBalance = await settlementService.GetMerchantBalanceAsync(new[] { merchantId });
            Assert.True(merchantBalance.HasPendingAccountingOrders);
            Assert.Equal(0m, merchantBalance.AvailableAmount);

            var mEx = await Assert.ThrowsAsync<InvalidOperationException>(() =>
                settlementService.CreateMerchantRequestAsync(Guid.NewGuid(), "Owner", "0912345678", new[] { new MerchantSettlementSource { MerchantId = merchantId, MerchantTitle = "Al-Sham Sweets" } }, new CreateSettlementRequestDto { Amount = 1000m }));
            Assert.Contains("معلقة لم تكتمل قيودها المحاسبية", mEx.Message);
        }

        // =========================================================================
        // Test 9: CaptainEarning_IsCreditedIndependentlyOfDeliveryFee
        // =========================================================================
        [Fact]
        public async Task Test09_CaptainEarning_IsCreditedIndependentlyOfDeliveryFee()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            var ledgerService = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await ledgerService.SeedSystemAccountsAsync();

            var driverId = Guid.NewGuid();
            var merchantId = 30;

            // Delivery fee = 6,000 SYP. Courier earning = 4,000 SYP. Platform delivery markup = 2,000 SYP.
            var req = new OrderDeliveredSplitRequest
            {
                OrderId = 109,
                CaptainUserId = driverId,
                CaptainName = "Captain Maher",
                DeliveryFee = 6000m,
                DeliveryFeeIsPlatformRevenue = true,
                CaptainEarning = 4000m,
                TotalsIncludeDeliveryFee = false,
                Currency = "SYP",
                IsCod = true,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = merchantId,
                        MerchantTitle = "Damascus Bakery",
                        TotalAmount = 20000m,
                        MerchantAmount = 18000m,
                        PlatformCommission = 2000m
                    }
                }
            };

            var txn = await ledgerService.PostOrderDeliveredSplitAsync(req);

            // Debits: Driver float debited total cash (20,000 + 6,000 = 26,000)
            var driverFloat = txn.Entries.Single(e => e.AccountCode.StartsWith(SystemAccountCodes.CaptainCashFloatPrefix));
            Assert.Equal(26000m, driverFloat.Debit);

            // Credits:
            // 1. Merchant payable: 18,000
            var merchantPayable = txn.Entries.Single(e => e.AccountCode.StartsWith(SystemAccountCodes.VendorPayablePrefix));
            Assert.Equal(18000m, merchantPayable.Credit);

            // 2. Captain earnings: 4,000
            var captainEarnings = txn.Entries.Single(e => e.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix));
            Assert.Equal(4000m, captainEarnings.Credit);

            // 3. Platform delivery markup revenue: 2,000 (6,000 - 4,000)
            var deliveryRevenue = txn.Entries.Single(e => e.AccountCode == SystemAccountCodes.PlatformDeliveryFeeRevenue);
            Assert.Equal(2000m, deliveryRevenue.Credit);

            // 4. Platform commission: 2,000
            var commissionRevenue = txn.Entries.Single(e => e.AccountCode == SystemAccountCodes.PlatformCommissionRevenue);
            Assert.Equal(2000m, commissionRevenue.Credit);

            // Perfect balance to the penny
            Assert.Equal(26000m, txn.Entries.Sum(e => e.Debit));
            Assert.Equal(26000m, txn.Entries.Sum(e => e.Credit));
        }

        [Fact]
        public async Task DriverEarningAboveCustomerDeliveryFee_IsBalancedAsPlatformExpense()
        {
            using var accountingDb = CreateInMemoryAccountingContext();
            var ledgerService = new LedgerService(accountingDb, new Mock<ILogger<LedgerService>>().Object);
            await ledgerService.SeedSystemAccountsAsync();

            var request = new OrderDeliveredSplitRequest
            {
                OrderId = 110,
                CaptainUserId = Guid.NewGuid(),
                CaptainName = "Captain Test",
                DeliveryFee = 3000m,
                CaptainEarning = 6500m,
                IsCod = true,
                MerchantSplits = new List<MerchantSplitItem>
                {
                    new MerchantSplitItem
                    {
                        MerchantId = 31,
                        MerchantTitle = "Test Merchant",
                        TotalAmount = 10000m,
                        MerchantAmount = 9000m,
                        PlatformCommission = 1000m
                    }
                }
            };

            var transaction = await ledgerService.PostOrderDeliveredSplitAsync(request);

            var driverEarnings = transaction.Entries.Single(x =>
                x.AccountCode.StartsWith(SystemAccountCodes.CaptainEarningsPrefix));
            var subsidy = transaction.Entries.Single(x =>
                x.AccountCode == SystemAccountCodes.DriverEarningSubsidyExpense);
            Assert.Equal(6500m, driverEarnings.Credit);
            Assert.Equal(3500m, subsidy.Debit);
            Assert.DoesNotContain(transaction.Entries, x =>
                x.AccountCode == SystemAccountCodes.PlatformDeliveryFeeRevenue);
            Assert.Equal(transaction.Entries.Sum(x => x.Debit), transaction.Entries.Sum(x => x.Credit));
        }
    }
}
