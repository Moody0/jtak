-- =============================================================================
-- Migration: 20260917010000_addMerchantOwnerName
-- Target Database: MariaDB 10.11.18 (Production: jtak_db)
-- Description: Adds dedicated human-readable OwnerName column to Catalog_Merchant
-- Safety: Fully idempotent, non-destructive, and EF Core 6.0.12 compliant
-- =============================================================================

START TRANSACTION;

-- 1. Add dedicated OwnerName column to Catalog_Merchant (native MariaDB 10.11 syntax)
ALTER TABLE `Catalog_Merchant`
ADD COLUMN IF NOT EXISTS `OwnerName` VARCHAR(128) NULL AFTER `Title`;

-- 2. Record migration in EF Core lowercase history table with exact 6.0.12 ProductVersion
INSERT IGNORE INTO `__efmigrationshistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260917010000_AddMerchantOwnerName', '6.0.12');

COMMIT;
