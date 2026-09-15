using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using App.Shared.Data.App;
using App.Catalog.Data;
using App.Orders.Data;
using App.Shipping.Data;

namespace App.Setup
{
    public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
            var serverVersion = new MySqlServerVersion(new Version(8, 0, 21));
            optionsBuilder.UseMySql("Server=localhost;Database=jtak_db;Uid=root;Pwd=;", serverVersion);
            return new AppDbContext(optionsBuilder.Options, null);
        }
    }

    public class CatalogDbContextFactory : IDesignTimeDbContextFactory<CatalogDbContext>
    {
        public CatalogDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<CatalogDbContext>();
            var serverVersion = new MySqlServerVersion(new Version(8, 0, 21));
            optionsBuilder.UseMySql("Server=localhost;Database=jtak_db;Uid=root;Pwd=;", serverVersion);
            return new CatalogDbContext(optionsBuilder.Options, null);
        }
    }

    public class OrdersDbContextFactory : IDesignTimeDbContextFactory<OrdersDbContext>
    {
        public OrdersDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<OrdersDbContext>();
            var serverVersion = new MySqlServerVersion(new Version(8, 0, 21));
            optionsBuilder.UseMySql("Server=localhost;Database=jtak_db;Uid=root;Pwd=;", serverVersion);
            return new OrdersDbContext(optionsBuilder.Options, null);
        }
    }

    public class ShippingDbContextFactory : IDesignTimeDbContextFactory<ShippingDbContext>
    {
        public ShippingDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<ShippingDbContext>();
            var serverVersion = new MySqlServerVersion(new Version(8, 0, 21));
            optionsBuilder.UseMySql("Server=localhost;Database=jtak_db;Uid=root;Pwd=;", serverVersion);
            return new ShippingDbContext(optionsBuilder.Options, null);
        }
    }
}
