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
    [InlineData("+963900000000", "Customer", false, false)]
    [InlineData("+963900000001", "Delivery", false, false)]
    [InlineData("+963900000002", "Merchant", false, false)]
    [InlineData("+963900000001", "Delivery", true, false)]
    [InlineData("+963900000002", "Merchant", true, false)]
    [InlineData("+963900000001", "Delivery", false, true)]
    [InlineData("+963900000002", "Merchant", true, true)]
    public async Task ProvisioningIsRoleBoundAndIdempotent(string phone, string role, bool existingPasswordless, bool synchronize)
    {
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        var store = new Mock<IUserStore<AppUser>>();
        var users = new Mock<UserManager<AppUser>>(store.Object, null!, null!, null!, null!, null!, null!, null!, null!);
        users.SetupGet(x => x.Users).Returns(db.Users);
        var roles = new Dictionary<Guid, List<string>>();
        users.Setup(x => x.CreateAsync(It.IsAny<AppUser>())).Returns<AppUser>(async u =>
        { db.Users.Add(u); await db.SaveChangesAsync(); roles[u.Id] = new(); return IdentityResult.Success; });
        var hasher = new PasswordHasher<AppUser>();
        const string password = "Reviewer.TestPassword!456";
        users.Setup(x => x.CreateAsync(It.IsAny<AppUser>(), It.IsAny<string>())).Returns<AppUser, string>(async (u, p) =>
        { u.PasswordHash = hasher.HashPassword(u, p); db.Users.Add(u); await db.SaveChangesAsync(); roles[u.Id] = new(); return IdentityResult.Success; });
        users.Setup(x => x.HasPasswordAsync(It.IsAny<AppUser>())).Returns<AppUser>(u => Task.FromResult(!string.IsNullOrEmpty(u.PasswordHash)));
        users.Setup(x => x.AddPasswordAsync(It.IsAny<AppUser>(), It.IsAny<string>())).Returns<AppUser, string>(async (u, p) =>
        { u.PasswordHash = hasher.HashPassword(u, p); await db.SaveChangesAsync(); return IdentityResult.Success; });
        users.Setup(x => x.CheckPasswordAsync(It.IsAny<AppUser>(), It.IsAny<string>())).Returns<AppUser, string>((u, p) =>
            Task.FromResult(hasher.VerifyHashedPassword(u, u.PasswordHash!, p) != PasswordVerificationResult.Failed));
        users.Setup(x => x.GeneratePasswordResetTokenAsync(It.IsAny<AppUser>())).ReturnsAsync("reviewer-reset-token");
        users.Setup(x => x.ResetPasswordAsync(It.IsAny<AppUser>(), "reviewer-reset-token", It.IsAny<string>()))
            .Returns<AppUser, string, string>(async (u, token, p) =>
            { u.PasswordHash = hasher.HashPassword(u, p); await db.SaveChangesAsync(); return IdentityResult.Success; });
        users.Setup(x => x.UpdateAsync(It.IsAny<AppUser>())).Returns<AppUser>(async u =>
        { await db.SaveChangesAsync(); return IdentityResult.Success; });
        users.Setup(x => x.AddToRoleAsync(It.IsAny<AppUser>(), It.IsAny<string>()))
            .Returns<AppUser, string>((u, r) => { roles[u.Id].Add(r); return Task.FromResult(IdentityResult.Success); });
        users.Setup(x => x.GetRolesAsync(It.IsAny<AppUser>()))
            .Returns<AppUser>(u => Task.FromResult<IList<string>>(roles[u.Id]));
        users.Setup(x => x.GetClaimsAsync(It.IsAny<AppUser>()))
            .ReturnsAsync(new List<Claim>());
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            { ["Authentication:GooglePlayReview:Enabled"] = "true",
              ["Authentication:GooglePlayReview:SynchronizePasswords"] = synchronize.ToString(),
              ["Authentication:GooglePlayReview:DriverPassword"] = password,
              ["Authentication:GooglePlayReview:MerchantPassword"] = password }).Build();
        var service = new CustomerOtpService(new AppUnitOfWork(db), users.Object, null!, config, null!);
        if (existingPasswordless)
        {
            var id = role == "Delivery" ? GooglePlayReviewIdentity.DriverId : GooglePlayReviewIdentity.MerchantId;
            db.Users.Add(new AppUser { Id = id, PhoneNumber = phone, UserName = phone, IsActive = true });
            await db.SaveChangesAsync(); roles[id] = new() { role };
        }
        var first = await service.EnsureReviewAccountAsync(phone);
        var savedHash = first.PasswordHash;
        first.AccessFailedCount = 5;
        first.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(15);
        if (role != "Customer")
            config["Authentication:GooglePlayReview:" + (role == "Delivery" ? "DriverPassword" : "MerchantPassword")] = "Changed.ConfigPassword!789";
        var second = await service.EnsureReviewAccountAsync(phone);
        Assert.Equal(first.Id, second.Id);
        Assert.Single(await db.Users.ToListAsync());
        Assert.Equal(new[] { role }, roles[first.Id]);
        Assert.Equal(phone, first.PhoneNumber);
        Assert.True(first.IsActive);
        Assert.True(first.EmailConfirmed);
        Assert.True(first.PhoneNumberConfirmed);
        Assert.True((await db.Users.AsNoTracking().SingleAsync()).EmailConfirmed);
        users.Verify(x => x.ResetPasswordAsync(It.IsAny<AppUser>(), It.IsAny<string>(), It.IsAny<string>()),
            synchronize ? Times.Once() : Times.Never());
        Assert.Equal(synchronize ? 0 : 5, second.AccessFailedCount);
        Assert.Equal(synchronize, second.LockoutEnd == null);
        if (!synchronize) Assert.Equal(savedHash, second.PasswordHash);
        if (role != "Customer")
            Assert.NotEqual(PasswordVerificationResult.Failed, hasher.VerifyHashedPassword(first, first.PasswordHash!,
                synchronize ? "Changed.ConfigPassword!789" : password));
        var currentHash = second.PasswordHash;
        await service.EnsureReviewAccountAsync(phone);
        Assert.Equal(currentHash, second.PasswordHash);
        users.Verify(x => x.ResetPasswordAsync(It.IsAny<AppUser>(), It.IsAny<string>(), It.IsAny<string>()),
            synchronize ? Times.Once() : Times.Never());

        roles[first.Id].Add("Admin");
        config["Authentication:GooglePlayReview:DriverPassword"] = "Privileged.Mutation!999";
        config["Authentication:GooglePlayReview:MerchantPassword"] = "Privileged.Mutation!999";
        await Assert.ThrowsAsync<CustomerOtpException>(() => service.EnsureReviewAccountAsync(phone));
        Assert.Equal(currentHash, second.PasswordHash);
    }

    [Fact]
    public async Task OperationsReviewerRequiresPasswordConfigurationBeforeCreation()
    {
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options, new HttpContextAccessor());
        var users = new Mock<UserManager<AppUser>>(Mock.Of<IUserStore<AppUser>>(), null!, null!, null!, null!, null!, null!, null!, null!);
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            { ["Authentication:GooglePlayReview:Enabled"] = "true" }).Build();
        var service = new CustomerOtpService(new AppUnitOfWork(db), users.Object, null!, config, null!);
        await Assert.ThrowsAsync<CustomerOtpException>(() => service.EnsureReviewAccountAsync(GooglePlayReviewIdentity.DriverPhone));
        await Assert.ThrowsAsync<CustomerOtpException>(() => service.EnsureReviewAccountAsync(GooglePlayReviewIdentity.MerchantPhone));
        Assert.Empty(await db.Users.ToListAsync());
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
