using App.Shared.Entities;
using App.Shared.Entities.Enums;
using App.Shared.Services;
using Modules.Orders.Entities;
using System;
using System.Threading.Tasks;

namespace App.Shared.Services.Pricing
{
    public class DriverPricingService : IDriverPricingService
    {
        private readonly IGenericSettingService _genericSetting;

        public DriverPricingService(IGenericSettingService genericSetting)
        {
            _genericSetting = genericSetting;
        }

        public async Task<DriverPricingSetting> GetSettingAsync()
        {
            var setting = await _genericSetting.GetValue<DriverPricingSetting>(DriverPricingSetting.Key);
            return setting != null && setting.IsValid ? setting : new DriverPricingSetting();
        }

        public async Task<bool> SaveSettingAsync(DriverPricingSetting setting)
        {
            if (setting == null || !setting.IsValid) return false;
            await _genericSetting.SetValue(DriverPricingSetting.Key, setting);
            return true;
        }

        public async Task<decimal> CalculateCaptainEarningAsync(decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m)
        {
            var setting = await GetSettingAsync();
            return CalculateCaptainEarning(setting, customerLat, customerLng, merchantLat, merchantLng, defaultFee);
        }

        public decimal CalculateCaptainEarning(DriverPricingSetting setting, decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m)
        {
            if (setting == null || !setting.IsValid)
                return defaultFee;

            // Option 1: Fixed amount per order. Invalid zero-value settings are
            // rejected and fall back to the customer fee if passed directly.
            if (setting.Mode == DriverPricingMode.Fixed)
            {
                return setting.FixedAmount;
            }

            // Option 2: Pay per distance (km or mile). Missing coordinates use
            // the configured base amount, then pass through the same min/max rules.
            decimal earning;
            if ((customerLat == 0m && customerLng == 0m) || (merchantLat == 0m && merchantLng == 0m))
            {
                earning = setting.DistanceBaseFee;
            }
            else
            {
                double meters = GeoLocationHelper.CalculateDistanceInMeters(merchantLat, merchantLng, customerLat, customerLng);
                double units = setting.Unit == DistanceUnit.Mile
                    ? (meters / 1609.344)
                    : (meters / 1000.0);
                earning = setting.DistanceBaseFee + ((decimal)units * setting.DistanceRatePerUnit);
            }

            if (setting.MinEarning > 0m)
                earning = Math.Max(setting.MinEarning, earning);

            if (setting.MaxEarning > 0m)
                earning = Math.Min(setting.MaxEarning, earning);

            return Math.Round(earning, MidpointRounding.AwayFromZero);
        }

        public CustomerDeliveryFeeQuote CalculateCustomerDeliveryFee(
            DriverPricingSetting setting,
            decimal customerLat,
            decimal customerLng,
            decimal merchantLat,
            decimal merchantLng,
            decimal fallbackFee = 0m)
        {
            setting ??= new DriverPricingSetting();

            decimal distanceKm = 0m;
            if (customerLat != 0m && customerLng != 0m && merchantLat != 0m && merchantLng != 0m)
            {
                double meters = GeoLocationHelper.CalculateDistanceInMeters(merchantLat, merchantLng, customerLat, customerLng);
                distanceKm = Math.Round((decimal)(meters / 1000.0), 2);
            }

            decimal rate = setting.CustomerRatePerKm > 0m ? setting.CustomerRatePerKm : 45m;
            decimal minFee = setting.MinDeliveryFee >= 0m ? setting.MinDeliveryFee : 50m;

            decimal calculated;
            if (distanceKm > 0m && distanceKm <= 25m)
            {
                calculated = Math.Round(distanceKm * rate, MidpointRounding.AwayFromZero);
            }
            else if (distanceKm > 25m)
            {
                // Safety guard for cross-city / cross-border coordinates (e.g. test GPS in Egypt at 620km):
                // Never calculate absurd inter-country fees like 27,000 SYP for intra-city bike delivery.
                calculated = fallbackFee > 0m
                    ? fallbackFee
                    : Math.Round(20m * rate, MidpointRounding.AwayFromZero);
            }
            else
            {
                calculated = fallbackFee;
            }

            decimal originalFee = Math.Max(minFee, calculated);
            decimal actualFee = setting.IsFreeDeliveryEnabled ? 0m : originalFee;

            return new CustomerDeliveryFeeQuote
            {
                DistanceInKm = distanceKm,
                CustomerRatePerKm = rate,
                OriginalDeliveryFee = originalFee,
                CustomerDeliveryFee = actualFee,
                IsFreeDelivery = setting.IsFreeDeliveryEnabled
            };
        }

        public decimal CalculateCaptainOrderEarning(
            CaptainCompensationType compensationType,
            decimal captainRate,
            decimal distanceInKm,
            decimal originalDeliveryFee)
        {
            return CalculateCaptainOrderEarningStatic(compensationType, captainRate, distanceInKm, originalDeliveryFee);
        }

        public static decimal CalculateCaptainOrderEarningStatic(
            CaptainCompensationType compensationType,
            decimal captainRate,
            decimal distanceInKm,
            decimal originalDeliveryFee)
        {
            decimal earning = 0m;
            switch (compensationType)
            {
                case CaptainCompensationType.SalariedEmployee:
                    earning = 0m;
                    break;

                case CaptainCompensationType.PerKilometer:
                    decimal cappedDistance = Math.Min(25m, Math.Max(0m, distanceInKm));
                    earning = Math.Round(cappedDistance * Math.Max(0m, captainRate), 0, MidpointRounding.AwayFromZero);
                    break;

                case CaptainCompensationType.Percentage:
                    earning = Math.Round(Math.Max(0m, originalDeliveryFee) * (Math.Max(0m, captainRate) / 100m), 0, MidpointRounding.AwayFromZero);
                    break;

                default:
                    earning = 0m;
                    break;
            }

            return Math.Max(0m, earning);
        }

        public void ApplyCaptainAcceptanceSnapshot(Order order, AppUser courier)
        {
            ApplyCaptainAcceptanceSnapshotStatic(order, courier);
        }

        public static void ApplyCaptainAcceptanceSnapshotStatic(Order order, AppUser courier)
        {
            if (order == null || courier == null) return;

            var money = OrderMoneySnapshot.Deserialize(order.MoneySnapshotJson);

            decimal distance = order.DistanceInKm ?? money?.DistanceInKm ?? 0m;
            decimal originalDeliveryFee = order.OriginalDeliveryFee ?? money?.OriginalDeliveryFee ?? order.DeliveryFee;
            if (originalDeliveryFee == 0m && order.DeliveryFee > 0m)
            {
                originalDeliveryFee = order.DeliveryFee;
            }

            var compType = courier.CaptainCompensationType;
            var rate = courier.CaptainRate;
            var earning = CalculateCaptainOrderEarningStatic(compType, rate, distance, originalDeliveryFee);

            order.DistanceInKm = distance;
            order.OriginalDeliveryFee = originalDeliveryFee;
            order.CaptainCompensationType = compType;
            order.CaptainRate = rate;
            order.CaptainEarning = earning;
            if (money != null)
            {
                if (!order.CustomerRatePerKm.HasValue && money.CustomerRatePerKm > 0m)
                {
                    order.CustomerRatePerKm = money.CustomerRatePerKm;
                }
                else if (order.CustomerRatePerKm.HasValue)
                {
                    money.CustomerRatePerKm = order.CustomerRatePerKm.Value;
                }
                money.DistanceInKm = distance;
                money.OriginalDeliveryFee = originalDeliveryFee;
                money.CaptainCompensationType = compType;
                money.CaptainRate = rate;
                money.CaptainEarning = earning;
                money.DriverEarningSubsidy = Math.Max(0m, earning - money.DeliveryFee);
                money.PlatformDeliveryRevenue = Math.Max(0m, money.DeliveryFee - earning);
                money.PlatformTotalRevenue = (money.TotalMerchantCommission + money.PlatformDeliveryRevenue) - money.DriverEarningSubsidy;
                order.MoneySnapshotJson = OrderMoneySnapshot.Serialize(money);
            }
            else
            {
                var fallbackMoney = new CanonicalOrderMoneyDto
                {
                    Version = 3,
                    DeliveryFee = order.DeliveryFee,
                    OriginalDeliveryFee = originalDeliveryFee,
                    DistanceInKm = distance,
                    CaptainCompensationType = compType,
                    CaptainRate = rate,
                    CaptainEarning = earning,
                    DriverEarningSubsidy = Math.Max(0m, earning - order.DeliveryFee),
                    PlatformDeliveryRevenue = Math.Max(0m, order.DeliveryFee - earning),
                    CashToCollect = order.ActualCashCollected ?? (order.PaymentMethod == Modules.Orders.Entities.PaymentMethod.PayOnDelivery ? order.DeliveryFee : 0m)
                };
                order.MoneySnapshotJson = OrderMoneySnapshot.Serialize(fallbackMoney);
            }
        }
    }
}
