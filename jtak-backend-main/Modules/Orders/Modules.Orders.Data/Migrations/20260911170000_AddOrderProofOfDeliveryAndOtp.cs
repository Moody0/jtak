using System;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260911170000_AddOrderProofOfDeliveryAndOtp")]
    public partial class AddOrderProofOfDeliveryAndOtp : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeliveryOtp",
                table: "Orders_Orders",
                type: "varchar(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeliveredAt",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProofOfDeliverySignature",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProofOfDeliveryPhotoUrl",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryNotes",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeliveryOtp",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeliveredAt",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ProofOfDeliverySignature",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ProofOfDeliveryPhotoUrl",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeliveryNotes",
                table: "Orders_Orders");
        }
    }
}
