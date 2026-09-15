-- ==============================================================================
-- CLEANUP DUPLICATE SAVED ADDRESSES
-- Run this in phpMyAdmin to remove any duplicate addresses created previously.
-- Safe: Keeps the original/first record and removes only redundant duplicates.
-- ==============================================================================

DELETE a1 FROM `Addresses` a1
INNER JOIN `Addresses` a2 
WHERE a1.`Id` > a2.`Id` 
  AND a1.`UserId` = a2.`UserId` 
  AND COALESCE(a1.`Title`, '') = COALESCE(a2.`Title`, '') 
  AND COALESCE(a1.`FullAddress`, '') = COALESCE(a2.`FullAddress`, '');

SELECT 'Cleaned up duplicate addresses successfully!' AS `Result`;
