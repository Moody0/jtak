using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260919093000_AddDeliveryDriverCashFloatLimit")]
    public partial class AddDeliveryDriverCashFloatLimit : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Startup reconciles a matching pre-existing column and missing
            // migration history before EF reaches this operation.
            migrationBuilder.AddColumn<decimal>(
                name: "MaxCashFloat",
                table: "AspNetUsers",
                type: "decimal(65,30)",
                nullable: false,
                defaultValue: 5000m);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MaxCashFloat",
                table: "AspNetUsers");
        }
    }
}
