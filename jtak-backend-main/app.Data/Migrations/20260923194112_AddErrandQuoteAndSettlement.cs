using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddErrandQuoteAndSettlement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ErrandApprovedAt",
                table: "SupportMessages",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandCashCollected",
                table: "SupportMessages",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ErrandDeliveredAt",
                table: "SupportMessages",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandDeliveryFee",
                table: "SupportMessages",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ErrandDeliveryCode",
                table: "SupportMessages",
                type: "varchar(6)",
                maxLength: 6,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ErrandDriverUserId",
                table: "SupportMessages",
                type: "varchar(36)",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandItemPrice",
                table: "SupportMessages",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandPurchaseCost",
                table: "SupportMessages",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ErrandPurchasedAt",
                table: "SupportMessages",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ErrandQuoteExpiresAt",
                table: "SupportMessages",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ErrandQuoteKey",
                table: "SupportMessages",
                type: "varchar(36)",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ErrandReceiptReference",
                table: "SupportMessages",
                type: "varchar(200)",
                maxLength: 200,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ErrandRequestKey",
                table: "SupportMessages",
                type: "varchar(36)",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandRefundAmount",
                table: "SupportMessages",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ErrandReturnReason",
                table: "SupportMessages",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "ErrandReturnedAt",
                table: "SupportMessages",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ErrandStatus",
                table: "SupportMessages",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessages_ErrandRequestKey",
                table: "SupportMessages",
                column: "ErrandRequestKey",
                unique: true);

            migrationBuilder.Sql(
                "UPDATE SupportMessages SET ErrandStatus = 0 " +
                "WHERE Title = 'طلبات - اطلب أي شيء' AND ErrandStatus IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SupportMessages_ErrandRequestKey",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandApprovedAt",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandCashCollected",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandDeliveredAt",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandDeliveryFee",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandDeliveryCode",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandDriverUserId",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandItemPrice",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandPurchaseCost",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandPurchasedAt",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandQuoteExpiresAt",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandQuoteKey",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandReceiptReference",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandRequestKey",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandRefundAmount",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandReturnReason",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandReturnedAt",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandStatus",
                table: "SupportMessages");
        }
    }
}
