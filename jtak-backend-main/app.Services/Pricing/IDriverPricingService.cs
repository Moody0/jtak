using App.Shared.Entities;
using App.Shared.Entities.Enums;
using Modules.Orders.Entities;
using System.Threading.Tasks;

namespace App.Shared.Services.Pricing
{
    public interface IDriverPricingService
    {
        Task<DriverPricingSetting> GetSettingAsync();
        Task<bool> SaveSettingAsync(DriverPricingSetting setting);
        Task<JtakMarketCourierPaySetting> GetJtakMarketCourierPayAsync();
        Task<bool> SaveJtakMarketCourierPayAsync(JtakMarketCourierPaySetting setting);
        Task<decimal> CalculateCaptainEarningAsync(decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m);
        decimal CalculateCaptainEarning(DriverPricingSetting setting, decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m);
        CustomerDeliveryFeeQuote CalculateCustomerDeliveryFee(DriverPricingSetting setting, decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal fallbackFee = 0m);
        decimal CalculateCaptainOrderEarning(CaptainCompensationType compensationType, decimal captainRate, decimal distanceInKm, decimal originalDeliveryFee);
        void ApplyCaptainAcceptanceSnapshot(Order order, AppUser courier);
    }

    public class CustomerDeliveryFeeQuote
    {
        // A virtual market has an explicit charge and no invented distance.
        public static CustomerDeliveryFeeQuote ForVirtualMarket(DriverPricingSetting setting, decimal fee)
        {
            if (fee < 0m)
                throw new System.InvalidOperationException("أجرة توصيل جيتك ماركت غير صالحة. تواصل مع الإدارة.");
            return new CustomerDeliveryFeeQuote {
                OriginalDeliveryFee = fee,
                IsVirtualMarket = true,
                CustomerDeliveryFee = setting?.IsFreeDeliveryEnabled == true ? 0m : fee,
                IsFreeDelivery = setting?.IsFreeDeliveryEnabled == true
            };
        }

        public decimal DistanceInKm { get; set; }
        public decimal CustomerRatePerKm { get; set; }
        public decimal OriginalDeliveryFee { get; set; }
        public decimal CustomerDeliveryFee { get; set; }
        public bool IsFreeDelivery { get; set; }
        public bool IsVirtualMarket { get; set; }
    }
}
