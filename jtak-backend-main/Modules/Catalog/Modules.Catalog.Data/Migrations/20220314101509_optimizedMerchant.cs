using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class optimizedMerchant : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Facebook",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "IBAN2",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "IBAN2Title",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Instagram",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "MinOrder",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Paypal",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "ShippingCost",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Twitter",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Website",
                table: "Catalog_Merchant");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Facebook",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "IBAN2",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "IBAN2Title",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Instagram",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<decimal>(
                name: "MinOrder",
                table: "Catalog_Merchant",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Paypal",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<decimal>(
                name: "ShippingCost",
                table: "Catalog_Merchant",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Twitter",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Website",
                table: "Catalog_Merchant",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }
    }
}
