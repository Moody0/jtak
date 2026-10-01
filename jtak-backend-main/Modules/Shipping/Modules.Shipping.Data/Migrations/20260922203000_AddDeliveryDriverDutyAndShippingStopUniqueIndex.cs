using System;
using App.Shipping.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Shipping.Data.Migrations
{
    [DbContext(typeof(ShippingDbContext))]
    [Migration("20260922203000_AddDeliveryDriverDutyAndShippingStopUniqueIndex")]
    public partial class AddDeliveryDriverDutyAndShippingStopUniqueIndex : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // This migration can be resumed after a partial MySQL/phpMyAdmin import,
            // where DDL may have committed before EF records the migration history.
            migrationBuilder.Sql(@"
CREATE TABLE IF NOT EXISTS `Shipping_DriverDuties` (
    `DriverId` char(36) COLLATE ascii_general_ci NOT NULL,
    `IsOnline` tinyint(1) NOT NULL,
    `ShiftStartedAt` datetime(6) NULL,
    `Lat` decimal(18,9) NOT NULL,
    `Lng` decimal(18,9) NOT NULL,
    `Heading` double NULL,
    `Speed` double NULL,
    `LastLocationUpdatedAt` datetime(6) NULL,
    `CreatedDate` datetime(6) NOT NULL,
    `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
    `UpdatedDate` datetime(6) NOT NULL,
    `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
    CONSTRAINT `PK_Shipping_DriverDuties` PRIMARY KEY (`DriverId`)
) CHARACTER SET=utf8mb4;");

            // Preserve legacy duplicate route stops before removing them from the
            // active route table. Keep an unfinished stop first, then the latest row.
            migrationBuilder.Sql(@"
CREATE TABLE IF NOT EXISTS `Shipping_ShippingOrderDuplicateArchive`
LIKE `Shipping_ShippingOrders`;");
            migrationBuilder.Sql(@"
CREATE TEMPORARY TABLE `tmp_ShippingOrderStopRanks` AS
SELECT `Id`, ROW_NUMBER() OVER (
    PARTITION BY `OrderId`, `StopType`, `MerchantId`
    ORDER BY (`CompletedDate` IS NULL) DESC, `UpdatedDate` DESC, `Id` DESC
) AS `DuplicateRank`
FROM `Shipping_ShippingOrders`
WHERE `MerchantId` IS NOT NULL;");
            migrationBuilder.Sql(@"
INSERT IGNORE INTO `Shipping_ShippingOrderDuplicateArchive`
SELECT `s`.*
FROM `Shipping_ShippingOrders` AS `s`
INNER JOIN `tmp_ShippingOrderStopRanks` AS `r` ON `r`.`Id` = `s`.`Id`
WHERE `r`.`DuplicateRank` > 1;");
            migrationBuilder.Sql(@"
DELETE `s` FROM `Shipping_ShippingOrders` AS `s`
INNER JOIN `tmp_ShippingOrderStopRanks` AS `r` ON `r`.`Id` = `s`.`Id`
WHERE `r`.`DuplicateRank` > 1;");
            migrationBuilder.Sql(@"DROP TEMPORARY TABLE IF EXISTS `tmp_ShippingOrderStopRanks`;");

            migrationBuilder.CreateIndex(
                name: "IX_Shipping_ShippingOrders_OrderId_StopType_MerchantId",
                table: "Shipping_ShippingOrders",
                columns: new[] { "OrderId", "StopType", "MerchantId" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Shipping_ShippingOrders_OrderId_StopType_MerchantId",
                table: "Shipping_ShippingOrders");

            migrationBuilder.Sql(@"
INSERT IGNORE INTO `Shipping_ShippingOrders`
SELECT * FROM `Shipping_ShippingOrderDuplicateArchive`;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS `Shipping_ShippingOrderDuplicateArchive`;");
            migrationBuilder.DropTable(
                name: "Shipping_DriverDuties");
        }
    }
}
