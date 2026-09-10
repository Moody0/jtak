using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class addedMoreOrderDetails : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "SingleAdditionalProfit",
                table: "Orders_OrderDetails",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "SingleMerchantProfit",
                table: "Orders_OrderDetails",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SingleAdditionalProfit",
                table: "Orders_OrderDetails");

            migrationBuilder.DropColumn(
                name: "SingleMerchantProfit",
                table: "Orders_OrderDetails");
        }
    }
}
