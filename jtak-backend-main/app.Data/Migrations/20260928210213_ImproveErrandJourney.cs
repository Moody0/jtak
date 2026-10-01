using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    /// <inheritdoc />
    public partial class ImproveErrandJourney : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ErrandDeliveryCodeFailedAttempts",
                table: "SupportMessages",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "ErrandItemsJson",
                table: "SupportMessages",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandPickupLatitude",
                table: "SupportMessages",
                type: "decimal(10,7)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ErrandPickupLongitude",
                table: "SupportMessages",
                type: "decimal(10,7)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ErrandPickupPlace",
                table: "SupportMessages",
                type: "varchar(250)",
                maxLength: 250,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ErrandUnavailableReason",
                table: "SupportMessages",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ErrandStatusEvents",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    SupportMessageId = table.Column<int>(type: "int", nullable: false),
                    FromStatus = table.Column<int>(type: "int", nullable: true),
                    ToStatus = table.Column<int>(type: "int", nullable: false),
                    ActorUserId = table.Column<string>(type: "varchar(36)", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ActorRole = table.Column<string>(type: "varchar(32)", maxLength: 32, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Note = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ErrandStatusEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ErrandStatusEvents_SupportMessages_SupportMessageId",
                        column: x => x.SupportMessageId,
                        principalTable: "SupportMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_ErrandStatusEvents_SupportMessageId_CreatedDate",
                table: "ErrandStatusEvents",
                columns: new[] { "SupportMessageId", "CreatedDate" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ErrandStatusEvents");

            migrationBuilder.DropColumn(
                name: "ErrandDeliveryCodeFailedAttempts",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandItemsJson",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandPickupLatitude",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandPickupLongitude",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandPickupPlace",
                table: "SupportMessages");

            migrationBuilder.DropColumn(
                name: "ErrandUnavailableReason",
                table: "SupportMessages");
        }
    }
}
