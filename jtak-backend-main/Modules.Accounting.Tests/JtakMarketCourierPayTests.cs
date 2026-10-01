using System.Text.Json;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using App.Shared.Services.Pricing;
using Modules.Orders.Entities;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests;

public class JtakMarketCourierPayTests
{
    [Fact]
    public async Task UnconfiguredMarketDefaultsToMonthlySalaryWithoutInventingASalaryAmount()
    {
        var settings = new Mock<IGenericSettingService>();
        var service = new DriverPricingService(settings.Object);
        var policy = await service.GetJtakMarketCourierPayAsync();
        Assert.Equal(CaptainCompensationType.SalariedEmployee, policy.Mode);
        Assert.Equal(0m, policy.Rate);
        Assert.True(policy.IsValid);
    }

    [Theory]
    [InlineData(CaptainCompensationType.SalariedEmployee, 0, 0)]
    [InlineData(CaptainCompensationType.FixedPerOrder, 75, 75)]
    [InlineData(CaptainCompensationType.Percentage, 60, 60)]
    public void VirtualOrderUsesItsSnapshottedPolicyIndependentlyOfCourierProfileAndCustomerPromotion(
        CaptainCompensationType mode, decimal rate, decimal expectedEarning)
    {
        var policy = new JtakMarketCourierPaySetting {Mode = mode, Rate = rate};
        var money = new CanonicalOrderMoneyDto {
            Version = 3, DeliveryFee = 0, OriginalDeliveryFee = 100, CashToCollect = 430,
            IsFreeDeliveryPromo = true, JtakMarketCourierPay = policy
        };
        var order = new Order { DeliveryFee = 0, OriginalDeliveryFee = 100, DistanceInKm = 0,
            MoneySnapshotJson = OrderMoneySnapshot.Serialize(money) };
        // A later settings change must not retroactively change this order's policy.
        policy.Mode = CaptainCompensationType.FixedPerOrder; policy.Rate = 999;
        var courier = new AppUser {CaptainCompensationType = CaptainCompensationType.PerKilometer, CaptainRate = 45};
        DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, courier);
        Assert.Equal(mode, order.CaptainCompensationType);
        Assert.Equal(rate, order.CaptainRate);
        Assert.Equal(expectedEarning, order.CaptainEarning);
        Assert.Equal(0m, order.DeliveryFee);
        var saved = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
        Assert.Equal(mode, saved.JtakMarketCourierPay.Mode);
        Assert.Equal(expectedEarning, saved.DriverEarningSubsidy);
        Assert.Equal(0m, saved.PlatformDeliveryRevenue);
    }

    [Fact]
    public void InternalPolicySurvivesSnapshotRoundTripButIsNotPartOfThePublicMoneyContract()
    {
        var money = new CanonicalOrderMoneyDto {JtakMarketCourierPay = new() {Mode = CaptainCompensationType.FixedPerOrder, Rate = 75m}};
        Assert.DoesNotContain("JtakMarketCourierPay", JsonSerializer.Serialize(money));
        var restored = OrderMoneySnapshot.Deserialize(OrderMoneySnapshot.Serialize(money));
        Assert.Equal(75m, restored.JtakMarketCourierPay.Rate);
    }

    [Theory]
    [InlineData(CaptainCompensationType.PerKilometer, 45)]
    [InlineData(CaptainCompensationType.FixedPerOrder, 0)]
    [InlineData(CaptainCompensationType.Percentage, 101)]
    [InlineData(CaptainCompensationType.SalariedEmployee, 75)]
    public async Task InvalidOrUnmeasurablePolicyNeverPersists(CaptainCompensationType mode, decimal rate)
    {
        var settings = new Mock<IGenericSettingService>();
        Assert.False(await new DriverPricingService(settings.Object).SaveJtakMarketCourierPayAsync(new() {Mode = mode, Rate = rate}));
        settings.Verify(x => x.SetValue(JtakMarketCourierPaySetting.Key, It.IsAny<JtakMarketCourierPaySetting>(), null), Times.Never);
    }

    [Fact]
    public async Task ValidPolicyPersistsUnderItsOwnNeutralKey()
    {
        var settings = new Mock<IGenericSettingService>();
        var policy = new JtakMarketCourierPaySetting {Mode = CaptainCompensationType.FixedPerOrder, Rate = 75};
        Assert.True(await new DriverPricingService(settings.Object).SaveJtakMarketCourierPayAsync(policy));
        settings.Verify(x => x.SetValue(JtakMarketCourierPaySetting.Key, policy, null), Times.Once);
    }
}
