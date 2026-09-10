using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class removedRedundantPriceing : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TotalDiscount",
                table: "Orders_OrderDetails");

            migrationBuilder.DropColumn(
                name: "TotalPrice",
                table: "Orders_OrderDetails");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "TotalDiscount",
                table: "Orders_OrderDetails",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "TotalPrice",
                table: "Orders_OrderDetails",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }
    }
}
