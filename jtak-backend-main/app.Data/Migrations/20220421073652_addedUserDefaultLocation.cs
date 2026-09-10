using Microsoft.EntityFrameworkCore.Migrations;

namespace App.Shared.Data.Migrations
{
    public partial class addedUserDefaultLocation : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DefaultLat",
                table: "AspNetUsers",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "DefaultLng",
                table: "AspNetUsers",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 0m);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DefaultLat",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "DefaultLng",
                table: "AspNetUsers");
        }
    }
}
