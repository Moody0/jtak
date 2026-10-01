using Modules.Orders.Entities;
using Xunit;

namespace Modules.Accounting.Tests;

public class LiveTrackingPolicyTests
{
    private static readonly DateTime Now = new(2026, 9, 30, 12, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(0, true)] [InlineData(90, true)] [InlineData(91, false)]
    [InlineData(-30, true)] [InlineData(-31, false)] [InlineData(600, false)]
    public void LocationFreshnessRejectsOldAndFutureFixes(int ageSeconds, bool expected) =>
        Assert.Equal(expected, LiveTrackingPolicy.IsFresh(Now.AddSeconds(-ageSeconds), Now));

    [Theory]
    [InlineData(0, 0, false)] [InlineData(34.7301, 36.7101, true)]
    [InlineData(91, 31, false)] [InlineData(30, 181, false)]
    [InlineData(0, 31, true)]
    public void CoordinatesAreValidated(double lat, double lng, bool expected) =>
        Assert.Equal(expected, LiveTrackingPolicy.HasCoordinates((decimal)lat, (decimal)lng));

    [Theory]
    [InlineData(true, 2000, 0, 5)] [InlineData(true, 2000, 2, 9)]
    [InlineData(false, 2000, 0, 0)] [InlineData(true, 740200, 0, 0)]
    [InlineData(true, 100000, 0, 0)] [InlineData(true, 0, 0, 0)]
    public void EtaIsUnknownWithoutFreshGpsOrForUnsupportedDistances(bool live, int metres, int stops, int expected) =>
        Assert.Equal(expected, LiveTrackingPolicy.EstimateEta(live, metres, stops));

    [Fact]
    public void IncomingGpsRejectsPoorAccuracyAndStaleCaptureWithoutBreakingOlderClients()
    {
        var fix = new DeliveryLocationUpdate { Lat = 34.7301m, Lng = 36.7101m };
        Assert.True(LiveTrackingPolicy.AcceptGpsUpdate(fix, Now));
        fix.Accuracy = 5; fix.CapturedAtUtc = Now;
        Assert.True(LiveTrackingPolicy.AcceptGpsUpdate(fix, Now));
        fix.CapturedAtUtc = Now.AddMinutes(-2);
        Assert.False(LiveTrackingPolicy.AcceptGpsUpdate(fix, Now));
        fix.CapturedAtUtc = Now; fix.Accuracy = 5000;
        Assert.False(LiveTrackingPolicy.AcceptGpsUpdate(fix, Now));
        fix.Accuracy = double.NaN;
        Assert.False(LiveTrackingPolicy.AcceptGpsUpdate(fix, Now));
    }
}
