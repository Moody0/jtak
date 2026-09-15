CREATE TABLE IF NOT EXISTS `__EFMigrationsHistory` (
    `MigrationId` varchar(150) CHARACTER SET utf8mb4 NOT NULL,
    `ProductVersion` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    CONSTRAINT `PK___EFMigrationsHistory` PRIMARY KEY (`MigrationId`)
) CHARACTER SET=utf8mb4;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    ALTER DATABASE CHARACTER SET utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_Orders` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `User` longtext CHARACTER SET utf8mb4 NULL,
        `PurchaseDate` datetime(6) NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `PaymentMethod` int NOT NULL,
        `PaymentDescription` longtext CHARACTER SET utf8mb4 NULL,
        `Notes` longtext CHARACTER SET utf8mb4 NULL,
        `Address` longtext CHARACTER SET utf8mb4 NULL,
        `Phonenumber` longtext CHARACTER SET utf8mb4 NULL,
        `OrderStatus` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_Orders` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_Settings` PRIMARY KEY (`Key`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_OrderDetails` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Quantity` int NOT NULL,
        `SinglePrice` decimal(65,30) NOT NULL,
        `SingleDiscount` decimal(65,30) NOT NULL,
        `TotalPrice` decimal(65,30) NOT NULL,
        `TotalDiscount` decimal(65,30) NOT NULL,
        `Currency` int NOT NULL,
        `OrderDetailStatus` int NOT NULL,
        `Warning` longtext CHARACTER SET utf8mb4 NULL,
        `ProductId` int NOT NULL,
        `Product` longtext CHARACTER SET utf8mb4 NULL,
        `OrderId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_OrderDetails` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Orders_OrderDetails_Orders_Orders_OrderId` FOREIGN KEY (`OrderId`) REFERENCES `Orders_Orders` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE INDEX `IX_Orders_OrderDetails_OrderId` ON `Orders_OrderDetails` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220114135533_OrdersInit', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` RENAME COLUMN `Product` TO `ProductTitle`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_Orders` ADD `Lat` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_Orders` ADD `Lng` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `ProductImage` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220123105341_improvedOrderAndOrderDetails', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` RENAME COLUMN `SingleDiscount` TO `SingleFinalPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `MerchantId` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `MerchantTitle` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `ProductUnit` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    CREATE TABLE `Orders_OrderStatusChangeLogs` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `OrderId` int NOT NULL,
        `OrderDetailId` int NOT NULL,
        `OrderDetailStatus` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_OrderStatusChangeLogs` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220126133742_addedOrdersUpdates', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` DROP COLUMN `OrderDetailId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` MODIFY COLUMN `Id` char(36) COLLATE ascii_general_ci NOT NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD `DriverId` char(36) COLLATE ascii_general_ci NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD `OrdreDetails` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryId` char(36) COLLATE ascii_general_ci NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    CREATE INDEX `IX_Orders_OrderStatusChangeLogs_OrderId` ON `Orders_OrderStatusChangeLogs` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD CONSTRAINT `FK_Orders_OrderStatusChangeLogs_Orders_Orders_OrderId` FOREIGN KEY (`OrderId`) REFERENCES `Orders_Orders` (`Id`) ON DELETE RESTRICT;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220128211103_addedOrderUpdateLogAndDeliveryId', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    ALTER TABLE `Orders_OrderDetails` DROP COLUMN `TotalDiscount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    ALTER TABLE `Orders_OrderDetails` DROP COLUMN `TotalPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203094159_removedRedundantPriceing', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `SingleAdditionalProfit` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `SingleMerchantProfit` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203114313_addedMoreOrderDetails', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220403142048_addedDerliveryUserName') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryUser` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220403142048_addedDerliveryUserName') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220403142048_addedDerliveryUserName', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLat` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLng` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLocationUpdatedAt` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260909150000_addDeliveryLiveLocation', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryOtp` varchar(16) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveredAt` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `ProofOfDeliverySignature` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `ProofOfDeliveryPhotoUrl` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryNotes` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911170000_AddOrderProofOfDeliveryAndOtp', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

