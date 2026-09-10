-- Migration: Add bilingual product support and original price in USD
-- Database: jtak_db (MySQL)

ALTER TABLE `Catalog_Products` 
ADD COLUMN IF NOT EXISTS `TitleEn` VARCHAR(128) NULL AFTER `Title`,
ADD COLUMN IF NOT EXISTS `DescriptionEn` LONGTEXT NULL AFTER `Description`;

ALTER TABLE `Catalog_MerchantProduct` 
ADD COLUMN IF NOT EXISTS `OriginalPrice` DECIMAL(18, 4) NULL AFTER `MerchantPrice`;
