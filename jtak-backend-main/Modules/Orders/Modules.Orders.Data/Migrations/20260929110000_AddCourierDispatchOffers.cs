using System;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260929110000_AddCourierDispatchOffers")]
    public partial class AddCourierDispatchOffers : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CourierMatchingStartedAtUtc",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CourierMatchingDeadlineAtUtc",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CourierMatchingCompletedAtUtc",
                table: "Orders_Orders",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CourierMatchingRound",
                table: "Orders_Orders",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Orders_OrderDispatchOffers",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    OrderId = table.Column<int>(type: "int", nullable: false),
                    DriverId = table.Column<Guid>(type: "varchar(36)", nullable: false),
                    MatchingRound = table.Column<int>(type: "int", nullable: false),
                    WaveNumber = table.Column<int>(type: "int", nullable: false),
                    OfferedAtUtc = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    RespondedAtUtc = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Status = table.Column<byte>(type: "tinyint unsigned", nullable: false)
                },
                constraints: table => table.PrimaryKey("PK_Orders_OrderDispatchOffers", x => x.Id))
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_OrderDispatchOffers_DriverId_Status_ExpiresAtUtc",
                table: "Orders_OrderDispatchOffers",
                columns: new[] { "DriverId", "Status", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Orders_OrderDispatchOffers_OrderId_MatchingRound_DriverId",
                table: "Orders_OrderDispatchOffers",
                columns: new[] { "OrderId", "MatchingRound", "DriverId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_OrderDispatchOffers_OrderId_Status_ExpiresAtUtc",
                table: "Orders_OrderDispatchOffers",
                columns: new[] { "OrderId", "Status", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Orders_CourierMatch_Deadline_Completed",
                table: "Orders_Orders",
                columns: new[] { "CourierMatchingDeadlineAtUtc", "CourierMatchingCompletedAtUtc" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "Orders_OrderDispatchOffers");
            migrationBuilder.DropIndex(
                name: "IX_Orders_Orders_CourierMatch_Deadline_Completed",
                table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "CourierMatchingStartedAtUtc", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "CourierMatchingDeadlineAtUtc", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "CourierMatchingCompletedAtUtc", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "CourierMatchingRound", table: "Orders_Orders");
        }
    }
}
