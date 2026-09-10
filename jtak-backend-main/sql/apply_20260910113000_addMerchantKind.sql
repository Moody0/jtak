-- =============================================================================
-- Migration: 20260910113000_addMerchantKind
-- Target Database: MySQL (JTAK Catalog DB)
-- Description: Adds MerchantKind column and classifies existing merchants by keyword
-- =============================================================================

START TRANSACTION;

-- 1. Add MerchantKind column
ALTER TABLE `Catalog_Merchant` 
ADD COLUMN IF NOT EXISTS `MerchantKind` tinyint unsigned NOT NULL DEFAULT 0;

-- 2. Populate MerchantKind based on business taxonomy rules
UPDATE `Catalog_Merchant`
SET `MerchantKind` = CASE
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, '')))
         REGEXP 'صيدلي|pharmacy|drugstore' THEN 2
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, '')))
         REGEXP 'سوبرماركت|سوبر ماركت|بقالة|تموينات|hypermarket|grocery|market|mart' THEN 1
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, '')))
         REGEXP 'متجر|مول|shop|store|mall|cosmetic|تجميل' THEN 3
    ELSE 0
END;

-- 3. Record migration in EF Core migration history
INSERT IGNORE INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260910113000_addMerchantKind', '5.0.13');

COMMIT;
