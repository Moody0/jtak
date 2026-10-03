using App.Catalog.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    [DbContext(typeof(CatalogDbContext))]
    [Migration("20261003130000_AddMerchantProductDiscountPercent")]
    public class AddMerchantProductDiscountPercent : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql(@"
ALTER TABLE `Catalog_MerchantProduct`
ADD COLUMN IF NOT EXISTS `DiscountPercent` decimal(5,2) NULL;");
        protected override void Down(MigrationBuilder migrationBuilder) { }
    }
}
