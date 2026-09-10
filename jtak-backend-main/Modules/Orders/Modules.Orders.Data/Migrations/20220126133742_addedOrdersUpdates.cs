using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class addedOrdersUpdates : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "SingleDiscount",
                table: "Orders_OrderDetails",
                newName: "SingleFinalPrice");

            migrationBuilder.AddColumn<int>(
                name: "MerchantId",
                table: "Orders_OrderDetails",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "MerchantTitle",
                table: "Orders_OrderDetails",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ProductUnit",
                table: "Orders_OrderDetails",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Orders_OrderStatusChangeLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    OrderId = table.Column<int>(type: "int", nullable: false),
                    OrderDetailId = table.Column<int>(type: "int", nullable: false),
                    OrderDetailStatus = table.Column<int>(type: "int", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Orders_OrderStatusChangeLogs", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Orders_OrderStatusChangeLogs");

            migrationBuilder.DropColumn(
                name: "MerchantId",
                table: "Orders_OrderDetails");

            migrationBuilder.DropColumn(
                name: "MerchantTitle",
                table: "Orders_OrderDetails");

            migrationBuilder.DropColumn(
                name: "ProductUnit",
                table: "Orders_OrderDetails");

            migrationBuilder.RenameColumn(
                name: "SingleFinalPrice",
                table: "Orders_OrderDetails",
                newName: "SingleDiscount");
        }
    }
}
