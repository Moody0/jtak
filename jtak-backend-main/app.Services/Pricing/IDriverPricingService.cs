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
        Task<decimal> CalculateCaptainEarningAsync(decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m);
        decimal CalculateCaptainEarning(DriverPricingSetting setting, decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal defaultFee = 0m);
        CustomerDeliveryFeeQuote CalculateCustomerDeliveryFee(DriverPricingSetting setting, decimal customerLat, decimal customerLng, decimal merchantLat, decimal merchantLng, decimal fallbackFee = 0m);
        decimal CalculateCaptainOrderEarning(CaptainCompensationType compensationType, decimal captainRate, decimal distanceInKm, decimal originalDeliveryFee);
        void ApplyCaptainAcceptanceSnapshot(Order order, AppUser courier);
    }

    public class CustomerDeliveryFeeQuote
    {
        public decimal DistanceInKm { get; set; }
        public decimal CustomerRatePerKm { get; set; }
        public decimal OriginalDeliveryFee { get; set; }
        public decimal CustomerDeliveryFee { get; set; }
        public bool IsFreeDelivery { get; set; }
    }
}
