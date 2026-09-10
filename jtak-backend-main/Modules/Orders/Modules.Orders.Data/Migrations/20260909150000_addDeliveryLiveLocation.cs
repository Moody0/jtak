using System;
using App.Orders.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Modules.Orders.Data.Migrations
{
    [DbContext(typeof(OrdersDbContext))]
    [Migration("20260909150000_addDeliveryLiveLocation")]
    public partial class addDeliveryLiveLocation : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(name: "DeliveryLat", table: "Orders_Orders", type: "decimal(65,30)", nullable: true);
            migrationBuilder.AddColumn<decimal>(name: "DeliveryLng", table: "Orders_Orders", type: "decimal(65,30)", nullable: true);
            migrationBuilder.AddColumn<DateTime>(name: "DeliveryLocationUpdatedAt", table: "Orders_Orders", type: "datetime(6)", nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "DeliveryLat", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "DeliveryLng", table: "Orders_Orders");
            migrationBuilder.DropColumn(name: "DeliveryLocationUpdatedAt", table: "Orders_Orders");
        }
    }
}
