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
            await contentSeeder.SeedMerchantProducts();
        }
    }
}
