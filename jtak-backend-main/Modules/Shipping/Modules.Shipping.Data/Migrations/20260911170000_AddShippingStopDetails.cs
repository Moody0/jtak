using System;
using App.Shipping.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Shipping.Data.Migrations
{
    [DbContext(typeof(ShippingDbContext))]
    [Migration("20260911170000_AddShippingStopDetails")]
    public partial class AddShippingStopDetails : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte>(
                name: "StopType",
                table: "Shipping_ShippingOrders",
                type: "tinyint unsigned",
                nullable: false,
                defaultValue: (byte)0);

            migrationBuilder.AddColumn<string>(
                name: "StopTitle",
                table: "Shipping_ShippingOrders",
                type: "varchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsDarkStore",
                table: "Shipping_ShippingOrders",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "VerificationCode",
                table: "Shipping_ShippingOrders",
                type: "varchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "Shipping_ShippingOrders",
                type: "varchar(256)",
                maxLength: 256,
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "StopType",
                table: "Shipping_ShippingOrders");

            migrationBuilder.DropColumn(
                name: "StopTitle",
                table: "Shipping_ShippingOrders");

            migrationBuilder.DropColumn(
                name: "IsDarkStore",
                table: "Shipping_ShippingOrders");

            migrationBuilder.DropColumn(
                name: "VerificationCode",
                table: "Shipping_ShippingOrders");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "Shipping_ShippingOrders");
        }
    }
}
