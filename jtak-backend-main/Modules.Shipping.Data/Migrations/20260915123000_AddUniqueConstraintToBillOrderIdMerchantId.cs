using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Accounting.Data.Migrations
{
    public partial class AddUniqueConstraintToBillOrderIdMerchantId : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Accounting_Bills_OrderId_MerchantId",
                table: "Accounting_Bills",
                columns: new[] { "OrderId", "MerchantId" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Accounting_Bills_OrderId_MerchantId",
                table: "Accounting_Bills");
        }
    }
}
