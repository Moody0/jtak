using App.Shared.Data.MultiContext;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Modules.Accounting.Services;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Modules.Accounting.Tests;

public class BillDataTableServiceTests
{
    private AccountingDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AccountingDbContext(options, null);
    }

    private BillService CreateBillService(AccountingDbContext context)
    {
        var repo = new TrackableRepository<Bill, AccountingDbContext>(context);
        return new BillService(repo);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchByBillId_ReturnsMatchingBill()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 830, MerchantAmount = 830, CreatedDate = DateTime.UtcNow.AddMinutes(-10), DueDate = DateTime.UtcNow },
            new Bill { Id = 12, OrderId = 30, MerchantId = 25, TotalAmount = 1500, MerchantAmount = 1400, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);
        var merchants = new Dictionary<int, string>
        {
            { 24, "تيستي مرسين" },
            { 25, "حلويات الفردوس" }
        };

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "11"
        };

        var result = await service.GetDataTableAsync(request, merchants);

        Assert.NotNull(result);
        Assert.Equal(1, result.TotalRecords);
        Assert.Single(result.Items);
        Assert.Equal(11, result.Items.First().Id);
        Assert.Equal("تيستي مرسين", result.Items.First().MerchantTitle);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchByHashPrefixBillId_ReturnsMatchingBill()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 830, MerchantAmount = 830, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 12, OrderId = 30, MerchantId = 25, TotalAmount = 1500, MerchantAmount = 1400, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);
        var merchants = new Dictionary<int, string>
        {
            { 24, "تيستي مرسين" },
            { 25, "حلويات الفردوس" }
        };

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "#11"
        };

        var result = await service.GetDataTableAsync(request, merchants);

        Assert.NotNull(result);
        Assert.Equal(1, result.TotalRecords);
        Assert.Single(result.Items);
        Assert.Equal(11, result.Items.First().Id);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchByMerchantTitle_ReturnsMatchingBills()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 830, MerchantAmount = 830, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 12, OrderId = 30, MerchantId = 25, TotalAmount = 1500, MerchantAmount = 1400, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);
        var merchants = new Dictionary<int, string>
        {
            { 24, "تيستي مرسين" },
            { 25, "حلويات الفردوس" }
        };

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "تيستي"
        };

        var result = await service.GetDataTableAsync(request, merchants);

        Assert.NotNull(result);
        Assert.Equal(1, result.TotalRecords);
        Assert.Single(result.Items);
        Assert.Equal(24, result.Items.First().MerchantId);
        Assert.Equal("تيستي مرسين", result.Items.First().MerchantTitle);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchByOrderId_ReturnsMatchingBill()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 830, MerchantAmount = 830, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 12, OrderId = 99, MerchantId = 25, TotalAmount = 1500, MerchantAmount = 1400, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "99"
        };

        var result = await service.GetDataTableAsync(request);

        Assert.NotNull(result);
        Assert.Equal(1, result.TotalRecords);
        Assert.Equal(12, result.Items.First().Id);
        Assert.Equal(99, result.Items.First().OrderId);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchByAmount_ReturnsMatchingBill()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 42290, MerchantAmount = 41890, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 12, OrderId = 30, MerchantId = 25, TotalAmount = 1500, MerchantAmount = 1400, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "42290"
        };

        var result = await service.GetDataTableAsync(request);

        Assert.NotNull(result);
        Assert.Equal(1, result.TotalRecords);
        Assert.Equal(11, result.Items.First().Id);
        Assert.Equal(42290m, result.Items.First().TotalAmount);
    }

    [Fact]
    public async Task GetDataTableAsync_SearchNoMatch_ReturnsEmptyWithoutException()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 11, OrderId = 29, MerchantId = 24, TotalAmount = 830, MerchantAmount = 830, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10,
            Search = "non_existent_search_query_xyz"
        };

        var result = await service.GetDataTableAsync(request);

        Assert.NotNull(result);
        Assert.Equal(0, result.TotalRecords);
        Assert.Empty(result.Items);
    }

    [Fact]
    public async Task GetDataTableAsync_WithSortingAndPaging_ReturnsCorrectPage()
    {
        using var context = CreateInMemoryContext();
        for (int i = 1; i <= 15; i++)
        {
            context.Bills.Add(new Bill
            {
                Id = i,
                OrderId = 100 + i,
                MerchantId = 1,
                TotalAmount = i * 100,
                MerchantAmount = i * 90,
                CreatedDate = DateTime.UtcNow.AddMinutes(-i),
                DueDate = DateTime.UtcNow
            });
        }
        await context.SaveChangesAsync();

        var service = CreateBillService(context);

        var request = new MetronicTable
        {
            PageNumber = 2,
            PageSize = 5,
            SortField = "id",
            SortOrder = "ASC"
        };

        var result = await service.GetDataTableAsync(request);

        Assert.NotNull(result);
        Assert.Equal(15, result.TotalRecords);
        Assert.Equal(5, result.Items.Length);
        Assert.Equal(6, result.Items[0].Id);
        Assert.Equal(10, result.Items[4].Id);
    }

    [Fact]
    public async Task GetDataTableAsync_WithAllowedMerchantIds_FiltersByAllowedMerchants()
    {
        using var context = CreateInMemoryContext();
        context.Bills.AddRange(
            new Bill { Id = 1, MerchantId = 10, OrderId = 1, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 2, MerchantId = 20, OrderId = 2, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow },
            new Bill { Id = 3, MerchantId = 30, OrderId = 3, CreatedDate = DateTime.UtcNow, DueDate = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var service = CreateBillService(context);

        var request = new MetronicTable
        {
            PageNumber = 1,
            PageSize = 10
        };

        var result = await service.GetDataTableAsync(request, null, new[] { 10, 30 });

        Assert.NotNull(result);
        Assert.Equal(2, result.TotalRecords);
        Assert.Contains(result.Items, b => b.Id == 1);
        Assert.Contains(result.Items, b => b.Id == 3);
        Assert.DoesNotContain(result.Items, b => b.Id == 2);
    }
}