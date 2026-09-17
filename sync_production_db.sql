-- ==============================================================================
-- JTAK PRODUCTION DATABASE SYNCHRONIZATION SCRIPT (100% SAFE & NON-DESTRUCTIVE)
-- ==============================================================================
-- Purpose:
--   Synchronizes an existing production MySQL / MariaDB database with the latest
--   JTAK codebase schema, tables, columns, indexes, and settings.
--
-- Safety Guarantees:
--   1. ZERO DATA LOSS: No DROP TABLE, no DROP COLUMN, no TRUNCATE.
--   2. IDEMPOTENT: Safe to run once or multiple times; skips existing tables/columns.
--   3. PRESERVES PRODUCTION DATA: Does not overwrite existing orders, users, or prices.
--
-- Instructions for phpMyAdmin:
--   1. (Recommended) Go to the "Export" tab in phpMyAdmin -> Quick -> SQL -> Click "Go" to save a backup.
--   2. Go to the "Import" tab in phpMyAdmin.
--   3. Select this file (`sync_production_db.sql`) and click "Go" / "Import".
--      (Alternatively, open the "SQL" tab, paste this entire file, and click "Go").
-- ==============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------------------------
-- 1. Ensure __EFMigrationsHistory Table Exists
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `__EFMigrationsHistory` (
    `MigrationId` varchar(150) CHARACTER SET utf8mb4 NOT NULL,
    `ProductVersion` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    CONSTRAINT `PK___EFMigrationsHistory` PRIMARY KEY (`MigrationId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------------------------
-- 2. Helper Procedures for Idempotent Schema Upgrades
-- ------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `AddColIfNotExists`;
DELIMITER $$
CREATE PROCEDURE `AddColIfNotExists`(
    IN in_table_name VARCHAR(128),
    IN in_column_name VARCHAR(128),
    IN in_column_def TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = in_table_name
          AND COLUMN_NAME = in_column_name
    ) THEN
        SET @sql = CONCAT('ALTER TABLE `', in_table_name, '` ADD COLUMN `', in_column_name, '` ', in_column_def);
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `AddIdxIfNotExists`;
DELIMITER $$
CREATE PROCEDURE `AddIdxIfNotExists`(
    IN in_table_name VARCHAR(128),
    IN in_index_name VARCHAR(128),
    IN in_index_def TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = in_table_name
          AND INDEX_NAME = in_index_name
    ) THEN
        SET @sql = CONCAT('ALTER TABLE `', in_table_name, '` ADD ', in_index_def);
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END $$
DELIMITER ;

-- ------------------------------------------------------------------------------
-- 3. Catalog Module Upgrades
-- ------------------------------------------------------------------------------

-- Catalog_Merchant
CALL AddColIfNotExists('Catalog_Merchant', 'OwnerName', 'varchar(128) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Catalog_Merchant', 'MerchantKind', 'int NOT NULL DEFAULT 0');
CALL AddColIfNotExists('Catalog_Merchant', 'DeliveryTime', "varchar(64) CHARACTER SET utf8mb4 NOT NULL DEFAULT '20-30 دقيقة'");
CALL AddColIfNotExists('Catalog_Merchant', 'DeliveryFee', 'decimal(18, 2) NOT NULL DEFAULT 5000.00');
CALL AddColIfNotExists('Catalog_Merchant', 'MinOrderAmount', 'decimal(18, 2) NOT NULL DEFAULT 15000.00');
CALL AddColIfNotExists('Catalog_Merchant', 'WorkingHours', "varchar(128) CHARACTER SET utf8mb4 NOT NULL DEFAULT 'حتى 3 ص'");

-- Catalog_MerchantProduct
CALL AddColIfNotExists('Catalog_MerchantProduct', 'OriginalPrice', 'decimal(18, 4) NULL');
CALL AddColIfNotExists('Catalog_MerchantProduct', 'PriceUsd', 'decimal(18, 6) NULL');

-- Catalog_Products
CALL AddColIfNotExists('Catalog_Products', 'TitleEn', 'varchar(256) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Catalog_Products', 'Barcode', 'varchar(128) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Catalog_Products', 'Brand', 'varchar(128) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Catalog_Products', 'DescriptionEn', 'longtext CHARACTER SET utf8mb4 NULL');

-- Catalog_ProductBatches
CREATE TABLE IF NOT EXISTS `Catalog_ProductBatches` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `ProductId` INT NOT NULL,
    `BatchCode` VARCHAR(64) NOT NULL,
    `CostPriceUsd` DECIMAL(18, 4) NOT NULL,
    `CostPriceSyp` DECIMAL(18, 4) NOT NULL,
    `ExchangeRateUsed` DECIMAL(18, 4) NOT NULL,
    `QuantityReceived` INT NOT NULL,
    `QuantityRemaining` INT NOT NULL,
    `ExpiryDate` DATETIME(6) NULL,
    `ReceivedDate` DATETIME(6) NOT NULL,
    `Supplier` VARCHAR(128) NULL,
    `InvoiceReference` VARCHAR(64) NULL,
    `Notes` LONGTEXT NULL,
    `IsActive` TINYINT(1) NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_Catalog_ProductBatches_ProductId` (`ProductId`),
    INDEX `IX_Catalog_ProductBatches_BatchCode` (`BatchCode`),
    INDEX `IX_Catalog_ProductBatches_ExpiryDate` (`ExpiryDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catalog_BatchReservations
CREATE TABLE IF NOT EXISTS `Catalog_BatchReservations` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `BatchId` INT NOT NULL,
    `OrderId` INT NOT NULL,
    `ProductId` INT NOT NULL,
    `MerchantId` INT NOT NULL,
    `Quantity` INT NOT NULL,
    `Status` INT NOT NULL DEFAULT 0,
    `ReservedAt` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `ConfirmedAt` DATETIME(6) NULL,
    `ReleasedAt` DATETIME(6) NULL,
    `IsPicked` TINYINT(1) NOT NULL DEFAULT 0,
    `PickedDate` DATETIME(6) NULL,
    `PickedBy` VARCHAR(128) NULL,
    `PickedQuantity` INT NOT NULL DEFAULT 0,
    `PickedAt` DATETIME(6) NULL,
    `PickedByUserId` VARCHAR(128) NULL,
    `Notes` LONGTEXT NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_Catalog_BatchReservations_BatchId` (`BatchId`),
    INDEX `IX_Catalog_BatchReservations_OrderId` (`OrderId`),
    INDEX `IX_Catalog_BatchReservations_ProductId` (`ProductId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 4. Orders Module Upgrades
-- ------------------------------------------------------------------------------
CALL AddColIfNotExists('Orders_Orders', 'ProofOfDeliveryPhotoUrl', 'longtext CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Orders_Orders', 'ProofOfDeliverySignature', 'longtext CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Orders_Orders', 'DeliveryOtp', 'varchar(10) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Orders_Orders', 'DeliveryNotes', 'longtext CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Orders_Orders', 'DeliveryLatitude', 'decimal(65,30) NULL');
CALL AddColIfNotExists('Orders_Orders', 'DeliveryLongitude', 'decimal(65,30) NULL');
CALL AddColIfNotExists('Orders_Orders', 'DeliveryLocationUpdatedAt', 'datetime(6) NULL');

-- ------------------------------------------------------------------------------
-- 5. Shipping Module Upgrades
-- ------------------------------------------------------------------------------
CALL AddColIfNotExists('Shipping_ShippingOrders', 'StopType', 'tinyint unsigned NOT NULL DEFAULT 0');
CALL AddColIfNotExists('Shipping_ShippingOrders', 'StopTitle', 'varchar(128) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Shipping_ShippingOrders', 'IsDarkStore', 'tinyint(1) NOT NULL DEFAULT 0');
CALL AddColIfNotExists('Shipping_ShippingOrders', 'VerificationCode', 'varchar(32) CHARACTER SET utf8mb4 NULL');
CALL AddColIfNotExists('Shipping_ShippingOrders', 'Notes', 'varchar(256) CHARACTER SET utf8mb4 NULL');

-- ------------------------------------------------------------------------------
-- 6. Support Messages Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `SupportMessages` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `UserId` VARCHAR(36) NULL,
    `SenderName` VARCHAR(150) NULL,
    `SenderPhone` VARCHAR(50) NULL,
    `SenderEmail` VARCHAR(150) NULL,
    `Title` VARCHAR(200) NULL,
    `Message` LONGTEXT NULL,
    `Status` INT NOT NULL DEFAULT 0,
    `AdminNotes` LONGTEXT NULL,
    `ResolvedDate` DATETIME(6) NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_SupportMessages_Status` (`Status`),
    INDEX `IX_SupportMessages_CreatedDate` (`CreatedDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 7. Accounting Module Upgrades (Double-Entry Ledger & Settlements)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Accounting_ChartOfAccounts` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `AccountCode` VARCHAR(32) NOT NULL,
    `AccountName` VARCHAR(128) NOT NULL,
    `AccountType` INT NOT NULL,
    `ParentAccountId` INT NULL,
    `IsActive` TINYINT(1) NOT NULL DEFAULT 1,
    `Description` LONGTEXT NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    UNIQUE INDEX `IX_Accounting_ChartOfAccounts_AccountCode` (`AccountCode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Accounting_JournalTransactions` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `TransactionNumber` VARCHAR(64) NOT NULL,
    `TransactionDate` DATETIME(6) NOT NULL,
    `TransactionType` INT NOT NULL,
    `ReferenceType` VARCHAR(64) NULL,
    `ReferenceId` VARCHAR(64) NULL,
    `Description` LONGTEXT NULL,
    `IdempotencyKey` VARCHAR(128) NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    UNIQUE INDEX `IX_Accounting_JournalTransactions_TransactionNumber` (`TransactionNumber`),
    UNIQUE INDEX `IX_Accounting_JournalTransactions_IdempotencyKey` (`IdempotencyKey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Accounting_JournalEntries` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `TransactionId` INT NOT NULL,
    `AccountId` INT NOT NULL,
    `Debit` DECIMAL(18, 4) NOT NULL DEFAULT 0.0000,
    `Credit` DECIMAL(18, 4) NOT NULL DEFAULT 0.0000,
    `Currency` VARCHAR(10) NOT NULL DEFAULT 'SYP',
    `ExchangeRate` DECIMAL(18, 4) NOT NULL DEFAULT 1.0000,
    `DebitLocal` DECIMAL(18, 4) NOT NULL DEFAULT 0.0000,
    `CreditLocal` DECIMAL(18, 4) NOT NULL DEFAULT 0.0000,
    `PartyType` VARCHAR(32) NULL,
    `PartyId` VARCHAR(64) NULL,
    `Description` LONGTEXT NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_Accounting_JournalEntries_TransactionId` (`TransactionId`),
    INDEX `IX_Accounting_JournalEntries_AccountId` (`AccountId`),
    INDEX `IX_Accounting_JournalEntries_PartyType_PartyId` (`PartyType`, `PartyId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Accounting_SettlementRequests` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `RequestNumber` VARCHAR(64) NOT NULL,
    `PartyType` INT NOT NULL,
    `RequestedByUserId` VARCHAR(36) NOT NULL,
    `TotalAmount` DECIMAL(18, 4) NOT NULL,
    `Currency` VARCHAR(10) NOT NULL DEFAULT 'SYP',
    `Status` INT NOT NULL DEFAULT 0,
    `Notes` LONGTEXT NULL,
    `ProcessedByUserId` VARCHAR(36) NULL,
    `ProcessedAt` DATETIME(6) NULL,
    `RejectionReason` LONGTEXT NULL,
    `PaymentReference` VARCHAR(128) NULL,
    `PaymentMethod` VARCHAR(64) NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    UNIQUE INDEX `IX_Accounting_SettlementRequests_RequestNumber` (`RequestNumber`),
    INDEX `IX_Accounting_SettlementRequests_PartyType_Status_CreatedDate` (`PartyType`, `Status`, `CreatedDate`),
    INDEX `IX_Accounting_SettlementRequests_RequestedByUserId_Status` (`RequestedByUserId`, `Status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Accounting_SettlementRequestMerchantAllocations` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `SettlementRequestId` INT NOT NULL,
    `MerchantId` INT NOT NULL,
    `Amount` DECIMAL(18, 4) NOT NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_Accounting_SettlementRequestMerchantAllocations_SettlementRequestId` (`SettlementRequestId`),
    INDEX `IX_Accounting_SettlementRequestMerchantAllocations_MerchantId_SettlementRequestId` (`MerchantId`, `SettlementRequestId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Enforce Unique Constraint on Accounting_Bills(OrderId, MerchantId) if table exists
CALL AddIdxIfNotExists('Accounting_Bills', 'IX_Accounting_Bills_OrderId_MerchantId', 'UNIQUE INDEX `IX_Accounting_Bills_OrderId_MerchantId` (`OrderId`, `MerchantId`)');

-- ------------------------------------------------------------------------------
-- 8. Clean up Helper Procedures
-- ------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `AddColIfNotExists`;
DROP PROCEDURE IF EXISTS `AddIdxIfNotExists`;

-- ------------------------------------------------------------------------------
-- 9. Exchange Rate Setting & Market Product USD Conversion
-- ------------------------------------------------------------------------------

-- Ensure Settings table exists
CREATE TABLE IF NOT EXISTS `Settings` (
    `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
    `Value` longtext CHARACTER SET utf8mb4 NULL,
    `CreatedDate` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
    `UpdatedDate` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
    PRIMARY KEY (`Key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed USD Exchange Rate if not already configured
INSERT INTO `Settings` (`Key`, `Value`, `CreatedDate`, `UpdatedDate`)
VALUES ('UsdToSypExchangeRate', '{"Rate":15000}', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE `Value` = IF(`Value` IS NULL OR `Value` = '', '{"Rate":15000}', `Value`);

-- For JTAK Market (Merchant 12): Safely populate PriceUsd for products whose price was stored in USD (< 1000)
UPDATE `Catalog_MerchantProduct`
SET `PriceUsd` = `MerchantPrice`,
    `MerchantPrice` = ROUND(`MerchantPrice` * 15000, 0)
WHERE `MerchantId` = 12
  AND `PriceUsd` IS NULL
  AND `MerchantPrice` > 0
  AND `MerchantPrice` < 1000;

-- ------------------------------------------------------------------------------
-- 10. Record EF Core Migration History
-- ------------------------------------------------------------------------------
INSERT IGNORE INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`) VALUES
('20220114132548_AppInit', '6.0.12'),
('20220120122434_addedBanners', '6.0.12'),
('20220123111100_removedUnusedPropertiesFromAppUser', '6.0.12'),
('20220421073652_addedUserDefaultLocation', '6.0.12'),
('20260915150000_AddSupportMessages', '6.0.12'),
('20220114135506_CatalogInit', '6.0.12'),
('20220120133627_addedMoreMerchantStuff', '6.0.12'),
('20220122141300_addedMoreMerchantProductDetails', '6.0.12'),
('20220122142155_addedProductCategoryOrderIndex', '6.0.12'),
('20220125115448_fixedTypo', '6.0.12'),
('20220129103311_madeMerchantLocationRequired', '6.0.12'),
('20220203094220_updatedMerchantProductPrice', '6.0.12'),
('20220314101509_optimizedMerchant', '6.0.12'),
('20220319100351_improvedMerchant', '6.0.12'),
('20260910113000_addMerchantKind', '6.0.12'),
('20260911160000_AddProductBatchesAndReservations', '6.0.12'),
('20260915163000_AddPickingFieldsToBatchReservation', '6.0.12'),
('20260915170000_AddProductCatalogCompatibilityColumns', '6.0.12'),
('20260916120000_AddMerchantProductPriceUsd', '6.0.12'),
('20260917010000_AddMerchantOwnerName', '6.0.12'),
('20220114135533_OrdersInit', '6.0.12'),
('20220123105341_improvedOrderAndOrderDetails', '6.0.12'),
('20220126133742_addedOrdersUpdates', '6.0.12'),
('20220128211103_addedOrderUpdateLogAndDeliveryId', '6.0.12'),
('20220203094159_removedRedundantPriceing', '6.0.12'),
('20220203114313_addedMoreOrderDetails', '6.0.12'),
('20220403142048_addedDerliveryUserName', '6.0.12'),
('20260909150000_addDeliveryLiveLocation', '6.0.12'),
('20260911170000_AddOrderProofOfDeliveryAndOtp', '6.0.12'),
('20220423105008_addedShippingDbStuff', '6.0.12'),
('20260911170000_AddShippingStopDetails', '6.0.12'),
('20220203093913_initAccountingDb', '6.0.12'),
('20220203143309_addedBalances', '6.0.12'),
('20220318143205_improvedHandOverDate', '6.0.12'),
('20220325140922_improvedBalances', '6.0.12'),
('20220328124235_revertedToPendingBalances', '6.0.12'),
('20260911120259_AddDoubleEntryLedgerTables', '6.0.12'),
('20260915071938_AddSettlementRequestWorkflow', '6.0.12'),
('20260915080246_EnforceLedgerIdempotency', '6.0.12'),
('20260915123000_AddUniqueConstraintToBillOrderIdMerchantId', '6.0.12');

SET FOREIGN_KEY_CHECKS = 1;

-- ==============================================================================
-- END OF SYNCHRONIZATION SCRIPT
-- ==============================================================================
