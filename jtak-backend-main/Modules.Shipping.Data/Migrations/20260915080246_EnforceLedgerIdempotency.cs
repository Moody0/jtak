using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Accounting.Data.Migrations
{
    public partial class EnforceLedgerIdempotency : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Accounting_JournalTransactions_IdempotencyKey",
                table: "Accounting_JournalTransactions");

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_JournalTransactions_IdempotencyKey",
                table: "Accounting_JournalTransactions",
                column: "IdempotencyKey",
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Accounting_JournalTransactions_IdempotencyKey",
                table: "Accounting_JournalTransactions");

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_JournalTransactions_IdempotencyKey",
                table: "Accounting_JournalTransactions",
                column: "IdempotencyKey");
        }
    }
}
