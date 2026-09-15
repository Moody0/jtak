-- Migration: Add bilingual product support and original price in USD
-- Database: jtak_db (MySQL)

USE `jtak_db`;

ALTER TABLE `jtak_db`.`Catalog_Products` 
ADD COLUMN IF NOT EXISTS `TitleEn` VARCHAR(128) NULL AFTER `Title`,
ADD COLUMN IF NOT EXISTS `Barcode` VARCHAR(64) NULL AFTER `TitleEn`,
ADD COLUMN IF NOT EXISTS `Brand` VARCHAR(128) NULL AFTER `Barcode`,
ADD COLUMN IF NOT EXISTS `DescriptionEn` LONGTEXT NULL AFTER `Description`;

ALTER TABLE `jtak_db`.`Catalog_Products`
MODIFY COLUMN `Title` VARCHAR(256) NOT NULL,
MODIFY COLUMN `TitleEn` VARCHAR(256) NULL;

ALTER TABLE `jtak_db`.`Catalog_MerchantProduct` 
ADD COLUMN IF NOT EXISTS `OriginalPrice` DECIMAL(18, 4) NULL AFTER `MerchantPrice`;
