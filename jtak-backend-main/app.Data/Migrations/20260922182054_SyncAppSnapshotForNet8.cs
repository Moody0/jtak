using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace App.Shared.Data.Migrations
{
    /// <summary>
    /// Synchronizes the EF Core 8 model snapshot with schema changes that are
    /// already represented by the preceding hand-authored migrations.
    /// </summary>
    public partial class SyncAppSnapshotForNet8 : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Intentionally empty. The preceding migrations contain the DDL.
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Snapshot-only migration; there is no database operation to undo.
        }
    }
}
