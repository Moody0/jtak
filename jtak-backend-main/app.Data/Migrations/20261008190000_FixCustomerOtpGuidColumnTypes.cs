using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace App.Shared.Data.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20261008190000_FixCustomerOtpGuidColumnTypes")]
    public partial class FixCustomerOtpGuidColumnTypes : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // AppDbContext maps Guid properties to varchar(36). MySqlConnector
            // materializes char(36) as Guid, which cannot satisfy EF's text read.
            // MODIFY preserves challenges and is safe after the manual SQL fix.
            migrationBuilder.Sql(@"ALTER TABLE `CustomerOtpChallenges`
                MODIFY COLUMN `ChallengeId` varchar(36) CHARACTER SET ascii NOT NULL,
                MODIFY COLUMN `UserId` varchar(36) CHARACTER SET ascii NULL;");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Keep the compatible column types when rolling back this repair.
        }
    }
}
