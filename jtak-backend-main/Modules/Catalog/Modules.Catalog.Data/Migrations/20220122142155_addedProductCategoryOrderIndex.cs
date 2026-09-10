using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class addedProductCategoryOrderIndex : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Catalog_ProductCategories_Order",
                table: "Catalog_ProductCategories",
                column: "Order");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Catalog_ProductCategories_Order",
                table: "Catalog_ProductCategories");
        }
    }
}
