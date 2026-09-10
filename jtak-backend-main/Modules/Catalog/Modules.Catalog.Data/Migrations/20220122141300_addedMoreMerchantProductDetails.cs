using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class addedMoreMerchantProductDetails : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Discount",
                table: "Catalog_Products");

            migrationBuilder.DropColumn(
                name: "Price",
                table: "Catalog_Products");

            migrationBuilder.DropColumn(
                name: "SoldCount",
                table: "Catalog_Products");

            migrationBuilder.DropColumn(
                name: "TotalCount",
                table: "Catalog_Products");

            migrationBuilder.AddColumn<int>(
                name: "Order",
                table: "Catalog_ProductCategories",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "AdditionalPercent",
                table: "Catalog_MerchantProduct",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Cost",
                table: "Catalog_MerchantProduct",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Discount",
                table: "Catalog_MerchantProduct",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_Merchant_Lat",
                table: "Catalog_Merchant",
                column: "Lat");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_Merchant_Lng",
                table: "Catalog_Merchant",
                column: "Lng");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Catalog_Merchant_Lat",
                table: "Catalog_Merchant");

            migrationBuilder.DropIndex(
                name: "IX_Catalog_Merchant_Lng",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Order",
                table: "Catalog_ProductCategories");

            migrationBuilder.DropColumn(
                name: "AdditionalPercent",
                table: "Catalog_MerchantProduct");

            migrationBuilder.DropColumn(
                name: "Cost",
                table: "Catalog_MerchantProduct");

            migrationBuilder.DropColumn(
                name: "Discount",
                table: "Catalog_MerchantProduct");

            migrationBuilder.AddColumn<decimal>(
                name: "Discount",
                table: "Catalog_Products",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Price",
                table: "Catalog_Products",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "SoldCount",
                table: "Catalog_Products",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TotalCount",
                table: "Catalog_Products",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }
    }
}
