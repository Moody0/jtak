using Microsoft.EntityFrameworkCore.Migrations;

namespace App.Shared.Data.Migrations
{
    public partial class addedBanners : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DescriptionAr",
                table: "Banners");

            migrationBuilder.DropColumn(
                name: "DescriptionEn",
                table: "Banners");

            migrationBuilder.DropColumn(
                name: "DescriptionTr",
                table: "Banners");

            migrationBuilder.DropColumn(
                name: "TitleAr",
                table: "Banners");

            migrationBuilder.RenameColumn(
                name: "TitleTr",
                table: "Banners",
                newName: "Title");

            migrationBuilder.RenameColumn(
                name: "TitleEn",
                table: "Banners",
                newName: "Description");

            migrationBuilder.AddColumn<int>(
                name: "Order",
                table: "Banners",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Order",
                table: "Banners");

            migrationBuilder.RenameColumn(
                name: "Title",
                table: "Banners",
                newName: "TitleTr");

            migrationBuilder.RenameColumn(
                name: "Description",
                table: "Banners",
                newName: "TitleEn");

            migrationBuilder.AddColumn<string>(
                name: "DescriptionAr",
                table: "Banners",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "DescriptionEn",
                table: "Banners",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "DescriptionTr",
                table: "Banners",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "TitleAr",
                table: "Banners",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }
    }
}
