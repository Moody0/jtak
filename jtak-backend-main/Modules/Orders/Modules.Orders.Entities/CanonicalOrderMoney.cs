using System;
using System.Collections.Generic;
using System.Text.Json;
using App.Shared.Entities.Enums;

namespace Modules.Orders.Entities
{
    /// <summary>
    /// Versioned canonical money contract for JTAK orders.
    /// Eliminates disparate calculations between customer, merchant, driver, and admin views.
    /// All participants see and use these exact figures.
    /// </summary>
    public class CanonicalOrderMoneyDto
    {
        // Optional for historical/physical-store orders; immutable order policy.
        // Fields are serialized only by the snapshot options below, not by the
        // public API's default serializer. Customers do not need internal pay rules.
        public JtakMarketCourierPaySetting JtakMarketCourierPay;
        public int Version { get; set; } = 1;

        /// <summary>
        /// Total selling price of all accepted items: Sum(Quantity * UnitSalePrice).
        /// Excludes rejected/canceled items and display-only CompareAt discounts.
        /// </summary>
        public decimal ProductSubtotal { get; set; }

        /// <summary>
        /// Delivery fee charged to the customer.
        /// </summary>
        public decimal DeliveryFee { get; set; }

        /// <summary>
        /// Original calculated delivery fee before free delivery promotions or discounts.
        /// </summary>
        public decimal OriginalDeliveryFee { get; set; }

        /// <summary>
        /// Straight-line distance in kilometers between a physical store and customer.
        /// Virtual-market orders have no pickup distance.
        /// </summary>
        public decimal DistanceInKm { get; set; }

        /// <summary>
        /// Customer delivery rate per kilometer at checkout.
        /// </summary>
        public decimal CustomerRatePerKm { get; set; }

        /// <summary>
        /// Indicates if free delivery promotion was active for customer.
        /// </summary>
        public bool IsFreeDeliveryPromo { get; set; }

        /// <summary>
        /// Other surcharges (if any).
        /// </summary>
        public decimal OtherCharges { get; set; }

        /// <summary>
        /// Real monetary reduction applied via coupon/promotion.
        /// </summary>
        public decimal PromotionDiscount { get; set; }

        /// <summary>
        /// Total amount owed by customer: ProductSubtotal + DeliveryFee + OtherCharges - PromotionDiscount.
        /// </summary>
        public decimal GrandTotal { get; set; }

        /// <summary>
        /// Exact cash amount to be collected by driver upon delivery.
        /// For COD (PayOnDelivery): GrandTotal - AmountAlreadyPaid.
        /// For electronic payment (card/transfer): 0.
        /// </summary>
        public decimal CashToCollect { get; set; }

        /// <summary>
        /// Any prepaid amount already received electronically or via wallet.
        /// </summary>
        public decimal AmountAlreadyPaid { get; set; }

        public bool IsCod { get; set; } = true;
        public string Currency { get; set; } = "SYP";
        public int CurrencyPrecision { get; set; } = 0; // Syrian Pound is whole-unit

        /// <summary>
        /// Explicit courier compensation for completing the delivery.
        /// Separate from customer delivery fee and platform revenue.
        /// </summary>
        public decimal CaptainEarning { get; set; }

        /// <summary>
        /// Courier compensation model locked upon order claim/assignment: Salaried (0), PerKm (1), Percentage (2).
        /// </summary>
        public CaptainCompensationType? CaptainCompensationType { get; set; }

        /// <summary>
        /// Courier compensation rate (price per km or percentage %) locked upon order claim/assignment.
        /// </summary>
        public decimal? CaptainRate { get; set; }

        /// <summary>
        /// Driver wage funded by the platform when the configured earning exceeds
        /// the delivery fee collected from the customer.
        /// </summary>
        public decimal DriverEarningSubsidy { get; set; }

        /// <summary>
        /// Platform revenue retained from the delivery fee: DeliveryFee - CaptainEarning.
        /// </summary>
        public decimal PlatformDeliveryRevenue { get; set; }

        /// <summary>
        /// Total merchant product gross sales.
        /// </summary>
        public decimal TotalMerchantGross { get; set; }

        /// <summary>
        /// Platform share after discounts and cash-price rounding. Version 4
        /// preserves the merchant's base quote and uses gross minus that quote.
        /// Earlier snapshot versions retain their historical policy.
        /// </summary>
        public decimal TotalMerchantCommission { get; set; }

        /// <summary>
        /// Total net payable to merchants: TotalMerchantGross - TotalMerchantCommission.
        /// </summary>
        public decimal TotalMerchantPayable { get; set; }

        /// <summary>
        /// Net platform income: commissions and retained delivery fees less driver wage subsidy.
        /// </summary>
        public decimal PlatformTotalRevenue { get; set; }

        /// <summary>
        /// Per-merchant financial split items.
        /// </summary>
        public List<CanonicalMerchantSplitDto> MerchantSplits { get; set; } = new List<CanonicalMerchantSplitDto>();
    }

    public class CanonicalMerchantSplitDto
    {
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public bool IsPlatformOwned { get; set; }
        public decimal CommissionRate { get; set; }
        public decimal MerchantGross { get; set; }
        public decimal MerchantCommission { get; set; }
        public decimal MerchantPayable { get; set; }
        public decimal AllocatedDeliveryFee { get; set; }
        public decimal CaptainEarning { get; set; }
    }

    public class MerchantCommissionInfo
    {
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public decimal CommissionRatePercent { get; set; }
        public bool IsDarkStore { get; set; }
    }

    public class MerchantSplitCalculation
    {
        public int MerchantId { get; set; }
        public decimal GrossAmount { get; set; }
        public decimal CommissionRate { get; set; }
        public decimal PlatformCommission { get; set; }
        public decimal MerchantPayable { get; set; }
    }

    public static class OrderMoneySnapshot
    {
        private static readonly JsonSerializerOptions Options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            IncludeFields = true
        };

        public static string Serialize(CanonicalOrderMoneyDto money)
        {
            if (money == null) return null;
            return JsonSerializer.Serialize(money, Options);
        }

        public static CanonicalOrderMoneyDto Deserialize(string snapshot)
        {
            if (string.IsNullOrWhiteSpace(snapshot)) return null;
            try
            {
                var dto = JsonSerializer.Deserialize<CanonicalOrderMoneyDto>(snapshot, Options);
                if (dto != null && dto.OriginalDeliveryFee == 0m && dto.DeliveryFee > 0m)
                {
                    dto.OriginalDeliveryFee = dto.DeliveryFee;
                }
                return dto;
            }
            catch (JsonException)
            {
                // Legacy/corrupt rows remain readable through the calculator fallback.
                return null;
            }
        }
    }
}
