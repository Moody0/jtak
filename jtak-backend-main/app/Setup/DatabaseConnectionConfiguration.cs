using System;
using System.Data.Common;
using System.Linq;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace App.Setup
{
    /// <summary>
    /// Checks database configuration before the application starts registering
    /// contexts or launching hosted jobs. Connection values must be supplied by
    /// protected production configuration/environment variables.
    /// </summary>
    public static class DatabaseConnectionConfiguration
    {
        public static bool TargetSameDatabase(DbConnection first, DbConnection second)
        {
            if (first == null || second == null) return false;
            if (ReferenceEquals(first, second)) return true;
            if (first is MySqlConnection && second is MySqlConnection)
            {
                // Opening a MySqlConnection can remove its password from ConnectionString.
                // Compare the database destination, not credentials or client/pooling options,
                // before enlisting both contexts in the same physical connection/transaction.
                var left = new MySqlConnectionStringBuilder(first.ConnectionString);
                var right = new MySqlConnectionStringBuilder(second.ConnectionString);
                if (string.IsNullOrWhiteSpace(left.Database) ||
                    !string.Equals(first.Database, second.Database, StringComparison.Ordinal) ||
                    left.ConnectionProtocol != right.ConnectionProtocol || left.Port != right.Port)
                    return false;

                var serverComparison = left.ConnectionProtocol == MySqlConnectionProtocol.UnixSocket ||
                    left.Server.Contains('/') || right.Server.Contains('/')
                    ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
                var leftServers = string.Join(",", left.Server.Split(',').Select(server => server.Trim()));
                var rightServers = string.Join(",", right.Server.Split(',').Select(server => server.Trim()));
                return string.Equals(leftServers, rightServers, serverComparison) &&
                    (left.ConnectionProtocol != MySqlConnectionProtocol.NamedPipe ||
                     string.Equals(left.PipeName, right.PipeName, StringComparison.Ordinal));
            }

            // Other providers retain their existing conservative matching behavior.
            return first.GetType() == second.GetType() &&
                string.Equals(first.ConnectionString, second.ConnectionString, StringComparison.Ordinal);
        }

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
