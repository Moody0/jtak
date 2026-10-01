using System;
using System.Linq;
using Microsoft.Extensions.Configuration;

namespace App.Setup
{
    /// <summary>
    /// Checks database configuration before the application starts registering
    /// contexts or launching hosted jobs. Connection values must be supplied by
    /// protected production configuration/environment variables.
    /// </summary>
    public static class DatabaseConnectionConfiguration
    {
        private static readonly string[] RequiredConnectionNames =
        {
            "DefaultConnection",
            "CatalogDbConnection",
            "OrdersDbConnection",
            "AccountingDbConnection",
            "ShippingDbConnection"
        };

        public static string[] GetMissingConnectionNames(IConfiguration configuration)
        {
            if (configuration == null) throw new ArgumentNullException(nameof(configuration));

            return RequiredConnectionNames
                .Where(name => string.IsNullOrWhiteSpace(configuration.GetConnectionString(name)))
                .ToArray();
        }

        public static void ValidateRequired(IConfiguration configuration)
        {
            var missing = GetMissingConnectionNames(configuration);
            if (missing.Length == 0) return;

            var environmentVariableNames = missing
                .Select(name => $"ConnectionStrings__{name}");

            throw new InvalidOperationException(
                "Database configuration is incomplete. Set the following connection strings " +
                "in protected production settings or environment variables: " +
                string.Join(", ", environmentVariableNames) + ".");
        }
    }
}
