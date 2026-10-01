using System;
using System.Collections.Generic;
using System.Linq;
using Modules.Orders.Entities;

namespace App.Shared.Services.Pricing
{
    /// <summary>
    /// Canonical implementation of order pricing, fee splitting, and money calculations.
    /// All participants (customer, driver, merchant, admin, ledger) use these exact rules.
    /// </summary>
    public class OrderMoneyCalculationService : IOrderMoneyCalculationService
    {
        public CanonicalOrderMoneyDto CalculateOrderMoney(
            IEnumerable<OrderDetail> orderDetails,
            decimal deliveryFee,
            PaymentMethod paymentMethod,
            decimal promotionDiscount = 0m,
            decimal amountAlreadyPaid = 0m,
            IEnumerable<MerchantCommissionInfo> merchantCommissionInfos = null,
            decimal captainEarning = 0m,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false)
        {
            var dtos = (orderDetails ?? Enumerable.Empty<OrderDetail>())
                .Select(d => d.ToDto())
                .ToList();

            return CalculateOrderMoney(
                dtos,
                deliveryFee,
                paymentMethod,
                promotionDiscount,
                amountAlreadyPaid,
                merchantCommissionInfos,
                captainEarning,
                currency,
                commissionIsMarkup,
                commissionIsPercentageOfGross);
        }

        public CanonicalOrderMoneyDto CalculateOrderMoney(
            IEnumerable<OrderDetailDto> orderDetails,
            decimal deliveryFee,
            PaymentMethod paymentMethod,
            decimal promotionDiscount = 0m,
            decimal amountAlreadyPaid = 0m,
            IEnumerable<MerchantCommissionInfo> merchantCommissionInfos = null,
            decimal captainEarning = 0m,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false)
        {
            currency = string.IsNullOrWhiteSpace(currency) ? "SYP" : currency.ToUpperInvariant();
            var isSyp = currency == "SYP";
            var precision = isSyp ? 0 : 2;

            var activeDetails = (orderDetails ?? Enumerable.Empty<OrderDetailDto>())
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerPending)
                .ToList();

            decimal productSubtotal = 0m;
            foreach (var detail in activeDetails)
            {
                // UnitSalePrice is SingleFinalPrice if positive; fallback to SinglePrice
                decimal unitSalePrice = detail.SingleFinalPrice > 0m ? detail.SingleFinalPrice : detail.SinglePrice;
                var lineTotal = RoundCurrency(detail.Quantity * unitSalePrice, currency);
                productSubtotal += lineTotal;
            }

            var roundedDeliveryFee = RoundCurrency(deliveryFee, currency);
            var roundedPromo = RoundCurrency(promotionDiscount, currency);
            var grandTotal = Math.Max(0m, productSubtotal + roundedDeliveryFee - roundedPromo);

            var isCod = paymentMethod == PaymentMethod.PayOnDelivery;
            var roundedAlreadyPaid = RoundCurrency(amountAlreadyPaid, currency);
            var cashToCollect = isCod ? Math.Max(0m, grandTotal - roundedAlreadyPaid) : 0m;

            var roundedCaptainEarning = RoundCurrency(captainEarning, currency);
            var platformDeliveryRev = Math.Max(0m, roundedDeliveryFee - roundedCaptainEarning);
            var driverEarningSubsidy = Math.Max(0m, roundedCaptainEarning - roundedDeliveryFee);

            var commissionLookup = (merchantCommissionInfos ?? Enumerable.Empty<MerchantCommissionInfo>())
                .ToDictionary(m => m.MerchantId);

            var splits = new List<CanonicalMerchantSplitDto>();
            var merchantGroups = activeDetails.GroupBy(x => x.MerchantId);

            foreach (var mg in merchantGroups)
            {
                var mid = mg.Key;
                var merchantTitle = mg.FirstOrDefault()?.MerchantTitle ?? $"Merchant #{mid}";
                commissionLookup.TryGetValue(mid, out var info);

                decimal merchantGross = 0m;
                foreach (var d in mg)
                {
                    decimal unitPrice = d.SingleFinalPrice > 0m ? d.SingleFinalPrice : d.SinglePrice;
                    merchantGross += RoundCurrency(d.Quantity * unitPrice, currency);
                }

                bool isPlatformOwned = info?.IsDarkStore ?? false;
                decimal commRate = isPlatformOwned ? 100m : (info?.CommissionRatePercent ?? 0m);

                decimal merchantComm;
                decimal merchantPayable;

                if (isPlatformOwned)
                {
                    merchantComm = merchantGross;
                    merchantPayable = 0m;
                }
                else if (commissionIsPercentageOfGross)
                {
                    // The merchant contract is a percentage of the billed sale
                    // amount, not merely the markup over the merchant's quote.
                    merchantComm = Math.Min(merchantGross, RoundCommission(
                        merchantGross * (Math.Max(0m, commRate) / 100m)));
                    merchantPayable = merchantGross - merchantComm;
                }
                else if (commissionIsMarkup)
                {
                    merchantPayable = mg.Sum(d => RoundCurrency(d.Quantity * d.SingleMerchantProfit, currency));
                    merchantPayable = Math.Min(merchantGross, Math.Max(0m, merchantPayable));
                    merchantComm = merchantGross - merchantPayable;
                }
                else
                {
                    merchantComm = commRate > 0m
                        ? RoundCurrency(merchantGross * (commRate / 100m), currency)
                        : 0m;
                    // Exact balancing: Payable = Gross - Commission
                    merchantPayable = merchantGross - merchantComm;
                }

                splits.Add(new CanonicalMerchantSplitDto
                {
                    MerchantId = mid,
                    MerchantTitle = merchantTitle,
                    IsPlatformOwned = isPlatformOwned,
                    CommissionRate = commRate,
                    MerchantGross = merchantGross,
                    MerchantCommission = merchantComm,
                    MerchantPayable = merchantPayable,
                    AllocatedDeliveryFee = 0m,
                    CaptainEarning = 0m
                });
            }

            var totalMerchantGross = splits.Sum(s => s.MerchantGross);
            var totalMerchantComm = splits.Sum(s => s.MerchantCommission);
            var totalMerchantPayable = splits.Sum(s => s.MerchantPayable);

            return new CanonicalOrderMoneyDto
            {
                Version = commissionIsPercentageOfGross ? 3 : commissionIsMarkup ? 2 : 1,
                ProductSubtotal = productSubtotal,
                DeliveryFee = roundedDeliveryFee,
                OtherCharges = 0m,
                PromotionDiscount = roundedPromo,
                GrandTotal = grandTotal,
                CashToCollect = cashToCollect,
                AmountAlreadyPaid = roundedAlreadyPaid,
                IsCod = isCod,
                Currency = currency,
                CurrencyPrecision = commissionIsPercentageOfGross && isSyp ? 2 : precision,
                CaptainEarning = roundedCaptainEarning,
                DriverEarningSubsidy = driverEarningSubsidy,
                PlatformDeliveryRevenue = platformDeliveryRev,
                TotalMerchantGross = totalMerchantGross,
                TotalMerchantCommission = totalMerchantComm,
                TotalMerchantPayable = totalMerchantPayable,
                PlatformTotalRevenue = totalMerchantComm + platformDeliveryRev - driverEarningSubsidy,
                MerchantSplits = splits
            };
        }

        public MerchantSplitCalculation CalculateMerchantBill(
            IEnumerable<OrderDetail> merchantDetails,
            decimal commissionRatePercent,
            PaymentMethod paymentMethod,
            string currency = "SYP",
            bool commissionIsMarkup = false,
            bool commissionIsPercentageOfGross = false)
        {
            currency = string.IsNullOrWhiteSpace(currency) ? "SYP" : currency.ToUpperInvariant();

            var active = (merchantDetails ?? Enumerable.Empty<OrderDetail>())
                .Where(x => x.OrderDetailStatus != OrderDetailStatus.MerchantRejected &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.DeliveryCanceled &&
                            x.OrderDetailStatus != OrderDetailStatus.CustomerPending)
                .ToList();

            decimal gross = 0m;
            foreach (var d in active)
            {
                decimal unitPrice = d.SingleFinalPrice > 0m ? d.SingleFinalPrice : d.SinglePrice;
                gross += RoundCurrency(d.Quantity * unitPrice, currency);
            }

            bool isPlatformOwned = active.Count > 0 && active.All(d => d.IsPlatformOwnedSnapshot);
            decimal payable = isPlatformOwned
                ? 0m
                : commissionIsPercentageOfGross
                    ? gross - Math.Min(gross, RoundCommission(
                        gross * (Math.Max(0m, commissionRatePercent) / 100m)))
                    : commissionIsMarkup
                ? Math.Min(gross, Math.Max(0m, active.Sum(d => RoundCurrency(d.Quantity * d.SingleMerchantProfit, currency))))
                : gross - (commissionRatePercent > 0m
                    ? RoundCurrency(gross * (commissionRatePercent / 100m), currency)
                    : 0m);
            decimal commission = gross - payable;

            return new MerchantSplitCalculation
            {
                MerchantId = active.FirstOrDefault()?.MerchantId ?? 0,
                GrossAmount = gross,
                CommissionRate = commissionRatePercent,
                PlatformCommission = commission,
                MerchantPayable = payable
            };
        }

        public decimal RoundCurrency(decimal amount, string currency = "SYP")
        {
            if (string.Equals(currency, "SYP", StringComparison.OrdinalIgnoreCase))
            {
                // Syrian Pound cash standard: integer whole amounts
                return Math.Round(amount, 0, MidpointRounding.AwayFromZero);
            }

            // Standard decimal currencies (USD, EUR, TRY): 2 decimal places
            return Math.Round(amount, 2, MidpointRounding.AwayFromZero);
        }

        private static decimal RoundCommission(decimal amount)
        {
            // Contract percentages can produce fractional SYP amounts (e.g.
            // 10% of 2,725 = 272.50). Preserve those two accounting decimals;
            // cash-price rounding remains governed by RoundCurrency.
            return Math.Round(amount, 2, MidpointRounding.AwayFromZero);
        }
    }
}
