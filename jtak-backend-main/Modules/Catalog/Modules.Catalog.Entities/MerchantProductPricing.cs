using System;

namespace Modules.Catalog.Entities
{
    public static class MerchantProductPricing
    {
        public static (decimal MerchantPrice, decimal Price, decimal FinalPrice, decimal Discount)
            Calculate(decimal exactBaseLocal, decimal markupPercent, decimal discountPercent)
        {
            if (exactBaseLocal < 0m || markupPercent < 0m || discountPercent < 0m || discountPercent >= 100m)
                throw new ArgumentOutOfRangeException(nameof(discountPercent), "قيم التسعير غير صالحة.");
            static decimal Local(decimal value) => Math.Round(value, 0, MidpointRounding.AwayFromZero);
            var merchantPrice = Local(exactBaseLocal);
            // Keep all precision until conversion to the final local amounts.
            var gross = exactBaseLocal * (1m + markupPercent / 100m);
            var price = Local(gross);
            var finalPrice = Math.Max(merchantPrice, Local(gross * (1m - discountPercent / 100m)));
            return (merchantPrice, price, finalPrice, Math.Max(0m, price - finalPrice));
        }
    }
}
