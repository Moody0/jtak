using App.Setup;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Modules.Accounting.Tests
{
    public class DatabaseConnectionConfigurationTests
    {
        [Fact]
        public void ReportsEveryMissingConnectionStringWithoutExposingValues()
        {
            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["ConnectionStrings:DefaultConnection"] = "configured",
                    ["ConnectionStrings:OrdersDbConnection"] = "configured"
                })
                .Build();

            var missing = DatabaseConnectionConfiguration.GetMissingConnectionNames(configuration);

            Assert.Equal(
                new[] { "CatalogDbConnection", "AccountingDbConnection", "ShippingDbConnection" },
                missing);
        }

        [Fact]
        public void ValidationNamesMissingEnvironmentVariablesButNeverValues()
        {
            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection()
                .Build();

            var exception = Assert.Throws<InvalidOperationException>(
                () => DatabaseConnectionConfiguration.ValidateRequired(configuration));

            Assert.Contains("ConnectionStrings__OrdersDbConnection", exception.Message);
            Assert.DoesNotContain("Server=", exception.Message);
        }
    }
}
