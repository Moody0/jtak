using App.Shared.Data.App;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace App.Shared.Data.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20261008170000_AddCustomerOtpSendCounters")]
    public partial class AddCustomerOtpSendCounters : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql(@"
            CREATE TABLE IF NOT EXISTS `CustomerOtpSendCounters` (
                `Bucket` varchar(128) NOT NULL,
                `WindowStart` datetime(6) NOT NULL,
                `SendCount` int NOT NULL,
                PRIMARY KEY (`Bucket`, `WindowStart`)
            ) ENGINE=InnoDB CHARACTER SET utf8mb4;");
        protected override void Down(MigrationBuilder migrationBuilder) =>
            migrationBuilder.DropTable("CustomerOtpSendCounters");
    }
}
