using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class fixedTypo : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "ShipingCoverageInMeters",
                table: "Catalog_Merchant",
                newName: "ShippingCoverageInMeters");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "ShippingCoverageInMeters",
                table: "Catalog_Merchant",
                newName: "ShipingCoverageInMeters");
        }
    }
}
