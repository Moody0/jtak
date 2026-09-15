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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Bills` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `MerchantId` int NOT NULL,
        `MerchantAmount` decimal(65,30) NOT NULL,
        `TotalAmount` decimal(65,30) NOT NULL,
        `JTakAmount` decimal(65,30) NOT NULL,
        `JTakAdditionalAmount` decimal(65,30) NOT NULL,
        `PaymentMethod` int NOT NULL,
        `DueDate` datetime(6) NOT NULL,
        `OrderId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Bills` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Payments` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ToUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `ToUser` longtext CHARACTER SET utf8mb4 NULL,
        `ByUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `ByUser` longtext CHARACTER SET utf8mb4 NULL,
        `Amount` decimal(65,30) NOT NULL,
        `NewBalance` decimal(65,30) NOT NULL,
        `HandoverDate` datetime(6) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Payments` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203093913_initAccountingDb', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203143309_addedBalances') THEN

    CREATE TABLE `Accounting_Balances` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `Amount` decimal(65,30) NOT NULL,
        `PendingAmount` decimal(65,30) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Balances` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203143309_addedBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203143309_addedBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220318143205_improvedHandOverDate') THEN

    ALTER TABLE `Accounting_Payments` MODIFY COLUMN `HandoverDate` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220318143205_improvedHandOverDate') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220318143205_improvedHandOverDate', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    ALTER TABLE `Accounting_Balances` DROP COLUMN `PendingAmount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    ALTER TABLE `Accounting_Balances` ADD `Name` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220325140922_improvedBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    ALTER TABLE `Accounting_Bills` ADD `IsAddedToDues` tinyint(1) NOT NULL DEFAULT FALSE;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    ALTER TABLE `Accounting_Balances` ADD `PendingAmount` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220328124235_revertedToPendingBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_Accounts` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `AccountCode` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `Name` varchar(200) CHARACTER SET utf8mb4 NOT NULL,
        `Type` int NOT NULL,
        `Currency` varchar(10) CHARACTER SET utf8mb4 NOT NULL,
        `OwnerUserId` char(36) COLLATE ascii_general_ci NULL,
        `OwnerMerchantId` int NULL,
        `IsActive` tinyint(1) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Accounts` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_DailySettlementBatches` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `BatchCode` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `CaptainUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `BatchDate` datetime(6) NOT NULL,
        `TotalCashCollected` decimal(18,2) NOT NULL,
        `TotalWagesEarned` decimal(18,2) NOT NULL,
        `NetCashRemitted` decimal(18,2) NOT NULL,
        `DiscrepancyAmount` decimal(18,2) NOT NULL,
        `DiscrepancyReason` varchar(500) CHARACTER SET utf8mb4 NULL,
        `HandledByAdminId` char(36) COLLATE ascii_general_ci NOT NULL,
        `SettlementTransactionId` char(36) COLLATE ascii_general_ci NOT NULL,
        `IsLocked` tinyint(1) NOT NULL,
        `Notes` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_DailySettlementBatches` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_JournalTransactions` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `TransactionNumber` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `PostedDate` datetime(6) NOT NULL,
        `ReferenceType` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `ReferenceId` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `IdempotencyKey` varchar(150) CHARACTER SET utf8mb4 NULL,
        `Description` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_JournalTransactions` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_LedgerEntries` (
        `Id` bigint NOT NULL AUTO_INCREMENT,
        `JournalTransactionId` char(36) COLLATE ascii_general_ci NOT NULL,
        `AccountId` char(36) COLLATE ascii_general_ci NOT NULL,
        `Debit` decimal(18,2) NOT NULL,
        `Credit` decimal(18,2) NOT NULL,
        `Currency` varchar(10) CHARACTER SET utf8mb4 NOT NULL,
        `Memo` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_LedgerEntries` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Accounting_LedgerEntries_Accounting_Accounts_AccountId` FOREIGN KEY (`AccountId`) REFERENCES `Accounting_Accounts` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Accounting_LedgerEntries_Accounting_JournalTransactions_Jour~` FOREIGN KEY (`JournalTransactionId`) REFERENCES `Accounting_JournalTransactions` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_Accounts_AccountCode` ON `Accounting_Accounts` (`AccountCode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_Accounts_OwnerMerchantId` ON `Accounting_Accounts` (`OwnerMerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_Accounts_OwnerUserId` ON `Accounting_Accounts` (`OwnerUserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_DailySettlementBatches_BatchCode` ON `Accounting_DailySettlementBatches` (`BatchCode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_DailySettlementBatches_CaptainUserId_BatchDate` ON `Accounting_DailySettlementBatches` (`CaptainUserId`, `BatchDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_JournalTransactions_IdempotencyKey` ON `Accounting_JournalTransactions` (`IdempotencyKey`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_JournalTransactions_ReferenceType_ReferenceId` ON `Accounting_JournalTransactions` (`ReferenceType`, `ReferenceId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_JournalTransactions_TransactionNumber` ON `Accounting_JournalTransactions` (`TransactionNumber`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_LedgerEntries_AccountId_Currency` ON `Accounting_LedgerEntries` (`AccountId`, `Currency`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_LedgerEntries_JournalTransactionId` ON `Accounting_LedgerEntries` (`JournalTransactionId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911120259_AddDoubleEntryLedgerTables', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE TABLE `Accounting_SettlementRequests` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `RequestNumber` varchar(80) CHARACTER SET utf8mb4 NOT NULL,
        `PartyType` tinyint unsigned NOT NULL,
        `Status` tinyint unsigned NOT NULL,
        `RequestedByUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `RequestedByName` varchar(200) CHARACTER SET utf8mb4 NULL,
        `RequestedByPhone` varchar(40) CHARACTER SET utf8mb4 NULL,
        `Amount` decimal(18,2) NOT NULL,
        `Currency` varchar(8) CHARACTER SET utf8mb4 NOT NULL,
        `Method` varchar(80) CHARACTER SET utf8mb4 NULL,
        `AccountDetails` varchar(500) CHARACTER SET utf8mb4 NULL,
        `Notes` varchar(500) CHARACTER SET utf8mb4 NULL,
        `RejectionReason` varchar(500) CHARACTER SET utf8mb4 NULL,
        `ReviewedByAdminId` char(36) COLLATE ascii_general_ci NULL,
        `ReviewedAt` datetime(6) NULL,
        `CompletedByAdminId` char(36) COLLATE ascii_general_ci NULL,
        `CompletedAt` datetime(6) NULL,
        `LedgerTransactionId` char(36) COLLATE ascii_general_ci NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_SettlementRequests` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE TABLE `Accounting_SettlementRequestMerchantAllocations` (
        `Id` bigint NOT NULL AUTO_INCREMENT,
        `SettlementRequestId` char(36) COLLATE ascii_general_ci NOT NULL,
        `MerchantId` int NOT NULL,
        `MerchantTitle` varchar(200) CHARACTER SET utf8mb4 NULL,
        `Amount` decimal(18,2) NOT NULL,
        CONSTRAINT `PK_Accounting_SettlementRequestMerchantAllocations` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Accounting_SettlementRequestMerchantAllocations_Accounting_S~` FOREIGN KEY (`SettlementRequestId`) REFERENCES `Accounting_SettlementRequests` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE INDEX `IX_Accounting_SettlementRequestMerchantAllocations_MerchantId_S~` ON `Accounting_SettlementRequestMerchantAllocations` (`MerchantId`, `SettlementRequestId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE INDEX `IX_Accounting_SettlementRequestMerchantAllocations_SettlementRe~` ON `Accounting_SettlementRequestMerchantAllocations` (`SettlementRequestId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE INDEX `IX_Accounting_SettlementRequests_PartyType_Status_CreatedDate` ON `Accounting_SettlementRequests` (`PartyType`, `Status`, `CreatedDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE INDEX `IX_Accounting_SettlementRequests_RequestedByUserId_Status` ON `Accounting_SettlementRequests` (`RequestedByUserId`, `Status`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    CREATE UNIQUE INDEX `IX_Accounting_SettlementRequests_RequestNumber` ON `Accounting_SettlementRequests` (`RequestNumber`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915071938_AddSettlementRequestWorkflow') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915071938_AddSettlementRequestWorkflow', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915080246_EnforceLedgerIdempotency') THEN

    ALTER TABLE `Accounting_JournalTransactions` DROP INDEX `IX_Accounting_JournalTransactions_IdempotencyKey`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915080246_EnforceLedgerIdempotency') THEN

    CREATE UNIQUE INDEX `IX_Accounting_JournalTransactions_IdempotencyKey` ON `Accounting_JournalTransactions` (`IdempotencyKey`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915080246_EnforceLedgerIdempotency') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915080246_EnforceLedgerIdempotency', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915123000_AddUniqueConstraintToBillOrderIdMerchantId') THEN

    CREATE UNIQUE INDEX `IX_Accounting_Bills_OrderId_MerchantId` ON `Accounting_Bills` (`OrderId`, `MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915123000_AddUniqueConstraintToBillOrderIdMerchantId') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915123000_AddUniqueConstraintToBillOrderIdMerchantId', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

