using App.Catalog.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    /// <summary>
    /// Keeps databases created from the original catalog migrations compatible
    /// with the current Product and MerchantProduct entities. The statements
    /// are deliberately idempotent because some installations already ran the
    /// equivalent manual SQL script.
    /// </summary>
    [DbContext(typeof(CatalogDbContext))]
    [Migration("20260915170000_AddProductCatalogCompatibilityColumns")]
    public class AddProductCatalogCompatibilityColumns : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
ALTER TABLE `Catalog_Products`
    ADD COLUMN IF NOT EXISTS `TitleEn` VARCHAR(256) NULL AFTER `Title`,
    ADD COLUMN IF NOT EXISTS `Barcode` VARCHAR(64) NULL AFTER `TitleEn`,
    ADD COLUMN IF NOT EXISTS `Brand` VARCHAR(128) NULL AFTER `Barcode`,
    ADD COLUMN IF NOT EXISTS `DescriptionEn` LONGTEXT NULL AFTER `Description`;");

            migrationBuilder.Sql(@"
ALTER TABLE `Catalog_Products`
    MODIFY COLUMN `Title` VARCHAR(256) NOT NULL,
    MODIFY COLUMN `TitleEn` VARCHAR(256) NULL;");

            migrationBuilder.Sql(@"
ALTER TABLE `Catalog_MerchantProduct`
    ADD COLUMN IF NOT EXISTS `OriginalPrice` DECIMAL(18, 4) NULL AFTER `MerchantPrice`;");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // These columns are part of the current application contract. Do
            // not drop them on rollback because older code can safely ignore
            // them while dropping would destroy imported catalog data.
        }
    }
}
