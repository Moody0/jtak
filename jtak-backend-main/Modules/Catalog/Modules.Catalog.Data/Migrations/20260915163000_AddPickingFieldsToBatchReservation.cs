using System;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class AddPickingFieldsToBatchReservation : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsPicked",
                table: "Catalog_BatchReservations",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "PickedDate",
                table: "Catalog_BatchReservations",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PickedBy",
                table: "Catalog_BatchReservations",
                type: "varchar(128)",
                maxLength: 128,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsPicked",
                table: "Catalog_BatchReservations");

            migrationBuilder.DropColumn(
                name: "PickedDate",
                table: "Catalog_BatchReservations");

            migrationBuilder.DropColumn(
                name: "PickedBy",
                table: "Catalog_BatchReservations");
        }
    }
}
