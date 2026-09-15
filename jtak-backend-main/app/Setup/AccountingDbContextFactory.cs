using System;
using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using Modules.Accounting.Data;

namespace App.Setup
{
    public class AccountingDbContextFactory : IDesignTimeDbContextFactory<AccountingDbContext>
    {
        public AccountingDbContext CreateDbContext(string[] args)
        {
            var basePath = Directory.GetCurrentDirectory();
            if (!File.Exists(Path.Combine(basePath, "appsettings.json")))
            {
                var candidate = Path.Combine(basePath, "app");
                if (Directory.Exists(candidate)) basePath = candidate;
            }

            var configuration = new ConfigurationBuilder()
                .SetBasePath(basePath)
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings.Development.json", optional: true)
                .Build();

            var connectionString = configuration.GetConnectionString("AccountingDbConnection")
                ?? "Server=localhost;Database=jtak_accounting;Uid=root;Pwd=;";

            var optionsBuilder = new DbContextOptionsBuilder<AccountingDbContext>();
            var serverVersion = new MySqlServerVersion(new Version(8, 0, 21));
            optionsBuilder.UseMySql(connectionString, serverVersion);

            return new AccountingDbContext(optionsBuilder.Options, null);
        }
    }
}
