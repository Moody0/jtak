using System.Collections.Generic;
using Modules.Orders.Entities;

namespace App.Shared.Services.Pricing
{
    public interface IOrderMoneyCalculationService
    {
        CanonicalOrderMoneyDto CalculateOrderMoney(
            IEnumerable<OrderDetail> orderDetails,
            decimal deliveryFee,
            PaymentMethod paymentMethod,
            decimal promotionDiscount = 0m,
            decimal amountAlreadyPaid = 0m,
            IEnumerable<MerchantCommissionInfo> merchantCommissionInfos = null,
            decimal captainEarning = 0m,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false,
            bool commissionUsesMerchantBase = false);

        CanonicalOrderMoneyDto CalculateOrderMoney(
            IEnumerable<OrderDetailDto> orderDetails,
            decimal deliveryFee,
            PaymentMethod paymentMethod,
            decimal promotionDiscount = 0m,
            decimal amountAlreadyPaid = 0m,
            IEnumerable<MerchantCommissionInfo> merchantCommissionInfos = null,
            decimal captainEarning = 0m,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false,
            bool commissionUsesMerchantBase = false);

        MerchantSplitCalculation CalculateMerchantBill(
            IEnumerable<OrderDetail> merchantDetails,
            decimal commissionRatePercent,
            PaymentMethod paymentMethod,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false,
            bool commissionUsesMerchantBase = false);

        decimal RoundCurrency(decimal amount, string currency = "SYP");
    }
}
