using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Accounting.Data.Migrations
{
    public partial class revertedToPendingBalances : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsAddedToDues",
                table: "Accounting_Bills",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "PendingAmount",
                table: "Accounting_Balances",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsAddedToDues",
                table: "Accounting_Bills");

            migrationBuilder.DropColumn(
                name: "PendingAmount",
                table: "Accounting_Balances");
        }
    }
}
