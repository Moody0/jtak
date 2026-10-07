using App.Catalog.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    [DbContext(typeof(CatalogDbContext))]
    [Migration("20261007150000_AddMerchantLogoBackgroundColor")]
    public class AddMerchantLogoBackgroundColor : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "LogoBackgroundColor",
                table: "Catalog_Merchant",
                type: "varchar(7)",
                maxLength: 7,
                nullable: true,
                defaultValue: "#FFFFFF");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "LogoBackgroundColor", table: "Catalog_Merchant");
        }
    }
}
