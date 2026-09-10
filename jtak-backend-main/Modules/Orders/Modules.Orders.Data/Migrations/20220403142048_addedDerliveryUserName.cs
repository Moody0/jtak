using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    public partial class addedDerliveryUserName : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeliveryUser",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeliveryUser",
                table: "Orders_Orders");
        }
    }
}
