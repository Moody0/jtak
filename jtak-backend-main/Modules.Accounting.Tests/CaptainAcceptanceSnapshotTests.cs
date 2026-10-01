using System;
using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services.Pricing;
using Modules.Orders.Entities;
using PaymentMethod = Modules.Orders.Entities.PaymentMethod;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class CaptainAcceptanceSnapshotTests
    {
        [Fact]
        public void ApplyCaptainAcceptanceSnapshot_SalariedEmployee_HasZeroEarning_AndFullPlatformDeliveryFee()
        {
            var money = new CanonicalOrderMoneyDto
            {
                Version = 3,
                ProductSubtotal = 2500m,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                GrandTotal = 2680m,
                CashToCollect = 2680m
            };

            var order = new Order
            {
                Id = 101,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                MoneySnapshotJson = OrderMoneySnapshot.Serialize(money),
                PaymentMethod = PaymentMethod.PayOnDelivery
            };

            var courier = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Salaried Captain",
                CaptainCompensationType = CaptainCompensationType.SalariedEmployee,
                CaptainRate = 0m
            };

            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, courier);

            Assert.Equal(CaptainCompensationType.SalariedEmployee, order.CaptainCompensationType);
            Assert.Equal(0m, order.CaptainRate);
            Assert.Equal(0m, order.CaptainEarning);
            Assert.Equal(4m, order.DistanceInKm);
            Assert.Equal(180m, order.OriginalDeliveryFee);

            var updatedMoney = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
            Assert.NotNull(updatedMoney);
            Assert.Equal(0m, updatedMoney.CaptainEarning);
            Assert.Equal(180m, updatedMoney.PlatformDeliveryRevenue);
            Assert.Equal(0m, updatedMoney.DriverEarningSubsidy);
        }

        [Fact]
        public void ApplyCaptainAcceptanceSnapshot_PerKilometer_CalculatesDistanceMultipliedByRate()
        {
            // Example from requirements:
            // Products: 2500, Distance: 4 km, Customer delivery: 180 (45/km). Total customer: 2680.
            // Captain on km rate 25/km -> Captain earning = 100 (4 * 25).
            var money = new CanonicalOrderMoneyDto
            {
                Version = 3,
                ProductSubtotal = 2500m,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                GrandTotal = 2680m,
                CashToCollect = 2680m
            };

            var order = new Order
            {
                Id = 102,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                MoneySnapshotJson = OrderMoneySnapshot.Serialize(money),
                PaymentMethod = PaymentMethod.PayOnDelivery
            };

            var courier = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Km Captain",
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m
            };

            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, courier);

            Assert.Equal(CaptainCompensationType.PerKilometer, order.CaptainCompensationType);
            Assert.Equal(25m, order.CaptainRate);
            Assert.Equal(100m, order.CaptainEarning);
            Assert.Equal(4m, order.DistanceInKm);

            var updatedMoney = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
            Assert.NotNull(updatedMoney);
            Assert.Equal(100m, updatedMoney.CaptainEarning);
            Assert.Equal(80m, updatedMoney.PlatformDeliveryRevenue); // 180 - 100 = 80
            Assert.Equal(0m, updatedMoney.DriverEarningSubsidy);
        }

        [Fact]
        public void ApplyCaptainAcceptanceSnapshot_Percentage_CalculatesPercentageOfOriginalDeliveryFee()
        {
            // Example from requirements:
            // Customer delivery: 180.
            // Captain on 60% rate -> Captain earning = 108 (180 * 60%).
            var money = new CanonicalOrderMoneyDto
            {
                Version = 3,
                ProductSubtotal = 2500m,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                GrandTotal = 2680m,
                CashToCollect = 2680m
            };

            var order = new Order
            {
                Id = 103,
                DeliveryFee = 180m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                MoneySnapshotJson = OrderMoneySnapshot.Serialize(money),
                PaymentMethod = PaymentMethod.PayOnDelivery
            };

            var courier = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Percentage Captain",
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m
            };

            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, courier);

            Assert.Equal(CaptainCompensationType.Percentage, order.CaptainCompensationType);
            Assert.Equal(60m, order.CaptainRate);
            Assert.Equal(108m, order.CaptainEarning);

            var updatedMoney = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
            Assert.NotNull(updatedMoney);
            Assert.Equal(108m, updatedMoney.CaptainEarning);
            Assert.Equal(72m, updatedMoney.PlatformDeliveryRevenue); // 180 - 108 = 72
            Assert.Equal(0m, updatedMoney.DriverEarningSubsidy);
        }

        [Fact]
        public void ApplyCaptainAcceptanceSnapshot_FreeDeliveryPromotion_CaptainEarningsProtected()
        {
            // Critical requirement: If customer got Free Delivery promotion (DeliveryFee = 0),
            // the captain's earning must NOT become 0. It must calculate from OriginalDeliveryFee or Distance.
            var money = new CanonicalOrderMoneyDto
            {
                Version = 3,
                ProductSubtotal = 2500m,
                DeliveryFee = 0m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                IsFreeDeliveryPromo = true,
                GrandTotal = 2500m,
                CashToCollect = 2500m
            };

            var order = new Order
            {
                Id = 104,
                DeliveryFee = 0m,
                OriginalDeliveryFee = 180m,
                DistanceInKm = 4m,
                CustomerRatePerKm = 45m,
                MoneySnapshotJson = OrderMoneySnapshot.Serialize(money),
                PaymentMethod = PaymentMethod.PayOnDelivery
            };

            // Test A: Per Kilometer Courier
            var kmCourier = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Km Courier",
                CaptainCompensationType = CaptainCompensationType.PerKilometer,
                CaptainRate = 25m
            };

            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, kmCourier);
            Assert.Equal(100m, order.CaptainEarning); // 4 km * 25 = 100

            var kmMoney = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
            Assert.Equal(100m, kmMoney.CaptainEarning);
            Assert.Equal(100m, kmMoney.DriverEarningSubsidy); // Platform funds the 100 because customer paid 0
            Assert.Equal(0m, kmMoney.PlatformDeliveryRevenue);

            // Test B: Percentage Courier on the same free delivery order
            var percentCourier = new AppUser
            {
                Id = Guid.NewGuid(),
                FullName = "Percent Courier",
                CaptainCompensationType = CaptainCompensationType.Percentage,
                CaptainRate = 60m
            };

            DriverPricingService.ApplyCaptainAcceptanceSnapshotStatic(order, percentCourier);
            Assert.Equal(108m, order.CaptainEarning); // 180 original * 60% = 108

            var percentMoney = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);
            Assert.Equal(108m, percentMoney.CaptainEarning);
            Assert.Equal(108m, percentMoney.DriverEarningSubsidy); // Platform funds the 108
            Assert.Equal(0m, percentMoney.PlatformDeliveryRevenue);
        }

        [Theory]
        [InlineData(-5, 25, 0)]
        [InlineData(4, -10, 0)]
        [InlineData(0, 50, 0)]
        public void CalculateCaptainOrderEarning_SafeWithNegativeOrZeroInputs(decimal distance, decimal rate, decimal expected)
        {
            var earning = DriverPricingService.CalculateCaptainOrderEarningStatic(
                CaptainCompensationType.PerKilometer, rate, distance, 180m);
            Assert.Equal(expected, earning);
        }
    }
}
