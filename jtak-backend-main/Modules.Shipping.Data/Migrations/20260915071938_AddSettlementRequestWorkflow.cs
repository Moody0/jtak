using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Accounting.Data.Migrations
{
    public partial class AddSettlementRequestWorkflow : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Accounting_SettlementRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    RequestNumber = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PartyType = table.Column<byte>(type: "tinyint unsigned", nullable: false),
                    Status = table.Column<byte>(type: "tinyint unsigned", nullable: false),
                    RequestedByUserId = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    RequestedByName = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RequestedByPhone = table.Column<string>(type: "varchar(40)", maxLength: 40, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "varchar(8)", maxLength: 8, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Method = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AccountDetails = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Notes = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RejectionReason = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ReviewedByAdminId = table.Column<Guid>(type: "char(36)", nullable: true, collation: "ascii_general_ci"),
                    ReviewedAt = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    CompletedByAdminId = table.Column<Guid>(type: "char(36)", nullable: true, collation: "ascii_general_ci"),
                    CompletedAt = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    LedgerTransactionId = table.Column<Guid>(type: "char(36)", nullable: true, collation: "ascii_general_ci"),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedBy = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Accounting_SettlementRequests", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Accounting_SettlementRequestMerchantAllocations",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    SettlementRequestId = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    MerchantId = table.Column<int>(type: "int", nullable: false),
                    MerchantTitle = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Accounting_SettlementRequestMerchantAllocations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Accounting_SettlementRequestMerchantAllocations_Accounting_S~",
                        column: x => x.SettlementRequestId,
                        principalTable: "Accounting_SettlementRequests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_SettlementRequestMerchantAllocations_MerchantId_S~",
                table: "Accounting_SettlementRequestMerchantAllocations",
                columns: new[] { "MerchantId", "SettlementRequestId" });

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_SettlementRequestMerchantAllocations_SettlementRe~",
                table: "Accounting_SettlementRequestMerchantAllocations",
                column: "SettlementRequestId");

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_SettlementRequests_PartyType_Status_CreatedDate",
                table: "Accounting_SettlementRequests",
                columns: new[] { "PartyType", "Status", "CreatedDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_SettlementRequests_RequestedByUserId_Status",
                table: "Accounting_SettlementRequests",
                columns: new[] { "RequestedByUserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Accounting_SettlementRequests_RequestNumber",
                table: "Accounting_SettlementRequests",
                column: "RequestNumber",
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Accounting_SettlementRequestMerchantAllocations");

            migrationBuilder.DropTable(
                name: "Accounting_SettlementRequests");
        }
    }
}
