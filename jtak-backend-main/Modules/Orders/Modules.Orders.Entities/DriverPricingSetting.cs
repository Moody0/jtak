using System;

namespace Modules.Orders.Entities
{
    /// <summary>
    /// Mode for calculating delivery driver compensation per order.
    /// </summary>
    public enum DriverPricingMode
    {
        /// <summary>
        /// 1. Fixed money received per order regardless of distance.
        /// </summary>
        Fixed = 0,

        /// <summary>
        /// 2. Pay per distance (base fee + rate per km/mile).
        /// </summary>
        Distance = 1
    }

    /// <summary>
    /// Distance measurement unit for driver compensation.
    /// </summary>
    public enum DistanceUnit
    {
        Kilometer = 0,
        Mile = 1
    }

    /// <summary>
    /// Configuration for delivery driver compensation (what the driver receives per order).
    /// </summary>
    public class DriverPricingSetting
    {
        public const string Key = "DriverPricingSetting";

        /// <summary>
        /// Option selected by admin: Fixed (0) or Distance (1).
        /// </summary>
        public DriverPricingMode Mode { get; set; } = DriverPricingMode.Fixed;

        /// <summary>
        /// Option 1: Fixed amount paid to driver per order (e.g. 5,000 SYP).
        /// </summary>
        public decimal FixedAmount { get; set; } = 5000m;

        /// <summary>
        /// Option 2: Base starting fare before distance (e.g. 2,000 SYP). Can be 0 for pure rate.
        /// </summary>
        public decimal DistanceBaseFee { get; set; } = 2000m;

        /// <summary>
        /// Option 2: Rate per unit distance (e.g. 1,000 SYP per km).
        /// </summary>
        public decimal DistanceRatePerUnit { get; set; } = 1000m;

        /// <summary>
        /// Distance unit: Kilometer (0) or Mile (1). Default is Kilometer.
        /// </summary>
        public DistanceUnit Unit { get; set; } = DistanceUnit.Kilometer;

        /// <summary>
        /// Minimum guaranteed driver payout for an order (e.g. 3,000 SYP).
        /// </summary>
        public decimal MinEarning { get; set; } = 3000m;

        /// <summary>
        /// Optional maximum driver payout cap (0 = unconstrained).
        /// </summary>
        public decimal MaxEarning { get; set; } = 0m;

        /// <summary>
        /// Customer Delivery Pricing Settings (Decoupled from captain compensation).
        /// </summary>
        public bool IsFreeDeliveryEnabled { get; set; } = false;

        /// <summary>
        /// Rate charged to customer per kilometer (e.g. 45 SYP / km).
        /// </summary>
        public decimal CustomerRatePerKm { get; set; } = 45m;

        /// <summary>
        /// Minimum delivery fee charged to customer regardless of distance (e.g. 50 SYP).
        /// </summary>
        public decimal MinDeliveryFee { get; set; } = 50m;

        public bool IsValid =>
            Enum.IsDefined(typeof(DriverPricingMode), Mode) &&
            Enum.IsDefined(typeof(DistanceUnit), Unit) &&
            FixedAmount >= 0m &&
            DistanceBaseFee >= 0m &&
            DistanceRatePerUnit >= 0m &&
            MinEarning >= 0m &&
            MaxEarning >= 0m &&
            CustomerRatePerKm >= 0m &&
            MinDeliveryFee >= 0m &&
            (MaxEarning == 0m || MaxEarning >= MinEarning) &&
            (Mode != DriverPricingMode.Fixed || FixedAmount > 0m) &&
            (Mode != DriverPricingMode.Distance || DistanceBaseFee > 0m || MinEarning > 0m || DistanceRatePerUnit > 0m);
    }
}
