using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260922230000_AddCanonicalMoneySnapshot")]
    public partial class AddCanonicalMoneySnapshot : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CaptainEarning",
                table: "Orders_Orders",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "MoneySnapshotJson",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MoneySnapshotVersion",
                table: "Orders_Orders",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<decimal>(
                name: "CommissionRatePercent",
                table: "Orders_OrderDetails",
                type: "decimal(9,4)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<bool>(
                name: "IsPlatformOwnedSnapshot",
                table: "Orders_OrderDetails",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "CaptainEarning", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "MoneySnapshotJson", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "MoneySnapshotVersion", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "CommissionRatePercent", table: "Orders_OrderDetails");
            migrationBuilder.DropColumn(name: "IsPlatformOwnedSnapshot", table: "Orders_OrderDetails");
        }
    }
}
