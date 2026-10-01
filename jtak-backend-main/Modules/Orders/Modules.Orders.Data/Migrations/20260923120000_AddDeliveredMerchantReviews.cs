using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260923120000_AddDeliveredMerchantReviews")]
    public partial class AddDeliveredMerchantReviews : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Orders_MerchantReviews",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    OrderId = table.Column<int>(type: "int", nullable: false),
                    MerchantId = table.Column<int>(type: "int", nullable: false),
                    ReviewerId = table.Column<System.Guid>(type: "varchar(36)", nullable: false),
                    Rate = table.Column<int>(type: "int", nullable: false),
                    TextReview = table.Column<string>(type: "varchar(2000)", maxLength: 2000, nullable: true),
                    CreatedDate = table.Column<System.DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedDate = table.Column<System.DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table => table.PrimaryKey("PK_Orders_MerchantReviews", x => x.Id));

            migrationBuilder.CreateIndex(
                name: "IX_Orders_MerchantReviews_MerchantId",
                table: "Orders_MerchantReviews",
                column: "MerchantId");
            migrationBuilder.CreateIndex(
                name: "IX_Orders_MerchantReviews_OrderId_MerchantId",
                table: "Orders_MerchantReviews",
                columns: new[] { "OrderId", "MerchantId" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "Orders_MerchantReviews");
        }
    }
}
