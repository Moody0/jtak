using App.Shared.Entities.Enums;
using Modules.Catalog.Entities;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Modules.Catalog.Services
{
    /// <summary>
    /// Resolves the single platform grocery market without relying on a database
    /// id. If more than one grocery merchant exists, the explicit JTAK Market
    /// name wins; otherwise the result is intentionally ambiguous.
    /// </summary>
    public static class JtakMarketMerchantResolver
    {
        public static Merchant Resolve(IEnumerable<Merchant> merchants)
        {
            var groceryMerchants = (merchants ?? Enumerable.Empty<Merchant>())
                .Where(x => x != null && x.Active && x.DeletionDate == null && x.MerchantKind == MerchantKind.Grocery)
                .ToArray();

            var namedMarkets = groceryMerchants.Where(IsNamedJtakMarket).ToArray();
            if (namedMarkets.Length == 1)
                return namedMarkets[0];

            if (namedMarkets.Length > 1)
                return null;

            return groceryMerchants.Length == 1 ? groceryMerchants[0] : null;
        }

        private static bool IsNamedJtakMarket(Merchant merchant)
        {
            var normalizedTitle = Normalize(merchant.Title);
            return normalizedTitle.Contains("jtakmarket", StringComparison.Ordinal) ||
                   normalizedTitle.Contains("جيتكماركت", StringComparison.Ordinal);
        }

        private static string Normalize(string value) =>
            new string((value ?? string.Empty)
                .Trim()
                .ToLowerInvariant()
                .Where(char.IsLetterOrDigit)
                .ToArray());
    }
}
