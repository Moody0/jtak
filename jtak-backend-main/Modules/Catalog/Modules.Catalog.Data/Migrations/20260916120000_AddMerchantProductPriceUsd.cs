using App.Catalog.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    /// <summary>
    /// Adds the USD base price that dollar-quoting merchants are repriced from.
    /// Catalogs imported before this column existed stored the dollar figure
    /// directly in MerchantPrice, so the backfill moves it into PriceUsd and
    /// leaves MerchantPrice to be recalculated by the reprice routine. Only
    /// rows that still look like raw dollar amounts are touched; merchants that
    /// price in the local currency keep a null PriceUsd and are never repriced.
    /// </summary>
    [DbContext(typeof(CatalogDbContext))]
    [Migration("20260916120000_AddMerchantProductPriceUsd")]
    public class AddMerchantProductPriceUsd : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
ALTER TABLE `Catalog_MerchantProduct`
    ADD COLUMN IF NOT EXISTS `PriceUsd` DECIMAL(18, 6) NULL AFTER `OriginalPrice`;");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Dropping the column would discard the only record of what the
            // dollar-denominated prices actually are, leaving the derived local
            // prices impossible to recompute. Older code ignores the column.
        }
    }
}
