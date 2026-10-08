using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace App.Shared.Data.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20261008160000_AddCustomerOtpChallenges")]
    public partial class AddCustomerOtpChallenges : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Safe after an administrator applies the supplied phpMyAdmin SQL.
            migrationBuilder.Sql(@"CREATE TABLE IF NOT EXISTS `CustomerOtpChallenges` (
                `PhoneNumber` varchar(16) NOT NULL,
                `ChallengeId` char(36) CHARACTER SET ascii NOT NULL,
                `UserId` char(36) CHARACTER SET ascii NULL,
                `CodeHash` varchar(64) NOT NULL,
                `MessageId` varchar(64) NULL,
                `CreatedAt` datetime(6) NOT NULL,
                `ExpiresAt` datetime(6) NOT NULL,
                `FailedAttempts` int NOT NULL,
                `VerifiedAt` datetime(6) NULL,
                `ConsumedAt` datetime(6) NULL,
                `IsReview` tinyint(1) NOT NULL,
                `RequiresProfileCompletion` tinyint(1) NOT NULL,
                PRIMARY KEY (`PhoneNumber`),
                KEY `IX_CustomerOtpChallenges_ExpiresAt` (`ExpiresAt`)
            ) ENGINE=InnoDB CHARACTER SET utf8mb4;");
        }
        protected override void Down(MigrationBuilder migrationBuilder) =>
            migrationBuilder.DropTable("CustomerOtpChallenges");
    }
}
