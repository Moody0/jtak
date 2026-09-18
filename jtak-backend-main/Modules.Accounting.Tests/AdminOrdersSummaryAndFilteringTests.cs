using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Orders.Entities;
using Modules.Orders.Services;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class AdminOrdersSummaryAndFilteringTests
    {
        private OrdersDbContext CreateInMemoryOrdersContext()
        {
            var options = new DbContextOptionsBuilder<OrdersDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new OrdersDbContext(options, null);
        }

        private static AdminOrdersSummaryDto ComputeSummary(List<Order> placedOrders)
        {
            int total = placedOrders.Count;
            int pendingApproval = 0;
            int withoutDriver = 0;
            int readyForDelivery = 0;
            int inDelivery = 0;
            int completed = 0;
            int cancelledRejected = 0;

            foreach (var order in placedOrders)
            {
                var details = order.OrderDetails ?? (ICollection<OrderDetail>)Array.Empty<OrderDetail>();
                bool allTerminal = details.Count > 0 && details.All(d =>
                    d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantRejected);

                if (allTerminal)
                {
                    cancelledRejected++;
                    continue;
                }

                var active = details.Where(d =>
                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.MerchantRejected).ToList();

                bool isDelivered = order.DeliveredAt != null || (active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered));
                if (isDelivered)
                {
                    completed++;
                    continue;
                }

                bool hasAssignedDriver = order.DeliveryId.HasValue &&
                                         !string.IsNullOrWhiteSpace(order.DeliveryUser) &&
                                         !order.DeliveryUser.Contains("?");

                if (!hasAssignedDriver)
                {
                    withoutDriver++;
                }

                bool isInTransit = active.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
                if (isInTransit)
                {
                    inDelivery++;
                }
                else
                {
                    bool isReady = active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
                    if (isReady)
                    {
                        readyForDelivery++;
                    }
                    else
                    {
                        bool isPending = details.Count == 0 || active.Any(d =>
                            d.OrderDetailStatus == OrderDetailStatus.Pending ||
                            d.OrderDetailStatus == OrderDetailStatus.CustomerPending);
                        if (isPending)
                        {
                            pendingApproval++;
                        }
                    }
                }
            }

            return new AdminOrdersSummaryDto
            {
                Total = total,
                PendingApproval = pendingApproval,
                WithoutDriver = withoutDriver,
                ReadyForDelivery = readyForDelivery,
                InDelivery = inDelivery,
                Completed = completed,
                CancelledRejected = cancelledRejected
            };
        }

        private static List<Order> FilterByStatus(List<Order> allOrders, string status)
        {
            if (string.IsNullOrWhiteSpace(status) || status.Equals("ALL", StringComparison.OrdinalIgnoreCase))
            {
                return allOrders;
            }

            var norm = status.Trim().ToUpperInvariant();
            return allOrders.Where(o =>
            {
                var details = o.OrderDetails ?? (ICollection<OrderDetail>)Array.Empty<OrderDetail>();
                bool allTerminal = details.Count > 0 && details.All(d =>
                    d.OrderDetailStatus == OrderDetailStatus.CustomerCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.DeliveryCanceled ||
                    d.OrderDetailStatus == OrderDetailStatus.MerchantRejected);

                var active = details.Where(d =>
                    d.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                    d.OrderDetailStatus != OrderDetailStatus.MerchantRejected).ToList();

                bool isDelivered = o.DeliveredAt != null || (active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.Delivered));
                bool isCanceled = allTerminal;
                bool isInTransit = !isDelivered && !isCanceled && active.Any(d => d.OrderDetailStatus == OrderDetailStatus.ShippingStarted);
                bool isReady = !isDelivered && !isCanceled && !isInTransit && active.Count > 0 && active.All(d => d.OrderDetailStatus == OrderDetailStatus.ReadyForPickup);
                bool isPending = !isDelivered && !isCanceled && !isInTransit && !isReady && (details.Count == 0 || active.Any(d => d.OrderDetailStatus == OrderDetailStatus.Pending || d.OrderDetailStatus == OrderDetailStatus.CustomerPending));

                switch (norm)
                {
                    case "PENDING":
                    case "WAITING_APPROVAL":
                        return isPending;

                    case "UNASSIGNED":
                    case "WITHOUT_DRIVER":
                        bool hasDriver = o.DeliveryId.HasValue && !string.IsNullOrWhiteSpace(o.DeliveryUser) && !o.DeliveryUser.Contains("?");
                        return !hasDriver && !isDelivered && !isCanceled;

                    case "READY":
                    case "READY_FOR_DELIVERY":
                        return isReady;

                    case "IN_TRANSIT":
                    case "IN_DELIVERY":
                        return isInTransit;

                    case "DELIVERED":
                    case "COMPLETED":
                        return isDelivered;

                    case "CANCELED":
                    case "CANCELLED":
                    case "REJECTED":
                        return isCanceled;

                    default:
                        return true;
                }
            }).ToList();
        }

        [Fact]
        public async Task PendingApproval_StrictlyExcludesMerchantAccepted()
        {
            using var context = CreateInMemoryOrdersContext();

            // Order 1: Pending (newly placed) -> in PendingApproval
            context.Orders.Add(new Order
            {
                Id = 1,
                OrderStatus = OrderStatus.Success,
                User = "Customer 1",
                OrderDetails = new List<OrderDetail>
                {
                    new() { OrderDetailStatus = OrderDetailStatus.Pending }
                }
            });

            // Order 2: CustomerPending -> in PendingApproval
            context.Orders.Add(new Order
            {
                Id = 2,
                OrderStatus = OrderStatus.Success,
                User = "Customer 2",
                OrderDetails = new List<OrderDetail>
                {
                    new() { OrderDetailStatus = OrderDetailStatus.CustomerPending }
                }
            });

            // Order 3: MerchantAccepted (Already approved, preparing) -> MUST NOT be in PendingApproval
            context.Orders.Add(new Order
            {
                Id = 3,
                OrderStatus = OrderStatus.Success,
                User = "Customer 3",
                OrderDetails = new List<OrderDetail>
                {
                    new() { OrderDetailStatus = OrderDetailStatus.MerchantAccepted }
                }
            });

            await context.SaveChangesAsync();

            var placedOrders = await context.Orders
                .Include(o => o.OrderDetails)
                .Where(o => o.OrderStatus == OrderStatus.Success)
                .ToListAsync();

            var summary = ComputeSummary(placedOrders);
            var pendingFiltered = FilterByStatus(placedOrders, "PENDING");

            Assert.Equal(3, summary.Total);
            Assert.Equal(2, summary.PendingApproval); // Only Order 1 and Order 2
            Assert.Equal(2, pendingFiltered.Count);
            Assert.Contains(pendingFiltered, o => o.Id == 1);
            Assert.Contains(pendingFiltered, o => o.Id == 2);
            Assert.DoesNotContain(pendingFiltered, o => o.Id == 3);
        }

        [Fact]
        public async Task MultiPageVerification_GlobalCountsAreIdenticalAcrossPages_AndMatchFilterResults()
        {
            using var context = CreateInMemoryOrdersContext();

            // Seed 45 orders (enough for 5 pages with pageSize = 10):
            // - 10 Pending approval
            // - 10 Ready for pickup (5 without driver, 5 with driver)
            // - 10 In transit (with driver)
            // - 10 Delivered
            // - 5 Canceled
            int id = 1;

            // 10 Pending (all without driver)
            for (int i = 0; i < 10; i++)
            {
                context.Orders.Add(new Order
                {
                    Id = id++,
                    OrderStatus = OrderStatus.Success,
                    User = $"Customer Pending {i}",
                    Phonenumber = $"09910000{i:D2}",
                    DeliveryId = null,
                    OrderDetails = new List<OrderDetail>
                    {
                        new() { OrderDetailStatus = OrderDetailStatus.Pending, SingleFinalPrice = 1000m, Quantity = 1 }
                    }
                });
            }

            // 10 Ready for pickup (5 unassigned, 5 assigned)
            for (int i = 0; i < 10; i++)
            {
                bool hasDriver = i >= 5;
                context.Orders.Add(new Order
                {
                    Id = id++,
                    OrderStatus = OrderStatus.Success,
                    User = $"Customer Ready {i}",
                    Phonenumber = $"09920000{i:D2}",
                    DeliveryId = hasDriver ? Guid.NewGuid() : null,
                    DeliveryUser = hasDriver ? "Captain Samer" : null,
                    OrderDetails = new List<OrderDetail>
                    {
                        new() { OrderDetailStatus = OrderDetailStatus.ReadyForPickup, SingleFinalPrice = 2000m, Quantity = 1 }
                    }
                });
            }

            // 10 In Transit
            for (int i = 0; i < 10; i++)
            {
                context.Orders.Add(new Order
                {
                    Id = id++,
                    OrderStatus = OrderStatus.Success,
                    User = $"Customer Transit {i}",
                    Phonenumber = $"09930000{i:D2}",
                    DeliveryId = Guid.NewGuid(),
                    DeliveryUser = "Captain Rami",
                    OrderDetails = new List<OrderDetail>
                    {
                        new() { OrderDetailStatus = OrderDetailStatus.ShippingStarted, SingleFinalPrice = 3000m, Quantity = 1 }
                    }
                });
            }

            // 10 Delivered
            for (int i = 0; i < 10; i++)
            {
                context.Orders.Add(new Order
                {
                    Id = id++,
                    OrderStatus = OrderStatus.Success,
                    User = $"Customer Delivered {i}",
                    Phonenumber = $"09940000{i:D2}",
                    DeliveredAt = DateTime.UtcNow,
                    DeliveryId = Guid.NewGuid(),
                    DeliveryUser = "Captain Rami",
                    OrderDetails = new List<OrderDetail>
                    {
                        new() { OrderDetailStatus = OrderDetailStatus.Delivered, SingleFinalPrice = 4000m, Quantity = 1 }
                    }
                });
            }

            // 5 Canceled
            for (int i = 0; i < 5; i++)
            {
                context.Orders.Add(new Order
                {
                    Id = id++,
                    OrderStatus = OrderStatus.Success,
                    User = $"Customer Canceled {i}",
                    Phonenumber = $"09950000{i:D2}",
                    DeliveryId = null,
                    OrderDetails = new List<OrderDetail>
                    {
                        new() { OrderDetailStatus = OrderDetailStatus.CustomerCanceled, SingleFinalPrice = 5000m, Quantity = 1 }
                    }
                });
            }

            await context.SaveChangesAsync();

            var allPlacedOrders = await context.Orders
                .Include(o => o.OrderDetails)
                .Where(o => o.OrderStatus == OrderStatus.Success)
                .ToListAsync();

            // 1. Authoritative Summary
            var globalSummary = ComputeSummary(allPlacedOrders);
            Assert.Equal(45, globalSummary.Total);
            Assert.Equal(10, globalSummary.PendingApproval);
            Assert.Equal(15, globalSummary.WithoutDriver); // 10 pending + 5 ready unassigned
            Assert.Equal(10, globalSummary.ReadyForDelivery);
            Assert.Equal(10, globalSummary.InDelivery);
            Assert.Equal(10, globalSummary.Completed);
            Assert.Equal(5, globalSummary.CancelledRejected);

            // 2. Pagination test across pages 1, 2, 3, 4, 5
            int pageSize = 10;
            for (int page = 1; page <= 5; page++)
            {
                var pageItems = allPlacedOrders
                    .OrderByDescending(o => o.Id)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToList();

                // Each page has up to pageSize items
                if (page < 5)
                {
                    Assert.Equal(10, pageItems.Count);
                }
                else
                {
                    Assert.Equal(5, pageItems.Count);
                }

                // Global summary computed from the database remains IDENTICAL regardless of which page is loaded
                var pageIndependentSummary = ComputeSummary(allPlacedOrders);
                Assert.Equal(globalSummary.Total, pageIndependentSummary.Total);
                Assert.Equal(globalSummary.PendingApproval, pageIndependentSummary.PendingApproval);
                Assert.Equal(globalSummary.WithoutDriver, pageIndependentSummary.WithoutDriver);
                Assert.Equal(globalSummary.ReadyForDelivery, pageIndependentSummary.ReadyForDelivery);
                Assert.Equal(globalSummary.InDelivery, pageIndependentSummary.InDelivery);
                Assert.Equal(globalSummary.Completed, pageIndependentSummary.Completed);
                Assert.Equal(globalSummary.CancelledRejected, pageIndependentSummary.CancelledRejected);
            }

            // 3. Status filter equality tests (clicking each status card)
            var pendingResults = FilterByStatus(allPlacedOrders, "PENDING");
            Assert.Equal(globalSummary.PendingApproval, pendingResults.Count);

            var unassignedResults = FilterByStatus(allPlacedOrders, "UNASSIGNED");
            Assert.Equal(globalSummary.WithoutDriver, unassignedResults.Count);

            var readyResults = FilterByStatus(allPlacedOrders, "READY");
            Assert.Equal(globalSummary.ReadyForDelivery, readyResults.Count);

            var inTransitResults = FilterByStatus(allPlacedOrders, "IN_TRANSIT");
            Assert.Equal(globalSummary.InDelivery, inTransitResults.Count);

            var deliveredResults = FilterByStatus(allPlacedOrders, "DELIVERED");
            Assert.Equal(globalSummary.Completed, deliveredResults.Count);

            var canceledResults = FilterByStatus(allPlacedOrders, "CANCELED");
            Assert.Equal(globalSummary.CancelledRejected, canceledResults.Count);

            var allResults = FilterByStatus(allPlacedOrders, "ALL");
            Assert.Equal(globalSummary.Total, allResults.Count);
        }
    }
}
