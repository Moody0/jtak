-- =============================================================================
-- Migration: 20260914230000_addMerchantDeliveryPolicyFields
-- Target Database: MySQL (JTAK Catalog DB)
-- Description: Adds DeliveryTime, DeliveryFee, MinOrderAmount, and WorkingHours to Catalog_Merchant
-- =============================================================================

START TRANSACTION;

-- 1. Add delivery policy columns to Catalog_Merchant
ALTER TABLE `Catalog_Merchant` 
ADD COLUMN IF NOT EXISTS `DeliveryTime` VARCHAR(64) NOT NULL DEFAULT '20-30 دقيقة',
ADD COLUMN IF NOT EXISTS `DeliveryFee` DECIMAL(18,2) NOT NULL DEFAULT 5000.00,
ADD COLUMN IF NOT EXISTS `MinOrderAmount` DECIMAL(18,2) NOT NULL DEFAULT 15000.00,
ADD COLUMN IF NOT EXISTS `WorkingHours` VARCHAR(128) NOT NULL DEFAULT 'حتى 3 ص';

-- 2. Populate any null/empty fields on existing records
UPDATE `Catalog_Merchant`
SET `DeliveryTime` = IFNULL(NULLIF(`DeliveryTime`, ''), '20-30 دقيقة'),
    `DeliveryFee` = IFNULL(`DeliveryFee`, 5000.00),
    `MinOrderAmount` = IFNULL(`MinOrderAmount`, 15000.00),
    `WorkingHours` = IFNULL(NULLIF(`WorkingHours`, ''), 'حتى 3 ص');

-- 3. Record migration in EF Core migration history
INSERT IGNORE INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260914230000_addMerchantDeliveryPolicyFields', '6.0.0');

COMMIT;
