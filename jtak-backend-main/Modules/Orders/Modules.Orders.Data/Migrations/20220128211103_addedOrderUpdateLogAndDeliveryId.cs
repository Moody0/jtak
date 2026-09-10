using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class addedOrderUpdateLogAndDeliveryId : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "OrderDetailId",
                table: "Orders_OrderStatusChangeLogs");

            migrationBuilder.AlterColumn<Guid>(
                name: "Id",
                table: "Orders_OrderStatusChangeLogs",
                type: "char(36)",
                nullable: false,
                collation: "ascii_general_ci",
                oldClrType: typeof(int),
                oldType: "int")
                .OldAnnotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn);

            migrationBuilder.AddColumn<Guid>(
                name: "DriverId",
                table: "Orders_OrderStatusChangeLogs",
                type: "char(36)",
                nullable: true,
                collation: "ascii_general_ci");

            migrationBuilder.AddColumn<string>(
                name: "OrdreDetails",
                table: "Orders_OrderStatusChangeLogs",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<Guid>(
                name: "DeliveryId",
                table: "Orders_Orders",
                type: "char(36)",
                nullable: true,
                collation: "ascii_general_ci");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_OrderStatusChangeLogs_OrderId",
                table: "Orders_OrderStatusChangeLogs",
                column: "OrderId");

            migrationBuilder.AddForeignKey(
                name: "FK_Orders_OrderStatusChangeLogs_Orders_Orders_OrderId",
                table: "Orders_OrderStatusChangeLogs",
                column: "OrderId",
                principalTable: "Orders_Orders",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Orders_OrderStatusChangeLogs_Orders_Orders_OrderId",
                table: "Orders_OrderStatusChangeLogs");

            migrationBuilder.DropIndex(
                name: "IX_Orders_OrderStatusChangeLogs_OrderId",
                table: "Orders_OrderStatusChangeLogs");

            migrationBuilder.DropColumn(
                name: "DriverId",
                table: "Orders_OrderStatusChangeLogs");

            migrationBuilder.DropColumn(
                name: "OrdreDetails",
                table: "Orders_OrderStatusChangeLogs");

            migrationBuilder.DropColumn(
                name: "DeliveryId",
                table: "Orders_Orders");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Orders_OrderStatusChangeLogs",
                type: "int",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "char(36)")
                .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn)
                .OldAnnotation("Relational:Collation", "ascii_general_ci");

            migrationBuilder.AddColumn<int>(
                name: "OrderDetailId",
                table: "Orders_OrderStatusChangeLogs",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }
    }
}
