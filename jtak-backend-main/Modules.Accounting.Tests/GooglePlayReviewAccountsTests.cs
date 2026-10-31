using App.Helpers.Authorization;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Moq;
using System.Security.Claims;
using Xunit;

namespace Modules.Accounting.Tests;

public class GooglePlayReviewAccountsTests
{
    [Theory]
    [InlineData("+963900000000", "Customer")]
    [InlineData("+963900000001", "Delivery")]
    [InlineData("+963900000002", "Merchant")]
    public async Task ProvisioningIsRoleBoundAndIdempotent(string phone, string role)
    {
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        var store = new Mock<IUserStore<AppUser>>();
        var users = new Mock<UserManager<AppUser>>(store.Object, null!, null!, null!, null!, null!, null!, null!, null!);
        users.SetupGet(x => x.Users).Returns(db.Users);
        var roles = new Dictionary<Guid, List<string>>();
        users.Setup(x => x.CreateAsync(It.IsAny<AppUser>())).Returns<AppUser>(async u =>
        { db.Users.Add(u); await db.SaveChangesAsync(); roles[u.Id] = new(); return IdentityResult.Success; });
        users.Setup(x => x.AddToRoleAsync(It.IsAny<AppUser>(), It.IsAny<string>()))
            .Returns<AppUser, string>((u, r) => { roles[u.Id].Add(r); return Task.FromResult(IdentityResult.Success); });
        users.Setup(x => x.GetRolesAsync(It.IsAny<AppUser>()))
            .Returns<AppUser>(u => Task.FromResult<IList<string>>(roles[u.Id]));
        users.Setup(x => x.GetClaimsAsync(It.IsAny<AppUser>()))
            .ReturnsAsync(new List<Claim>());
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            { ["Authentication:GooglePlayReview:Enabled"] = "true" }).Build();
        var service = new CustomerOtpService(new AppUnitOfWork(db), users.Object, null!, config, null!);
        var first = await service.EnsureReviewAccountAsync(phone);
        var second = await service.EnsureReviewAccountAsync(phone);
        Assert.Equal(first.Id, second.Id);
        Assert.Single(await db.Users.ToListAsync());
        Assert.Equal(new[] { role }, roles[first.Id]);
        Assert.Equal(phone, first.PhoneNumber);
        Assert.True(first.IsActive);

        roles[first.Id].Add("Admin");
        await Assert.ThrowsAsync<CustomerOtpException>(() => service.EnsureReviewAccountAsync(phone));
    }

    [Fact]
    public async Task DisabledReviewModeDoesNotCreateAccounts()
    {
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        var users = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(), null!, null!, null!, null!, null!, null!, null!, null!);
        var service = new CustomerOtpService(new AppUnitOfWork(db), users.Object, null!, new ConfigurationBuilder().Build(), null!);
        Assert.Null(await service.EnsureReviewAccountAsync(GooglePlayReviewIdentity.DriverPhone));
        Assert.Null(await service.EnsureReviewAccountAsync(GooglePlayReviewIdentity.MerchantPhone));
        Assert.Empty(await db.Users.ToListAsync());
    }
}
