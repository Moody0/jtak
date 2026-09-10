using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Catalog.Data.Migrations
{
    public partial class addMerchantKind : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte>(
                name: "MerchantKind",
                table: "Catalog_Merchant",
                type: "tinyint unsigned",
                nullable: false,
                defaultValue: (byte)0);

            migrationBuilder.Sql(@"
                UPDATE Catalog_Merchant
                SET MerchantKind = CASE
                    WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                         REGEXP 'صيدلي|pharmacy|drugstore' THEN 2
                    WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                         REGEXP 'سوبرماركت|سوبر ماركت|بقالة|تموينات|hypermarket|grocery|market|mart' THEN 1
                    WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                         REGEXP 'متجر|مول|shop|store|mall|cosmetic|تجميل' THEN 3
                    ELSE 0
                END;");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MerchantKind",
                table: "Catalog_Merchant");
        }
    }
}
