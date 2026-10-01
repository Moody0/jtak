using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddActionNotificationDispatch : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AudienceApp",
                table: "Notifications",
                type: "varchar(16)",
                maxLength: 16,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "DispatchKey",
                table: "Notifications",
                type: "varchar(64)",
                maxLength: 64,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "PushAttemptCount",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "PushLockId",
                table: "Notifications",
                type: "varchar(36)",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "PushLockedUntilUtc",
                table: "Notifications",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PushNextAttemptAtUtc",
                table: "Notifications",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PushSentAtUtc",
                table: "Notifications",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_DispatchKey",
                table: "Notifications",
                column: "DispatchKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_PushSentAtUtc_PushNextAttemptAtUtc_PushLockedU~",
                table: "Notifications",
                columns: new[] { "PushSentAtUtc", "PushNextAttemptAtUtc", "PushLockedUntilUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Notifications_DispatchKey",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_PushSentAtUtc_PushNextAttemptAtUtc_PushLockedU~",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "AudienceApp",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "DispatchKey",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "PushAttemptCount",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "PushLockId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "PushLockedUntilUtc",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "PushNextAttemptAtUtc",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "PushSentAtUtc",
                table: "Notifications");
        }
    }
}
