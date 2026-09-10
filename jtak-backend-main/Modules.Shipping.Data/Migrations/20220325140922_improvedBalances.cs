using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Accounting.Data.Migrations
{
    public partial class improvedBalances : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PendingAmount",
                table: "Accounting_Balances");

            migrationBuilder.AddColumn<string>(
                name: "Name",
                table: "Accounting_Balances",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Name",
                table: "Accounting_Balances");

            migrationBuilder.AddColumn<decimal>(
                name: "PendingAmount",
                table: "Accounting_Balances",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }
    }
}
