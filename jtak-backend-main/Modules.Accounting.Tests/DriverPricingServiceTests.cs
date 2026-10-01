using System;
using System.Threading.Tasks;
using App.Shared.Services;
using App.Shared.Services.Pricing;
using Modules.Orders.Entities;
using Moq;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class DriverPricingServiceTests
    {
        [Fact]
        public void FixedMode_Returns_FixedAmount()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Fixed,
                FixedAmount = 6500m
            };

            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 33.5138m,
                customerLng: 36.2765m,
                merchantLat: 33.5200m,
                merchantLng: 36.2900m,
                defaultFee: 3000m);

            Assert.Equal(6500m, earning);
        }

        [Fact]
        public async Task SaveSetting_RejectsInvalidMaximumWithoutPersisting()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var saved = await service.SaveSettingAsync(new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                MinEarning = 5000m,
                MaxEarning = 4000m
            });

            Assert.False(saved);
            Assert.False(await service.SaveSettingAsync(new DriverPricingSetting
            {
                Mode = DriverPricingMode.Fixed,
                FixedAmount = 0m
            }));
            genericSettingMock.Verify(
                x => x.SetValue(DriverPricingSetting.Key, It.IsAny<DriverPricingSetting>(), null),
                Times.Never);
        }

        [Fact]
        public void DistanceMode_Kilometers_Calculates_BaseFee_Plus_DistanceCost()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                Unit = DistanceUnit.Kilometer,
                DistanceBaseFee = 2000m,
                DistanceRatePerUnit = 1000m,
                MinEarning = 3000m,
                MaxEarning = 0m
            };

            // Merchant at (33.5138, 36.2765), Customer at (33.5200, 36.2900)
            // Distance is approx 1435 meters = 1.435 km
            // Expected: 2000 + 1.435 * 1000 = 3435 SYP
            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 33.5200m,
                customerLng: 36.2900m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m,
                defaultFee: 2000m);

            Assert.InRange(earning, 3400m, 3500m);
        }

        [Fact]
        public void DistanceMode_Respects_MinEarning_Floor()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                Unit = DistanceUnit.Kilometer,
                DistanceBaseFee = 1000m,
                DistanceRatePerUnit = 500m,
                MinEarning = 4000m, // High guaranteed floor
                MaxEarning = 0m
            };

            // Very short distance: customer right next to merchant (0.1 km)
            // 1000 + 0.1 * 500 = 1050, which is below MinEarning 4000
            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 33.5140m,
                customerLng: 36.2766m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m,
                defaultFee: 2000m);

            Assert.Equal(4000m, earning);
        }

        [Fact]
        public void DistanceMode_Respects_MaxEarning_Cap()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                Unit = DistanceUnit.Kilometer,
                DistanceBaseFee = 2000m,
                DistanceRatePerUnit = 2000m,
                MinEarning = 2000m,
                MaxEarning = 10000m // Cap
            };

            // Far distance (e.g. 15 km away)
            // 2000 + 15 * 2000 = 32000 -> capped at 10000
            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 33.6500m,
                customerLng: 36.4000m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m,
                defaultFee: 2000m);

            Assert.Equal(10000m, earning);
        }

        [Fact]
        public void DistanceMode_MissingCoordinates_FallsBack_To_Base_Or_Min()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                DistanceBaseFee = 2500m,
                MinEarning = 3000m
            };

            // Coordinates are 0 (e.g. text address only)
            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 0m,
                customerLng: 0m,
                merchantLat: 0m,
                merchantLng: 0m,
                defaultFee: 1500m);

            Assert.Equal(3000m, earning);
        }

        [Fact]
        public void DistanceMode_Miles_Calculates_Distance_In_Miles()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                Mode = DriverPricingMode.Distance,
                Unit = DistanceUnit.Mile,
                DistanceBaseFee = 1000m,
                DistanceRatePerUnit = 1609.344m, // Rate per mile
                MinEarning = 0m,
                MaxEarning = 0m
            };

            // Approx 1609 meters (1 mile)
            // (33.5138, 36.2765) to (33.5282, 36.2765) is approx 1 mile north (0.0144 deg lat)
            var earning = service.CalculateCaptainEarning(
                setting,
                customerLat: 33.5282m,
                customerLng: 36.2765m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m,
                defaultFee: 2000m);

            // 1000 + 1 * 1609.344 ≈ 2609
            Assert.InRange(earning, 2550m, 2650m);
        }

        [Fact]
        public void CalculateCustomerDeliveryFee_DistanceBased_CalculatesExpectedFee()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                IsFreeDeliveryEnabled = false,
                CustomerRatePerKm = 45m,
                MinDeliveryFee = 50m
            };

            // ~4 km distance:
            // 33.5138 to 33.5498 is approx 0.036 deg lat ≈ 4.0 km (4000 meters)
            var quote = service.CalculateCustomerDeliveryFee(
                setting,
                customerLat: 33.5498m,
                customerLng: 36.2765m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m);

            Assert.False(quote.IsFreeDelivery);
            Assert.Equal(45m, quote.CustomerRatePerKm);
            Assert.InRange(quote.DistanceInKm, 3.9m, 4.1m);
            // ~4.0 * 45 = 180
            Assert.InRange(quote.CustomerDeliveryFee, 175m, 185m);
            Assert.Equal(quote.CustomerDeliveryFee, quote.OriginalDeliveryFee);
        }

        [Fact]
        public void CalculateCustomerDeliveryFee_BelowMinimum_EnforcesMinDeliveryFee()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                IsFreeDeliveryEnabled = false,
                CustomerRatePerKm = 45m,
                MinDeliveryFee = 50m
            };

            // Very short distance: ~0.5 km (500 meters)
            // 0.5 * 45 = 22.5 -> below minimum 50
            var quote = service.CalculateCustomerDeliveryFee(
                setting,
                customerLat: 33.5183m,
                customerLng: 36.2765m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m);

            Assert.InRange(quote.DistanceInKm, 0.45m, 0.55m);
            Assert.Equal(50m, quote.CustomerDeliveryFee);
            Assert.Equal(50m, quote.OriginalDeliveryFee);
        }

        [Fact]
        public void CalculateCustomerDeliveryFee_FreeDeliveryEnabled_ReturnsZeroCustomerFee_PreservesOriginalFee()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                IsFreeDeliveryEnabled = true,
                CustomerRatePerKm = 45m,
                MinDeliveryFee = 50m
            };

            // ~4 km distance
            var quote = service.CalculateCustomerDeliveryFee(
                setting,
                customerLat: 33.5498m,
                customerLng: 36.2765m,
                merchantLat: 33.5138m,
                merchantLng: 36.2765m);

            Assert.True(quote.IsFreeDelivery);
            Assert.Equal(0m, quote.CustomerDeliveryFee); // Customer pays 0
            Assert.InRange(quote.OriginalDeliveryFee, 175m, 185m); // Original fee preserved for captain compensation!
        }

        [Fact]
        public void CalculateCustomerDeliveryFee_MissingCoordinates_RejectsInsteadOfUsingFlatFallback()
        {
            var genericSettingMock = new Mock<IGenericSettingService>();
            var service = new DriverPricingService(genericSettingMock.Object);

            var setting = new DriverPricingSetting
            {
                IsFreeDeliveryEnabled = false,
                CustomerRatePerKm = 45m,
                MinDeliveryFee = 50m
            };

            Assert.Throws<InvalidOperationException>(() => service.CalculateCustomerDeliveryFee(
                setting,
                customerLat: 0m,
                customerLng: 0m,
                merchantLat: 0m,
                merchantLng: 0m,
                fallbackFee: 75m));
        }

        [Fact]
        public void CustomerFee_Beyond25Km_UsesDistanceRateRatherThanFlatFallback()
        {
            var service = new DriverPricingService(null);
            var quote = service.CalculateCustomerDeliveryFee(new DriverPricingSetting(),
                34.7333m, 36.7167m, 34.4000m, 36.7167m, 100m);
            Assert.True(quote.DistanceInKm > 25m);
            Assert.Equal(Math.Round(quote.DistanceInKm * 45m, MidpointRounding.AwayFromZero), quote.CustomerDeliveryFee);
            Assert.NotEqual(100m, quote.CustomerDeliveryFee);
        }

        [Fact]
        public void CustomerFee_IdenticalPins_UsesMinimumRatherThanFlatFallback()
        {
            var quote = new DriverPricingService(null).CalculateCustomerDeliveryFee(new DriverPricingSetting(),
                34.7333m, 36.7167m, 34.7333m, 36.7167m, 100m);
            Assert.Equal(0m, quote.DistanceInKm);
            Assert.Equal(50m, quote.CustomerDeliveryFee);
        }

        [Theory]
        [InlineData(false, 100, 100)]
        [InlineData(true, 100, 0)]
        [InlineData(false, 0, 0)]
        public void VirtualMarket_UsesOwnFeeWithoutDistanceOrPhysicalStoreMinimum(bool free, decimal fee, decimal expected)
        {
            var quote = CustomerDeliveryFeeQuote.ForVirtualMarket(new DriverPricingSetting {
                CustomerRatePerKm = 500m, MinDeliveryFee = 1000m, IsFreeDeliveryEnabled = free
            }, fee);
            Assert.Equal(expected, quote.CustomerDeliveryFee);
            Assert.Equal(fee, quote.OriginalDeliveryFee);
            Assert.Equal(0m, quote.DistanceInKm);
            Assert.Equal(0m, quote.CustomerRatePerKm);
            Assert.Equal(free, quote.IsFreeDelivery);
        }
    }
}
