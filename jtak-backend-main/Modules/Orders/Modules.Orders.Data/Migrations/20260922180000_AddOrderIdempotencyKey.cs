using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260922180000_AddOrderIdempotencyKey")]
    public partial class AddOrderIdempotencyKey : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "IdempotencyKey",
                table: "Orders_Orders",
                type: "varchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Orders_UserId_IdempotencyKey",
                table: "Orders_Orders",
                columns: new[] { "UserId", "IdempotencyKey" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Orders_Orders_UserId_IdempotencyKey",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "IdempotencyKey",
                table: "Orders_Orders");
        }
    }
}
