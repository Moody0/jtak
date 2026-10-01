using System;
using System.Threading.Tasks;
using App.ApiControllers.V1.Admin;
using App.Shared.Data.App;
using App.Shared.Entities.Domain;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Modules.Accounting.Tests;

public class AdminErrandQueueTests
{
    [Fact]
    public async Task List_SeparatesSupportAndPaginatesActiveRequests()
    {
        using var app = CreateAppContext();
        app.SupportMessages.AddRange(
            new SupportMessage { Title = "Support", SenderName = "Customer", Status = SupportMessageStatus.New },
            new SupportMessage { Title = "Request", SenderName = "Ali", ErrandStatus = ErrandStatus.Submitted, CreatedDate = new DateTime(2026, 9, 20) },
            new SupportMessage { Title = "Request", SenderName = "Omar", ErrandStatus = ErrandStatus.Approved, CreatedDate = new DateTime(2026, 9, 21) },
            new SupportMessage { Title = "Request", SenderName = "Rami", ErrandStatus = ErrandStatus.Delivered, CreatedDate = new DateTime(2026, 9, 22) });
        await app.SaveChangesAsync();
        var api = CreateController(app);

        var result = Assert.IsType<OkObjectResult>((await api.List(pageSize: 1)).Result);
        var page = Assert.IsType<ErrandQueuePageDto>(result.Value);
        Assert.Equal(2, page.TotalCount);
        Assert.Single(page.Items);
        Assert.Contains(page.Items[0].SenderName, new[] { "Ali", "Omar" });

        var firstName = page.Items[0].SenderName;
        result = Assert.IsType<OkObjectResult>((await api.List(page: 2, pageSize: 1)).Result);
        page = Assert.IsType<ErrandQueuePageDto>(result.Value);
        Assert.Equal(2, page.TotalCount);
        Assert.Single(page.Items);
        Assert.NotEqual(firstName, page.Items[0].SenderName);

        result = Assert.IsType<OkObjectResult>((await api.List(bucket: "closed")).Result);
        page = Assert.IsType<ErrandQueuePageDto>(result.Value);
        Assert.Equal(1, page.TotalCount);
        Assert.Equal("Rami", page.Items[0].SenderName);

        result = Assert.IsType<OkObjectResult>((await api.List(bucket: "all", search: "Ali")).Result);
        page = Assert.IsType<ErrandQueuePageDto>(result.Value);
        Assert.Equal(1, page.TotalCount);
        Assert.Equal("Ali", page.Items[0].SenderName);

        Assert.IsType<BadRequestObjectResult>((await api.List(bucket: "unknown")).Result);
        Assert.IsType<BadRequestObjectResult>((await api.List(pageSize: 101)).Result);
    }

    [Fact]
    public async Task Stats_GroupsRequestsByWorkflowState()
    {
        using var app = CreateAppContext();
        app.SupportMessages.AddRange(
            new SupportMessage { Title = "Support", Status = SupportMessageStatus.New },
            new SupportMessage { ErrandStatus = ErrandStatus.Submitted },
            new SupportMessage { ErrandStatus = ErrandStatus.Declined },
            new SupportMessage { ErrandStatus = ErrandStatus.Quoted },
            new SupportMessage { ErrandStatus = ErrandStatus.Approved },
            new SupportMessage { ErrandStatus = ErrandStatus.Assigned },
            new SupportMessage { ErrandStatus = ErrandStatus.Purchased },
            new SupportMessage { ErrandStatus = ErrandStatus.Delivered });
        await app.SaveChangesAsync();
        var result = Assert.IsType<OkObjectResult>((await CreateController(app).Stats()).Result);
        var stats = Assert.IsType<ErrandQueueStatsDto>(result.Value);
        Assert.Equal(2, stats.New);
        Assert.Equal(1, stats.Quoted);
        Assert.Equal(1, stats.Approved);
        Assert.Equal(2, stats.InProgress);
        Assert.Equal(1, stats.Closed);
    }

    private static AppDbContext CreateAppContext() => new(
        new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"admin-errands-{Guid.NewGuid()}").Options,
        new HttpContextAccessor());

    private static ErrandRequestsController CreateController(AppDbContext app) =>
        new(app, null, null, null, null, NullLogger<ErrandRequestsController>.Instance);
}
