using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class improvedOrderAndOrderDetails : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Product",
                table: "Orders_OrderDetails",
                newName: "ProductTitle");

            migrationBuilder.AddColumn<decimal>(
                name: "Lat",
                table: "Orders_Orders",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Lng",
                table: "Orders_Orders",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "ProductImage",
                table: "Orders_OrderDetails",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Lat",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "Lng",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ProductImage",
                table: "Orders_OrderDetails");

            migrationBuilder.RenameColumn(
                name: "ProductTitle",
                table: "Orders_OrderDetails",
                newName: "Product");
        }
    }
}
