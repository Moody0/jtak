-- ==============================================================================
-- JTAK PRODUCTION DATABASE RECONCILIATION: accounting_ledgerentries ROLLBACK
-- Target DB: MariaDB 10.11 / MySQL 8.0+
-- Author: JTAK DevOps & Antigravity Engineering
-- Date: 2026-09-17
--
-- ATOMIC RENAME ROLLBACK ARCHITECTURE:
--   1. Validates that `accounting_ledgerentries_backup_20260917` exists.
--   2. Validates that current `accounting_ledgerentries` exists.
--   3. Performs an atomic swap using `RENAME TABLE`:
--        accounting_ledgerentries TO accounting_ledgerentries_quarantine_20260917,
--        accounting_ledgerentries_backup_20260917 TO accounting_ledgerentries;
--      This restores the original legacy table with 100% fidelity (all original
--      indexes, constraints, datatypes, and 0 data).
--   4. Preserves the quarantined table for forensic inspection.
--   5. Reverts the migration record from `__efmigrationshistory`.
-- ==============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_rollback_accounting_ledgerentries $$

CREATE PROCEDURE sp_rollback_accounting_ledgerentries()
proc_block: BEGIN
    DECLARE v_backup_exists INT DEFAULT 0;
    DECLARE v_live_exists INT DEFAULT 0;

    -- Verify backup table exists
    SELECT COUNT(*) INTO v_backup_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_backup_20260917';

    IF v_backup_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT ROLLBACK: Backup table `accounting_ledgerentries_backup_20260917` not found.';
    END IF;

    -- Verify live table exists
    SELECT COUNT(*) INTO v_live_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries';

    IF v_live_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT ROLLBACK: Live table `accounting_ledgerentries` not found.';
    END IF;

    -- Atomic rollback swap
    RENAME TABLE
      `accounting_ledgerentries` TO `accounting_ledgerentries_quarantine_20260917`,
      `accounting_ledgerentries_backup_20260917` TO `accounting_ledgerentries`;

    -- Revert migration history entry in lowercase __efmigrationshistory
    IF EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = '__efmigrationshistory'
    ) THEN
        DELETE FROM `__efmigrationshistory`
        WHERE `MigrationId` = '20260917154500_ReconcileAccountingLedgerEntriesSchema';
    END IF;

    SELECT 'ROLLBACK SUCCESS: Original legacy table restored exactly from backup. Quarantined table preserved for audit.' AS Status;
END proc_block $$

DELIMITER ;

CALL sp_rollback_accounting_ledgerentries();

DROP PROCEDURE IF EXISTS sp_rollback_accounting_ledgerentries;
