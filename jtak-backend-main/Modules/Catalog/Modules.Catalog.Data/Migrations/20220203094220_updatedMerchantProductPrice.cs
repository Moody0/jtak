using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class updatedMerchantProductPrice : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Cost",
                table: "Catalog_MerchantProduct",
                newName: "ProfitOutOfMerchantPricePercent");

            migrationBuilder.RenameColumn(
                name: "AdditionalPercent",
                table: "Catalog_MerchantProduct",
                newName: "MerchantPrice");

            migrationBuilder.AddColumn<decimal>(
                name: "AdditionalProfitPercent",
                table: "Catalog_MerchantProduct",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AdditionalProfitPercent",
                table: "Catalog_MerchantProduct");

            migrationBuilder.RenameColumn(
                name: "ProfitOutOfMerchantPricePercent",
                table: "Catalog_MerchantProduct",
                newName: "Cost");

            migrationBuilder.RenameColumn(
                name: "MerchantPrice",
                table: "Catalog_MerchantProduct",
                newName: "AdditionalPercent");
        }
    }
}
