using System;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;

namespace App.Setup
{
    public static class SeedDatabase
    {
        public static async Task EnsureSeedData(this IServiceProvider services)
        {
            await services.GetRequiredService<SeedRoles>().Seed();
            await services.GetRequiredService<SeedUsers>().Seed();

            var contentSeeder = services.GetRequiredService<SeedContent>();

            await contentSeeder.SeedSettings();
            await contentSeeder.SeedMerchants();
            await contentSeeder.SeedCategories();
            await contentSeeder.SeedProducts();
            // Merchant catalogs start empty. Product links and prices must be
            // explicitly saved for that merchant, never inferred during startup.
        }
    }
}
