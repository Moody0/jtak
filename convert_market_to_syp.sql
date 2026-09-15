-- =====================================================================
--  JTAK - convert the market catalogue from raw USD to local currency
-- =====================================================================
--  Run ONCE, and only AFTER deploying the backend build that adds the
--  Catalog_MerchantProduct.PriceUsd column.
--
--  Merchant 12 (جيتك ماركت) was imported with dollar amounts written straight
--  into MerchantPrice, while the restaurants (24-27) were entered directly in
--  local currency. This moves the market's dollar figures into PriceUsd and
--  derives MerchantPrice from the current rate. Restaurants keep PriceUsd NULL,
--  so the reprice routine never touches them.
--
--  Restart the API afterwards: prices and settings are held in an in-process
--  cache that will not notice a change made underneath it.
-- =====================================================================

USE `jtak_db`;

SET @rate   := 135;   -- must match the rate shown in the dashboard
SET @market := 12;

START TRANSACTION;

-- 1. Seed the language-neutral rate key that the pricing code reads.
--    Without this the services fall back to "no dollar pricing configured".
INSERT INTO `Settings` (`Key`, `Value`, `CreatedDate`, `UpdatedDate`)
VALUES ('UsdToSypExchangeRate', CONCAT('{"Rate":', @rate, '}'), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE `Value` = CONCAT('{"Rate":', @rate, '}'), `UpdatedDate` = UTC_TIMESTAMP(6);

-- 2. Convert the market's dollar prices.
--    Rows at zero are unpriced placeholders and rows at or above 1000 are not
--    dollar amounts at all, so both are left out for manual review in step 4.
UPDATE `Catalog_MerchantProduct`
SET `PriceUsd`      = `MerchantPrice`,
    `MerchantPrice` = ROUND(`MerchantPrice` * @rate, 0)
WHERE `MerchantId` = @market
  AND `PriceUsd` IS NULL
  AND `MerchantPrice` > 0
  AND `MerchantPrice` < 1000;

COMMIT;

-- 3. Verify: expect ~3648 rows, local prices roughly 5 .. 123120.
SELECT COUNT(*)          AS converted,
       MIN(`MerchantPrice`) AS min_local,
       MAX(`MerchantPrice`) AS max_local,
       MIN(`PriceUsd`)      AS min_usd,
       MAX(`PriceUsd`)      AS max_usd
FROM `Catalog_MerchantProduct`
WHERE `MerchantId` = @market AND `PriceUsd` IS NOT NULL;

-- 4. Rows deliberately skipped - these need a price entered by hand.
--    Until they get one they stay outside dollar tracking.
SELECT `ProductId`, `MerchantPrice`
FROM `Catalog_MerchantProduct`
WHERE `MerchantId` = @market AND `PriceUsd` IS NULL AND `MerchantPrice` >= 1000;

-- 5. Sanity check: the restaurants must be completely unaffected.
SELECT `MerchantId`, COUNT(*) AS rows_with_usd_base
FROM `Catalog_MerchantProduct`
WHERE `PriceUsd` IS NOT NULL
GROUP BY `MerchantId`;
