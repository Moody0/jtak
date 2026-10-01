using System.Text.Json;
using App.Shared.Data.App;
using App.Shared.Entities;
using App.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using Moq;
using Xunit;
using App.ApiControllers.V1.Admin;
using App.Shared.Entities.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Modules.Accounting.Tests;

public class HomsCoverageTests
{
    private static readonly DateTimeOffset Now = new(2026,10,1,12,0,0,TimeSpan.Zero);
    private static CustomerDeviceLocation Fix(decimal lat=34.7333m,decimal lng=36.7167m) =>
        new() { Latitude=lat,Longitude=lng,AccuracyMeters=10m,CapturedAt=Now };

    [Fact]
    public void EgyptGpsCannotBeReplacedWithSearchedHomsDestination() {
        var error=HomsCoverageService.Validate(new(),34.7333m,36.7167m,Fix(30.0145m,31.1759m),Now);
        Assert.Contains("موقعك الحالي خارج",error);
        Assert.Null(HomsCoverageService.Validate(new(),34.7333m,36.7167m,Fix(),Now));
    }
    [Fact]
    public void DestinationAndDeviceAreSeparateCoverageRequirements() {
        Assert.Contains("عنوان التوصيل خارج",HomsCoverageService.Validate(new(),30.0145m,31.1759m,Fix(),Now));
        Assert.Contains("حدّث التطبيق",HomsCoverageService.Validate(new(),34.7333m,36.7167m,null,Now));
    }
    [Theory]
    [InlineData(61,10,false)]
    [InlineData(-31,10,false)]
    [InlineData(0,101,false)]
    [InlineData(0,0,false)]
    [InlineData(0,10,true)]
    public void OldInaccurateOrReportedMockFixCannotPass(int age,int accuracy,bool mocked) {
        var fix=Fix();fix.CapturedAt=Now.AddSeconds(-age);fix.AccuracyMeters=accuracy;fix.IsMocked=mocked;
        Assert.NotNull(HomsCoverageService.Validate(new(),34.7333m,36.7167m,fix,Now));
    }
    [Theory]
    [InlineData(0,0)]
    [InlineData(91,36)]
    [InlineData(34,181)]
    public void InvalidDeviceCoordinatesAreRejected(int lat,int lng) =>
        Assert.NotNull(HomsCoverageService.Validate(new(),34.7333m,36.7167m,Fix(lat,lng),Now));

    [Fact]
    public void RadiusBoundaryAndLocationAccuracyAreHandledConservatively() {
        const decimal center=34.7333m, longitude=36.7167m;
        var latAt10Km=center+(decimal)(10000d/6371000d*180d/Math.PI);
        var config=new HomsCoverageSetting {RadiusKm=10m};
        Assert.Null(HomsCoverageService.Validate(config,latAt10Km-0.00001m,longitude,Fix(),Now));
        Assert.Contains("عنوان التوصيل خارج",HomsCoverageService.Validate(config,latAt10Km+0.00001m,longitude,Fix(),Now));
        Assert.Contains("دقة الموقع",HomsCoverageService.Validate(config,center,longitude,Fix(latAt10Km-0.00001m,longitude),Now));
    }

    [Fact]
    public async Task LatestDatabaseRadiusOverridesGenericCacheAcrossContexts() {
        var options=new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        using var first=new AppDbContext(options,new HttpContextAccessor());
        using var second=new AppDbContext(options,new HttpContextAccessor());
        var settings=new Mock<IGenericSettingService>(MockBehavior.Strict);
        var coverage=new HomsCoverageService(settings.Object,second);
        Assert.Equal(25m,(await coverage.GetSettingAsync()).RadiusKm);
        var row=new GenericSetting {Key=HomsCoverageSetting.Key,Value=JsonSerializer.Serialize(new HomsCoverageSetting {RadiusKm=20m})};
        first.Set<GenericSetting>().Add(row);await first.SaveChangesAsync();
        Assert.Equal(20m,(await coverage.GetSettingAsync()).RadiusKm);
        Assert.True(await coverage.ContainsDestinationAsync(34.85m,36.7167m));
        row.Value=JsonSerializer.Serialize(new HomsCoverageSetting {RadiusKm=1m});await first.SaveChangesAsync();
        Assert.Equal(1m,(await coverage.GetSettingAsync()).RadiusKm);
        Assert.False(await coverage.ContainsDestinationAsync(34.85m,36.7167m));
        row.Value=JsonSerializer.Serialize(new HomsCoverageSetting {RadiusKm=100m});await first.SaveChangesAsync();
        Assert.True(await coverage.ContainsDestinationAsync(35.05m,36.7167m));
        row.Value="{broken";await first.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(()=>coverage.GetSettingAsync());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    [InlineData(0.123)]
    public async Task InvalidRadiusCannotBeSaved(decimal radius) {
        var settings=new Mock<IGenericSettingService>(MockBehavior.Strict);
        await Assert.ThrowsAsync<InvalidOperationException>(()=>new HomsCoverageService(settings.Object).SaveAsync(radius));
        settings.VerifyNoOtherCalls();
    }
    [Fact]
    public void MissingRadiusDoesNotSilentlyResetAnExistingConfigurationToDefault() =>
        Assert.Throws<JsonException>(()=>JsonSerializer.Deserialize<HomsCoverageSetting>("{}"));
    [Fact]
    public async Task ValidSaveUsesNeutralSettingKeyAndFixedCenter() {
        var settings=new Mock<IGenericSettingService>();
        HomsCoverageSetting saved=null;
        settings.Setup(x=>x.SetValue(HomsCoverageSetting.Key,It.IsAny<HomsCoverageSetting>(),null))
            .Callback<string,HomsCoverageSetting,string>((_,value,_)=>saved=value).Returns(Task.CompletedTask);
        var result=await new HomsCoverageService(settings.Object).SaveAsync(12.5m);
        Assert.Equal(12.5m,saved.RadiusKm);Assert.Equal(34.7333m,saved.CenterLat);Assert.Equal(36.7167m,saved.CenterLng);
        Assert.NotEqual(Guid.Empty,saved.Version);Assert.Equal(saved.Version,result.Version);
    }

    [Fact]
    public async Task AdminSaveRequiresAdminPolicyAndRecordsBeforeAfterRadius() {
        var policy=Assert.Single(typeof(SettingsController).GetCustomAttributes(typeof(AuthorizeAttribute),true).Cast<AuthorizeAttribute>());
        Assert.Equal(nameof(AppPermissionKey.AdminPermission),policy.Policy);
        var settings=new Mock<IGenericSettingService>();
        settings.Setup(x=>x.GetValue<HomsCoverageSetting>(HomsCoverageSetting.Key,null)).ReturnsAsync(new HomsCoverageSetting {RadiusKm=25m});
        settings.Setup(x=>x.SetValue(HomsCoverageSetting.Key,It.IsAny<HomsCoverageSetting>(),null)).Returns(Task.CompletedTask);
        AdminAuditLogEntry entry=null;
        var audit=new Mock<IAdminAuditService>();
        audit.Setup(x=>x.LogAsync(It.IsAny<AdminAuditLogEntry>())).Callback<AdminAuditLogEntry>(x=>entry=x).Returns(Task.CompletedTask);
        var controller=new SettingsController(null,null,null,settings.Object,null,null,null,audit.Object);
        Assert.IsType<BadRequestObjectResult>(await controller.SetDeliveryCoverage(new HomsCoverageSetting {RadiusKm=0}));
        settings.Verify(x=>x.SetValue(HomsCoverageSetting.Key,It.IsAny<HomsCoverageSetting>(),null),Times.Never);
        var result=Assert.IsType<OkObjectResult>(await controller.SetDeliveryCoverage(new HomsCoverageSetting {RadiusKm=12.5m}));
        Assert.Equal(12.5m,Assert.IsType<HomsCoverageSetting>(result.Value).RadiusKm);
        Assert.Equal(25m,Assert.IsType<HomsCoverageSetting>(entry.BeforeState).RadiusKm);
        Assert.Equal(12.5m,Assert.IsType<HomsCoverageSetting>(entry.AfterState).RadiusKm);
        Assert.Equal("UpdateDeliveryCoverage",entry.Action);
    }
}
