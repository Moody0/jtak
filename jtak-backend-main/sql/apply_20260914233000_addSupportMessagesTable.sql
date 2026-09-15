-- =========================================================================================
-- Migration: Add SupportMessages Table for Customer Support & Inquiries
-- Date: 2026-09-14
-- Description: Stores customer help requests, complaints, and inquiries submitted from the mobile app
-- =========================================================================================

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
