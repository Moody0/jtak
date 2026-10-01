using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using System;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260922210000_AddOrderAccountingStatusAndProofOfDelivery")]
    public partial class AddOrderAccountingStatusAndProofOfDelivery : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "AccountingStatus",
                table: "Orders_Orders",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "AccountingPostedAt",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AccountingLastError",
                table: "Orders_Orders",
                type: "longtext",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "AccountingRetryCount",
                table: "Orders_Orders",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "DeliveryOtpFailedAttempts",
                table: "Orders_Orders",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeliveryOtpExpiresAt",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ProofPhotoUploadedBy",
                table: "Orders_Orders",
                type: "char(36)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProofPhotoUploadedAt",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ActualCashCollected",
                table: "Orders_Orders",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Orders_AccountingStatus",
                table: "Orders_Orders",
                column: "AccountingStatus");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Orders_Orders_AccountingStatus",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "AccountingStatus",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "AccountingPostedAt",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "AccountingLastError",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "AccountingRetryCount",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeliveryOtpFailedAttempts",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "DeliveryOtpExpiresAt",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ProofPhotoUploadedBy",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ProofPhotoUploadedAt",
                table: "Orders_Orders");

            migrationBuilder.DropColumn(
                name: "ActualCashCollected",
                table: "Orders_Orders");
        }
    }
}
