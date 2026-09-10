using System;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class addedMoreMerchantStuff : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId",
                table: "Catalog_ProductCategories");

            migrationBuilder.DropForeignKey(
                name: "FK_Catalog_Products_Catalog_Merchant_MerchantId",
                table: "Catalog_Products");

            migrationBuilder.DropIndex(
                name: "IX_Catalog_Products_MerchantId",
                table: "Catalog_Products");

            migrationBuilder.DropIndex(
                name: "IX_Catalog_ProductCategories_MerchantId",
                table: "Catalog_ProductCategories");

            migrationBuilder.DropColumn(
                name: "MerchantId",
                table: "Catalog_Products");

            migrationBuilder.DropColumn(
                name: "MerchantId",
                table: "Catalog_ProductCategories");

            migrationBuilder.AddColumn<decimal>(
                name: "Lat",
                table: "Catalog_Merchant",
                type: "decimal(65,30)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Lng",
                table: "Catalog_Merchant",
                type: "decimal(65,30)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ShipingCoverageInMeters",
                table: "Catalog_Merchant",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Catalog_MerchantProduct",
                columns: table => new
                {
                    MerchantId = table.Column<int>(type: "int", nullable: false),
                    ProductId = table.Column<int>(type: "int", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Catalog_MerchantProduct", x => new { x.MerchantId, x.ProductId });
                    table.ForeignKey(
                        name: "FK_Catalog_MerchantProduct_Catalog_Merchant_MerchantId",
                        column: x => x.MerchantId,
                        principalTable: "Catalog_Merchant",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Catalog_MerchantProduct_Catalog_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Catalog_Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_MerchantProduct_ProductId",
                table: "Catalog_MerchantProduct",
                column: "ProductId");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Catalog_MerchantProduct");

            migrationBuilder.DropColumn(
                name: "Lat",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "Lng",
                table: "Catalog_Merchant");

            migrationBuilder.DropColumn(
                name: "ShipingCoverageInMeters",
                table: "Catalog_Merchant");

            migrationBuilder.AddColumn<int>(
                name: "MerchantId",
                table: "Catalog_Products",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "MerchantId",
                table: "Catalog_ProductCategories",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_Products_MerchantId",
                table: "Catalog_Products",
                column: "MerchantId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductCategories_MerchantId",
                table: "Catalog_ProductCategories",
                column: "MerchantId");

            migrationBuilder.AddForeignKey(
                name: "FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId",
                table: "Catalog_ProductCategories",
                column: "MerchantId",
                principalTable: "Catalog_Merchant",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Catalog_Products_Catalog_Merchant_MerchantId",
                table: "Catalog_Products",
                column: "MerchantId",
                principalTable: "Catalog_Merchant",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
