using System;
using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    /// <summary>
    /// Creates the centralized, append-only AdminAuditLogs table and indexes.
    /// </summary>
    [DbContext(typeof(AppDbContext))]
    [Migration("20260918030100_AddAdminAuditLogs")]
    public partial class AddAdminAuditLogs : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AdminAuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "varchar(36)", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "varchar(36)", nullable: true),
                    AdminName = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AdminEmail = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Module = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Action = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    EntityType = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    EntityId = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Description = table.Column<string>(type: "varchar(2000)", maxLength: 2000, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Result = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    FailureReason = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    IpAddress = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UserAgent = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CorrelationId = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    BeforeStateJson = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AfterStateJson = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminAuditLogs", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_CreatedDate",
                table: "AdminAuditLogs",
                column: "CreatedDate");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_AdminUserId",
                table: "AdminAuditLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_Module",
                table: "AdminAuditLogs",
                column: "Module");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_Action",
                table: "AdminAuditLogs",
                column: "Action");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_Result",
                table: "AdminAuditLogs",
                column: "Result");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_EntityType_EntityId",
                table: "AdminAuditLogs",
                columns: new[] { "EntityType", "EntityId" });

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_CorrelationId",
                table: "AdminAuditLogs",
                column: "CorrelationId");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "AdminAuditLogs");
        }
    }
}
