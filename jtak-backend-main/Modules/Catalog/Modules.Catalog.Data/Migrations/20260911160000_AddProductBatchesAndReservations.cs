using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class AddProductBatchesAndReservations : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Catalog_ProductBatches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductId = table.Column<int>(type: "int", nullable: false),
                    MerchantId = table.Column<int>(type: "int", nullable: false),
                    BatchNumber = table.Column<string>(type: "varchar(64)", maxLength: 64, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    LotNumber = table.Column<string>(type: "varchar(64)", maxLength: 64, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Barcode = table.Column<string>(type: "varchar(64)", maxLength: 64, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Sku = table.Column<string>(type: "varchar(64)", maxLength: 64, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    LocationBin = table.Column<string>(type: "varchar(128)", maxLength: 128, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ManufactureDate = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    ExpirationDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    QuantityOnHand = table.Column<int>(type: "int", nullable: false),
                    QuantityReserved = table.Column<int>(type: "int", nullable: false),
                    CostPrice = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    SellingPrice = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Status = table.Column<int>(type: "int", nullable: false),
                    Notes = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DeletionDate = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    DeletedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Catalog_ProductBatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Catalog_ProductBatches_Catalog_Merchant_MerchantId",
                        column: x => x.MerchantId,
                        principalTable: "Catalog_Merchant",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Catalog_ProductBatches_Catalog_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Catalog_Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Catalog_BatchReservations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductBatchId = table.Column<int>(type: "int", nullable: false),
                    OrderId = table.Column<int>(type: "int", nullable: false),
                    OrderDetailId = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    IsDeducted = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    DeductedDate = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    IsReleased = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    ReleasedDate = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    ReleaseReason = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
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
                    table.PrimaryKey("PK_Catalog_BatchReservations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Catalog_BatchReservations_Catalog_ProductBatches_ProductBatchId",
                        column: x => x.ProductBatchId,
                        principalTable: "Catalog_ProductBatches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductBatches_Barcode",
                table: "Catalog_ProductBatches",
                column: "Barcode");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductBatches_BatchNumber",
                table: "Catalog_ProductBatches",
                column: "BatchNumber");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductBatches_ExpirationDate",
                table: "Catalog_ProductBatches",
                column: "ExpirationDate");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductBatches_MerchantId",
                table: "Catalog_ProductBatches",
                column: "MerchantId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductBatches_ProductId",
                table: "Catalog_ProductBatches",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_BatchReservations_OrderDetailId",
                table: "Catalog_BatchReservations",
                column: "OrderDetailId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_BatchReservations_OrderId",
                table: "Catalog_BatchReservations",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_Catalog_BatchReservations_ProductBatchId",
                table: "Catalog_BatchReservations",
                column: "ProductBatchId");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Catalog_BatchReservations");

            migrationBuilder.DropTable(
                name: "Catalog_ProductBatches");
        }
    }
}
