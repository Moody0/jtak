using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    public partial class AddErrandReceiptPhotoToken : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ErrandReceiptPhotoToken",
                table: "SupportMessages",
                type: "varchar(255)",
                maxLength: 255,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ErrandReceiptPhotoToken",
                table: "SupportMessages");
        }
    }
}
