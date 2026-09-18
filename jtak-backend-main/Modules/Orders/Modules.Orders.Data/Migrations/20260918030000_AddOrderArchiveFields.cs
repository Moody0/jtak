using System;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260918030000_AddOrderArchiveFields")]
    public partial class AddOrderArchiveFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DeletionDate",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeletedBy",
                table: "Orders_Orders",
                type: "varchar(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeleteReason",
                table: "Orders_Orders",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Orders_DeletionDate",
                table: "Orders_Orders",
                column: "DeletionDate");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Orders_Orders_DeletionDate",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeletionDate",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeletedBy",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeleteReason",
                table: "Orders_Orders");
        }
    }
}
