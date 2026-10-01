using App.Shared.Entities.Enums;
using Modules.Catalog.Entities;
using Modules.Catalog.Services;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class JtakMarketMerchantResolverTests
    {
        [Fact]
        public void Resolve_PrefersExplicitJtakMarketWhenSeveralGroceriesExist()
        {
            var grocery = new Merchant
            {
                Id = 24,
                Title = "Local Grocery",
                Active = true,
                MerchantKind = MerchantKind.Grocery
            };
            var jtakMarket = new Merchant
            {
                Id = 12,
                Title = "جيتك ماركت - JTAK Market",
                Active = true,
                MerchantKind = MerchantKind.Grocery
            };

            var result = JtakMarketMerchantResolver.Resolve(new[] { grocery, jtakMarket });

            Assert.Same(jtakMarket, result);
        }

        [Fact]
        public void Resolve_UsesSoleActiveGroceryAsMarketFallback()
        {
            var market = new Merchant
            {
                Id = 12,
                Title = "سوبر ماركت مركزي",
                Active = true,
                MerchantKind = MerchantKind.Grocery
            };

            Assert.Same(market, JtakMarketMerchantResolver.Resolve(new[] { market }));
        }

        [Fact]
        public void Resolve_ReturnsNullWhenMarketIsAmbiguousOrOnlyRestaurantsExist()
        {
            var groceries = new[]
            {
                new Merchant { Id = 10, Title = "Grocery A", Active = true, MerchantKind = MerchantKind.Grocery },
                new Merchant { Id = 11, Title = "Grocery B", Active = true, MerchantKind = MerchantKind.Grocery }
            };
            var restaurant = new Merchant
            {
                Id = 20,
                Title = "Restaurant",
                Active = true,
                MerchantKind = MerchantKind.Restaurant
            };

            Assert.Null(JtakMarketMerchantResolver.Resolve(groceries));
            Assert.Null(JtakMarketMerchantResolver.Resolve(new[] { restaurant }));
        }
    }
}
