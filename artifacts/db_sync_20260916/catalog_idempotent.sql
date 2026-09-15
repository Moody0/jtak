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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Merchant` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NOT NULL,
        `ShortDescription` varchar(128) CHARACTER SET utf8mb4 NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `Facebook` longtext CHARACTER SET utf8mb4 NULL,
        `Instagram` longtext CHARACTER SET utf8mb4 NULL,
        `Twitter` longtext CHARACTER SET utf8mb4 NULL,
        `Website` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN1Title` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN1` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN2Title` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN2` longtext CHARACTER SET utf8mb4 NULL,
        `Paypal` longtext CHARACTER SET utf8mb4 NULL,
        `Phone1` longtext CHARACTER SET utf8mb4 NULL,
        `Phone2` longtext CHARACTER SET utf8mb4 NULL,
        `Address` longtext CHARACTER SET utf8mb4 NULL,
        `ShippingCost` decimal(65,30) NOT NULL,
        `MinOrder` decimal(65,30) NOT NULL,
        `Active` tinyint(1) NOT NULL,
        `DefaultCurrency` int NOT NULL,
        `OwnerId` char(36) COLLATE ascii_general_ci NOT NULL,
        `Photo` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Merchant` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Tags` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `NameAr` longtext CHARACTER SET utf8mb4 NULL,
        `NameEn` longtext CHARACTER SET utf8mb4 NULL,
        `NameTr` longtext CHARACTER SET utf8mb4 NULL,
        `Photo` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Tags` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_ProductCategories` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NULL,
        `Icon` longtext CHARACTER SET utf8mb4 NULL,
        `MerchantId` int NULL,
        `Active` tinyint(1) NOT NULL,
        `ParentId` int NULL,
        `SubCategoriesCsv` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductCategories` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductCategories_Catalog_ProductCategories_ParentId` FOREIGN KEY (`ParentId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Products` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NOT NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `Photos` longtext CHARACTER SET utf8mb4 NULL,
        `TotalCount` int NOT NULL,
        `SoldCount` int NOT NULL,
        `Unit` longtext CHARACTER SET utf8mb4 NULL,
        `Price` decimal(65,30) NOT NULL,
        `Discount` decimal(65,30) NOT NULL,
        `Currency` int NOT NULL,
        `Active` tinyint(1) NOT NULL,
        `ExpiryDate` datetime(6) NULL,
        `IsFeatured` tinyint(1) NOT NULL,
        `Rate` double NOT NULL,
        `RateCount` int NOT NULL,
        `MerchantId` int NOT NULL,
        `ProductCategoryId` int NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Products` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_Products_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_Products_Catalog_ProductCategories_ProductCategoryId` FOREIGN KEY (`ProductCategoryId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `DynamicField` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductCategoryId` int NOT NULL,
        `DisplayName` longtext CHARACTER SET utf8mb4 NULL,
        `ControlType` tinyint unsigned NOT NULL,
        `IsRequired` tinyint(1) NOT NULL,
        `DisplayOrder` int NOT NULL,
        `PotentialValues` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_DynamicField` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_DynamicField_Catalog_ProductCategories_ProductCategoryId` FOREIGN KEY (`ProductCategoryId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE CASCADE
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_ProductTags` (
        `ProductId` int NOT NULL,
        `TagId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductTags` PRIMARY KEY (`ProductId`, `TagId`),
        CONSTRAINT `FK_Catalog_ProductTags_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductTags_Catalog_Tags_TagId` FOREIGN KEY (`TagId`) REFERENCES `Catalog_Tags` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `DynamicFieldValue` (
        `DynamicFieldId` int NOT NULL,
        `ProductId` bigint NOT NULL,
        `ProductId1` int NULL,
        `ControlType` tinyint unsigned NOT NULL,
        `StringVal` varchar(255) CHARACTER SET utf8mb4 NULL,
        `NumberVal` decimal(65,30) NULL,
        `DateTimeVal` datetime(6) NULL,
        `BoolVal` tinyint(1) NULL,
        CONSTRAINT `PK_DynamicFieldValue` PRIMARY KEY (`DynamicFieldId`, `ProductId`),
        CONSTRAINT `FK_DynamicFieldValue_Catalog_Products_ProductId1` FOREIGN KEY (`ProductId1`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_DynamicFieldValue_DynamicField_DynamicFieldId` FOREIGN KEY (`DynamicFieldId`) REFERENCES `DynamicField` (`Id`) ON DELETE CASCADE
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_MerchantId` ON `Catalog_ProductCategories` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_ParentId` ON `Catalog_ProductCategories` (`ParentId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_Products_MerchantId` ON `Catalog_Products` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_Products_ProductCategoryId` ON `Catalog_Products` (`ProductCategoryId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductTags_TagId` ON `Catalog_ProductTags` (`TagId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_DynamicField_ProductCategoryId` ON `DynamicField` (`ProductCategoryId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_DynamicFieldValue_ProductId1` ON `DynamicFieldValue` (`ProductId1`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220114135506_CatalogInit', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP FOREIGN KEY `FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP FOREIGN KEY `FK_Catalog_Products_Catalog_Merchant_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP INDEX `IX_Catalog_Products_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP INDEX `IX_Catalog_ProductCategories_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP COLUMN `MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `Lat` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `Lng` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `ShipingCoverageInMeters` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    CREATE TABLE `Catalog_MerchantProduct` (
        `MerchantId` int NOT NULL,
        `ProductId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_MerchantProduct` PRIMARY KEY (`MerchantId`, `ProductId`),
        CONSTRAINT `FK_Catalog_MerchantProduct_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_MerchantProduct_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    CREATE INDEX `IX_Catalog_MerchantProduct_ProductId` ON `Catalog_MerchantProduct` (`ProductId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220120133627_addedMoreMerchantStuff', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `Discount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `Price`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `SoldCount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `TotalCount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_ProductCategories` ADD `Order` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `AdditionalPercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `Cost` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `Discount` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    CREATE INDEX `IX_Catalog_Merchant_Lat` ON `Catalog_Merchant` (`Lat`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    CREATE INDEX `IX_Catalog_Merchant_Lng` ON `Catalog_Merchant` (`Lng`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220122141300_addedMoreMerchantProductDetails', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122142155_addedProductCategoryOrderIndex') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_Order` ON `Catalog_ProductCategories` (`Order`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122142155_addedProductCategoryOrderIndex') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220122142155_addedProductCategoryOrderIndex', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220125115448_fixedTypo') THEN

    ALTER TABLE `Catalog_Merchant` RENAME COLUMN `ShipingCoverageInMeters` TO `ShippingCoverageInMeters`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220125115448_fixedTypo') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220125115448_fixedTypo', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    ALTER TABLE `Catalog_Merchant` MODIFY COLUMN `Lng` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    ALTER TABLE `Catalog_Merchant` MODIFY COLUMN `Lat` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220129103311_madeMerchantLocationRequired', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` RENAME COLUMN `Cost` TO `ProfitOutOfMerchantPricePercent`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` RENAME COLUMN `AdditionalPercent` TO `MerchantPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `AdditionalProfitPercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203094220_updatedMerchantProductPrice', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Facebook`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `IBAN2`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `IBAN2Title`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Instagram`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `MinOrder`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Paypal`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `ShippingCost`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Twitter`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Website`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220314101509_optimizedMerchant', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220319100351_improvedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` ADD `ProfitOutOfMerchantPricePercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220319100351_improvedMerchant') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220319100351_improvedMerchant', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN

    ALTER TABLE `Catalog_Merchant` ADD `MerchantKind` tinyint unsigned NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN


                    UPDATE Catalog_Merchant
                    SET MerchantKind = CASE
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'صيدلي|pharmacy|drugstore' THEN 2
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'سوبرماركت|سوبر ماركت|بقالة|تموينات|hypermarket|grocery|market|mart' THEN 1
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'متجر|مول|shop|store|mall|cosmetic|تجميل' THEN 3
                        ELSE 0
                    END;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260910113000_addMerchantKind', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE TABLE `Catalog_ProductBatches` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductId` int NOT NULL,
        `MerchantId` int NOT NULL,
        `BatchNumber` varchar(64) CHARACTER SET utf8mb4 NOT NULL,
        `LotNumber` varchar(64) CHARACTER SET utf8mb4 NULL,
        `Barcode` varchar(64) CHARACTER SET utf8mb4 NOT NULL,
        `Sku` varchar(64) CHARACTER SET utf8mb4 NULL,
        `LocationBin` varchar(128) CHARACTER SET utf8mb4 NULL,
        `ManufactureDate` datetime(6) NULL,
        `ExpirationDate` datetime(6) NOT NULL,
        `QuantityOnHand` int NOT NULL,
        `QuantityReserved` int NOT NULL,
        `CostPrice` decimal(18,2) NOT NULL,
        `SellingPrice` decimal(18,2) NULL,
        `Status` int NOT NULL,
        `Notes` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductBatches` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_ProductBatches_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductBatches_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE TABLE `Catalog_BatchReservations` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductBatchId` int NOT NULL,
        `OrderId` int NOT NULL,
        `OrderDetailId` int NOT NULL,
        `Quantity` int NOT NULL,
        `IsDeducted` tinyint(1) NOT NULL,
        `DeductedDate` datetime(6) NULL,
        `IsReleased` tinyint(1) NOT NULL,
        `ReleasedDate` datetime(6) NULL,
        `ReleaseReason` varchar(256) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_BatchReservations` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_BatchReservations_Catalog_ProductBatches_ProductBatch` FOREIGN KEY (`ProductBatchId`) REFERENCES `Catalog_ProductBatches` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_Barcode` ON `Catalog_ProductBatches` (`Barcode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_BatchNumber` ON `Catalog_ProductBatches` (`BatchNumber`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_ExpirationDate` ON `Catalog_ProductBatches` (`ExpirationDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_MerchantId` ON `Catalog_ProductBatches` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_ProductId` ON `Catalog_ProductBatches` (`ProductId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_OrderDetailId` ON `Catalog_BatchReservations` (`OrderDetailId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_OrderId` ON `Catalog_BatchReservations` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_ProductBatchId` ON `Catalog_BatchReservations` (`ProductBatchId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911160000_AddProductBatchesAndReservations', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915163000_AddPickingFieldsToBatchReservation') THEN

    ALTER TABLE `Catalog_BatchReservations` ADD `IsPicked` tinyint(1) NOT NULL DEFAULT FALSE;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915163000_AddPickingFieldsToBatchReservation') THEN

    ALTER TABLE `Catalog_BatchReservations` ADD `PickedDate` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915163000_AddPickingFieldsToBatchReservation') THEN

    ALTER TABLE `Catalog_BatchReservations` ADD `PickedBy` varchar(128) CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915163000_AddPickingFieldsToBatchReservation') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915163000_AddPickingFieldsToBatchReservation', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915170000_AddProductCatalogCompatibilityColumns') THEN


    ALTER TABLE `Catalog_Products`
        ADD COLUMN IF NOT EXISTS `TitleEn` VARCHAR(256) NULL AFTER `Title`,
        ADD COLUMN IF NOT EXISTS `Barcode` VARCHAR(64) NULL AFTER `TitleEn`,
        ADD COLUMN IF NOT EXISTS `Brand` VARCHAR(128) NULL AFTER `Barcode`,
        ADD COLUMN IF NOT EXISTS `DescriptionEn` LONGTEXT NULL AFTER `Description`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915170000_AddProductCatalogCompatibilityColumns') THEN


    ALTER TABLE `Catalog_Products`
        MODIFY COLUMN `Title` VARCHAR(256) NOT NULL,
        MODIFY COLUMN `TitleEn` VARCHAR(256) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915170000_AddProductCatalogCompatibilityColumns') THEN


    ALTER TABLE `Catalog_MerchantProduct`
        ADD COLUMN IF NOT EXISTS `OriginalPrice` DECIMAL(18, 4) NULL AFTER `MerchantPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915170000_AddProductCatalogCompatibilityColumns') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915170000_AddProductCatalogCompatibilityColumns', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260916120000_AddMerchantProductPriceUsd') THEN


    ALTER TABLE `Catalog_MerchantProduct`
        ADD COLUMN IF NOT EXISTS `PriceUsd` DECIMAL(18, 6) NULL AFTER `OriginalPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260916120000_AddMerchantProductPriceUsd') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260916120000_AddMerchantProductPriceUsd', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

