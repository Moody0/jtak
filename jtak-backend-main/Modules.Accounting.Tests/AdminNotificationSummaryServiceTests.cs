using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Domain;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests;

public class AdminNotificationSummaryServiceTests
{
    private static OrdersDbContext CreateOrdersContext()
    {
        var options = new DbContextOptionsBuilder<OrdersDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new OrdersDbContext(options, null);
    }

    private static AppDbContext CreateAppContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AppDbContext(options, null);
    }

    private static AccountingDbContext CreateAccountingContext()
    {
        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AccountingDbContext(options, null);
    }

    [Fact]
    public async Task EmptyDatabases_ReturnsZeroCounts()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        Assert.NotNull(summary);
        Assert.Equal(0, summary.Orders);
        Assert.Equal(0, summary.SupportMessages);
        Assert.Equal(0, summary.DriverSettlements);
        Assert.Equal(0, summary.MerchantSettlements);
        Assert.Equal(0, summary.Reconciliation);
        Assert.Equal(0, summary.Users);
        Assert.Equal(0, summary.TotalActionable);
    }

    [Fact]
    public async Task Orders_AccuratelyCountsAllActiveNonTerminalOrders()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        // 1. Pending merchant decision -> Active (Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 101,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.Pending }
            }
        });

        // 2. Preparing / MerchantAccepted -> Active (Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 102,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.MerchantAccepted }
            }
        });

        // 3. Ready for pickup with no driver assigned -> Active (Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 103,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            DeliveryId = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.ReadyForPickup }
            }
        });

        // 4. Ready for pickup with driver assigned -> Active (Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 104,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            DeliveryId = Guid.NewGuid(),
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.ReadyForPickup }
            }
        });

        // 5. Shipping started / in delivery -> Active (Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 105,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            DeliveryId = Guid.NewGuid(),
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.ShippingStarted }
            }
        });

        // 6. Delivered item -> Terminal (NOT Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 106,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = DateTime.UtcNow,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.Delivered }
            }
        });

        // 7. CustomerCanceled -> Terminal (NOT Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 107,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.CustomerCanceled }
            }
        });

        // 8. DeliveryCanceled -> Terminal (NOT Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 108,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.DeliveryCanceled }
            }
        });

        // 9. MerchantRejected -> Terminal (NOT Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 109,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.MerchantRejected }
            }
        });

        // 10. Cart order (not placed/confirmed) -> Not placed (NOT Counted)
        ordersDb.Orders.Add(new Order
        {
            Id = 110,
            OrderStatus = OrderStatus.Pending,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.Pending }
            }
        });

        await ordersDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        // Exactly 5 active non-terminal orders (101, 102, 103, 104, 105)
        Assert.Equal(5, summary.Orders);

        // Lifecycle transition: mark order 105 as Delivered
        var order105 = await ordersDb.Orders.Include(o => o.OrderDetails).FirstAsync(o => o.Id == 105);
        order105.DeliveredAt = DateTime.UtcNow;
        order105.OrderDetails.First().OrderDetailStatus = OrderDetailStatus.Delivered;
        await ordersDb.SaveChangesAsync();

        var summaryAfterDelivery = await service.GetSummaryAsync();
        Assert.Equal(4, summaryAfterDelivery.Orders);
    }

    [Fact]
    public async Task SupportMessages_OnlyCountsNewMessages()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        appDb.SupportMessages.AddRange(
            new SupportMessage { Title = "Msg 1", Status = SupportMessageStatus.New },
            new SupportMessage { Title = "Msg 2", Status = SupportMessageStatus.Read },
            new SupportMessage { Title = "Msg 3", Status = SupportMessageStatus.Resolved },
            new SupportMessage { Title = "Msg 4", Status = SupportMessageStatus.New }
        );
        await appDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        Assert.Equal(2, summary.SupportMessages);
    }

    [Fact]
    public async Task Settlements_CountsPendingDriverAndMerchantRequests()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        accDb.SettlementRequests.AddRange(
            new SettlementRequest { RequestNumber = "DRV-1", PartyType = SettlementPartyType.Captain, Status = SettlementRequestStatus.Pending, Amount = 10_000m },
            new SettlementRequest { RequestNumber = "DRV-2", PartyType = SettlementPartyType.Captain, Status = SettlementRequestStatus.Completed, Amount = 20_000m },
            new SettlementRequest { RequestNumber = "MER-1", PartyType = SettlementPartyType.Merchant, Status = SettlementRequestStatus.Pending, Amount = 50_000m },
            new SettlementRequest { RequestNumber = "MER-2", PartyType = SettlementPartyType.Merchant, Status = SettlementRequestStatus.Approved, Amount = 75_000m },
            new SettlementRequest { RequestNumber = "MER-3", PartyType = SettlementPartyType.Merchant, Status = SettlementRequestStatus.Rejected, Amount = 15_000m }
        );
        await accDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        Assert.Equal(1, summary.DriverSettlements);
        Assert.Equal(1, summary.MerchantSettlements);
        Assert.Equal(2, summary.Reconciliation);
    }

    [Fact]
    public async Task EndToEnd_CompositeSummaryMatchesTotalActionable()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        ordersDb.Orders.Add(new Order
        {
            Id = 201,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.Pending } }
        });
        await ordersDb.SaveChangesAsync();

        appDb.SupportMessages.Add(new SupportMessage { Title = "Urgent inquiry", Status = SupportMessageStatus.New });
        await appDb.SaveChangesAsync();

        accDb.SettlementRequests.Add(new SettlementRequest
        {
            RequestNumber = "DRV-99",
            PartyType = SettlementPartyType.Captain,
            Status = SettlementRequestStatus.Pending,
            Amount = 15_000m
        });
        await accDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        Assert.Equal(1, summary.Orders);
        Assert.Equal(1, summary.SupportMessages);
        Assert.Equal(1, summary.DriverSettlements);
        Assert.Equal(0, summary.MerchantSettlements);
        Assert.Equal(1, summary.Reconciliation);
        Assert.Equal(0, summary.Users);
        Assert.Equal(3, summary.TotalActionable);
    }

    [Fact]
    public async Task ExactPromptScenario_TenTotal_FiveCompleted_ThreeCancelledOrRejected_YieldsTwoActiveOrders()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        // 5 Completed / Delivered orders
        for (int i = 1; i <= 5; i++)
        {
            ordersDb.Orders.Add(new Order
            {
                Id = 300 + i,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = DateTime.UtcNow,
                OrderDetails = new List<OrderDetail>
                {
                    new() { OrderDetailStatus = OrderDetailStatus.Delivered }
                }
            });
        }

        // 3 Cancelled / Rejected terminal orders
        ordersDb.Orders.Add(new Order
        {
            Id = 310,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.CustomerCanceled }
            }
        });
        ordersDb.Orders.Add(new Order
        {
            Id = 311,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.DeliveryCanceled }
            }
        });
        ordersDb.Orders.Add(new Order
        {
            Id = 312,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.MerchantRejected }
            }
        });

        // 2 Active in-progress orders
        ordersDb.Orders.Add(new Order
        {
            Id = 320,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.Pending }
            }
        });
        ordersDb.Orders.Add(new Order
        {
            Id = 321,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail>
            {
                new() { OrderDetailStatus = OrderDetailStatus.ShippingStarted }
            }
        });

        await ordersDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        // Total placed = 10, Completed = 5, Cancelled/Rejected = 3 -> Active = 2
        Assert.Equal(2, summary.Orders);
    }

    [Fact]
    public async Task FourBucketClassification_DistinctOrders_OverlappingConditionsAndCompletedExclusion()
    {
        using var ordersDb = CreateOrdersContext();
        using var appDb = CreateAppContext();
        using var accDb = CreateAccountingContext();

        // 1. Waiting approval = 2 orders (with driver)
        for (int i = 1; i <= 2; i++)
        {
            ordersDb.Orders.Add(new Order
            {
                Id = 400 + i,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = null,
                DeliveryId = Guid.NewGuid(),
                DeliveryUser = "Driver " + i,
                OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.Pending } }
            });
        }

        // 2. No courier assigned = 3 orders (in pending/processing states)
        for (int i = 1; i <= 3; i++)
        {
            ordersDb.Orders.Add(new Order
            {
                Id = 410 + i,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = null,
                DeliveryId = null,
                DeliveryUser = null,
                OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.MerchantAccepted } }
            });
        }

        // 3. Ready for delivery = 4 orders (with driver assigned)
        for (int i = 1; i <= 4; i++)
        {
            ordersDb.Orders.Add(new Order
            {
                Id = 420 + i,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = null,
                DeliveryId = Guid.NewGuid(),
                DeliveryUser = "Captain " + i,
                OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.ReadyForPickup } }
            });
        }

        // 4. In delivery = 1 order (with driver)
        ordersDb.Orders.Add(new Order
        {
            Id = 430,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            DeliveryId = Guid.NewGuid(),
            DeliveryUser = "Courier Main",
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.ShippingStarted } }
        });

        // 5. Add 100 completed orders -> must not affect badge
        for (int i = 1; i <= 100; i++)
        {
            ordersDb.Orders.Add(new Order
            {
                Id = 500 + i,
                OrderStatus = OrderStatus.Success,
                DeliveredAt = DateTime.UtcNow,
                DeliveryId = Guid.NewGuid(),
                DeliveryUser = "Past Driver",
                OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.Delivered } }
            });
        }

        // 6. Add cancelled / rejected orders -> must not affect badge
        ordersDb.Orders.Add(new Order
        {
            Id = 701,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.CustomerCanceled } }
        });
        ordersDb.Orders.Add(new Order
        {
            Id = 702,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.MerchantRejected } }
        });

        await ordersDb.SaveChangesAsync();

        var service = new AdminNotificationSummaryService(ordersDb, appDb, accDb);
        var summary = await service.GetSummaryAsync();

        // 2 waiting + 3 no courier + 4 ready + 1 in delivery = 10
        Assert.Equal(10, summary.Orders);

        // 7. Overlapping conditions: An order that is BOTH Ready for Delivery AND No Courier assigned
        // Must be counted ONCE (not twice).
        ordersDb.Orders.Add(new Order
        {
            Id = 801,
            OrderStatus = OrderStatus.Success,
            DeliveredAt = null,
            DeliveryId = null,
            DeliveryUser = null, // No courier assigned
            OrderDetails = new List<OrderDetail> { new() { OrderDetailStatus = OrderDetailStatus.ReadyForPickup } } // Ready for delivery
        });
        await ordersDb.SaveChangesAsync();

        var summaryWithOverlap = await service.GetSummaryAsync();
        Assert.Equal(11, summaryWithOverlap.Orders);

        // 8. Lifecycle transition: When an order is delivered, count decreases immediately
        var order430 = await ordersDb.Orders.Include(o => o.OrderDetails).FirstAsync(o => o.Id == 430);
        order430.DeliveredAt = DateTime.UtcNow;
        order430.OrderDetails.First().OrderDetailStatus = OrderDetailStatus.Delivered;
        await ordersDb.SaveChangesAsync();

        var summaryAfterTransition = await service.GetSummaryAsync();
        Assert.Equal(10, summaryAfterTransition.Orders);
    }
}
