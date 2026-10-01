using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Catalog.Data.Migrations
{
    /// <inheritdoc />
    public partial class FixDynamicFieldValueProductForeignKey : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DynamicFieldValue_Catalog_Products_ProductId1",
                table: "DynamicFieldValue");

            migrationBuilder.DropIndex(
                name: "IX_DynamicFieldValue_ProductId1",
                table: "DynamicFieldValue");

            migrationBuilder.Sql(
                "UPDATE DynamicFieldValue SET ProductId = ProductId1 WHERE ProductId1 IS NOT NULL;");

            migrationBuilder.DropColumn(
                name: "ProductId1",
                table: "DynamicFieldValue");

            migrationBuilder.AlterColumn<int>(
                name: "ProductId",
                table: "DynamicFieldValue",
                type: "int",
                nullable: false,
                oldClrType: typeof(long),
                oldType: "bigint");

            migrationBuilder.CreateIndex(
                name: "IX_DynamicFieldValue_ProductId",
                table: "DynamicFieldValue",
                column: "ProductId");

            migrationBuilder.AddForeignKey(
                name: "FK_DynamicFieldValue_Catalog_Products_ProductId",
                table: "DynamicFieldValue",
                column: "ProductId",
                principalTable: "Catalog_Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DynamicFieldValue_Catalog_Products_ProductId",
                table: "DynamicFieldValue");

            migrationBuilder.DropIndex(
                name: "IX_DynamicFieldValue_ProductId",
                table: "DynamicFieldValue");

            migrationBuilder.AlterColumn<long>(
                name: "ProductId",
                table: "DynamicFieldValue",
                type: "bigint",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<int>(
                name: "ProductId1",
                table: "DynamicFieldValue",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_DynamicFieldValue_ProductId1",
                table: "DynamicFieldValue",
                column: "ProductId1");

            migrationBuilder.AddForeignKey(
                name: "FK_DynamicFieldValue_Catalog_Products_ProductId1",
                table: "DynamicFieldValue",
                column: "ProductId1",
                principalTable: "Catalog_Products",
                principalColumn: "Id");
        }
    }
}
