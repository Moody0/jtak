using System;
using App.Catalog.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    [DbContext(typeof(CatalogDbContext))]
    [Migration("20260922190000_AddInventoryMovements")]
    public partial class AddInventoryMovements : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Catalog_InventoryMovements",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductBatchId = table.Column<int>(type: "int", nullable: false),
                    ProductId = table.Column<int>(type: "int", nullable: false),
                    MerchantId = table.Column<int>(type: "int", nullable: false),
                    OrderId = table.Column<int>(type: "int", nullable: true),
                    OrderDetailId = table.Column<int>(type: "int", nullable: true),
                    MovementType = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    QuantityOnHandBefore = table.Column<int>(type: "int", nullable: false),
                    QuantityOnHandAfter = table.Column<int>(type: "int", nullable: false),
                    QuantityReservedBefore = table.Column<int>(type: "int", nullable: false),
                    QuantityReservedAfter = table.Column<int>(type: "int", nullable: false),
                    BusinessKey = table.Column<string>(type: "varchar(128)", maxLength: 128, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Reason = table.Column<string>(type: "varchar(512)", maxLength: 512, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Reference = table.Column<string>(type: "varchar(128)", maxLength: 128, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Catalog_InventoryMovements", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Catalog_InventoryMovements_Catalog_ProductBatches_ProductBatchId",
                        column: x => x.ProductBatchId,
                        principalTable: "Catalog_ProductBatches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_InventoryMovements_BusinessKey",
                table: "Catalog_InventoryMovements",
                column: "BusinessKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_InventoryMovements_ProductBatchId",
                table: "Catalog_InventoryMovements",
                column: "ProductBatchId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_BatchReservations_OrderDetailId_ProductBatchId",
                table: "Catalog_BatchReservations",
                columns: new[] { "OrderDetailId", "ProductBatchId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_InventoryMovements_OrderId_OrderDetailId",
                table: "Catalog_InventoryMovements",
                columns: new[] { "OrderId", "OrderDetailId" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Catalog_BatchReservations_OrderDetailId_ProductBatchId",
                table: "Catalog_BatchReservations");

            migrationBuilder.DropTable(
                name: "Catalog_InventoryMovements");
        }
    }
}
