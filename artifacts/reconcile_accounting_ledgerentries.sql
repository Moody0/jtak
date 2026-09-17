-- ==============================================================================
-- JTAK PRODUCTION DATABASE RECONCILIATION: accounting_ledgerentries
-- Target DB: MariaDB 10.11 / MySQL 8.0+
-- Author: JTAK DevOps & Antigravity Engineering
-- Date: 2026-09-17
--
-- EXACT PRODUCTION SCHEMA DETAILS:
--   - Live table name: `accounting_ledgerentries` (lowercase)
--   - Parent tables: `accounting_accounts`, `accounting_journaltransactions` (lowercase)
--   - Parent PK types: char(36) utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL PRIMARY KEY
--   - Authoritative new PK: Id bigint AUTO_INCREMENT (verified 0 inbound FKs)
--   - Migration history: `__efmigrationshistory` (lowercase)
--
-- ATOMIC STAGED SWAP ARCHITECTURE:
--   1. Strict prechecks:
--      - Parent tables `accounting_accounts` and `accounting_journaltransactions` exist.
--      - If live table already has `Credit` and `Debit`, exit idempotently.
--      - Live table MUST have 0 rows. If > 0 rows, SIGNAL 45000 and abort.
--      - Staging table `accounting_ledgerentries_new_20260917` does NOT exist.
--      - Backup table `accounting_ledgerentries_backup_20260917` does NOT exist.
--   2. Pre-create staging table `accounting_ledgerentries_new_20260917` with exact EF Core schema
--      and verified foreign key collation (`char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`).
--   3. Deep validation of staging table (all 11 columns, PK, indexes, FKs, 0 rows).
--   4. ATOMIC SWAP via `RENAME TABLE`:
--        accounting_ledgerentries TO accounting_ledgerentries_backup_20260917,
--        accounting_ledgerentries_new_20260917 TO accounting_ledgerentries;
--      (Preserves the exact live legacy table as backup with zero table DROP and zero downtime).
--   5. Record migration truthfully in `__efmigrationshistory`.
-- ==============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_reconcile_accounting_ledgerentries $$

CREATE PROCEDURE sp_reconcile_accounting_ledgerentries()
proc_block: BEGIN
    DECLARE v_accounts_exist INT DEFAULT 0;
    DECLARE v_journal_exist INT DEFAULT 0;
    DECLARE v_live_exists INT DEFAULT 0;
    DECLARE v_credit_exists INT DEFAULT 0;
    DECLARE v_debit_exists INT DEFAULT 0;
    DECLARE v_new_exists INT DEFAULT 0;
    DECLARE v_backup_exists INT DEFAULT 0;
    DECLARE v_live_rows INT DEFAULT 0;

    -- Validation counters for staging table
    DECLARE v_stg_col_count INT DEFAULT 0;
    DECLARE v_stg_pk_count INT DEFAULT 0;
    DECLARE v_stg_fk_count INT DEFAULT 0;
    DECLARE v_stg_rows INT DEFAULT 0;

    -- -------------------------------------------------------------------------
    -- GUARD 1: Verify parent tables exist in current database (lowercase)
    -- -------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_accounts_exist
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_accounts';

    IF v_accounts_exist = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Required parent table `accounting_accounts` does not exist.';
    END IF;

    SELECT COUNT(*) INTO v_journal_exist
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_journaltransactions';

    IF v_journal_exist = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Required parent table `accounting_journaltransactions` does not exist.';
    END IF;

    -- -------------------------------------------------------------------------
    -- GUARD 2: Check if live accounting_ledgerentries already has reconciled schema
    -- -------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_live_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries';

    IF v_live_exists > 0 THEN
        SELECT COUNT(*) INTO v_credit_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND LOWER(TABLE_NAME) = 'accounting_ledgerentries'
          AND LOWER(COLUMN_NAME) = 'credit';

        SELECT COUNT(*) INTO v_debit_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND LOWER(TABLE_NAME) = 'accounting_ledgerentries'
          AND LOWER(COLUMN_NAME) = 'debit';

        IF v_credit_exists > 0 AND v_debit_exists > 0 THEN
            SELECT 'OK: `accounting_ledgerentries` already has `Credit` and `Debit` columns. Schema already reconciled.' AS Status;
            LEAVE proc_block;
        END IF;

        -- ---------------------------------------------------------------------
        -- GUARD 3: Strict empty-table guard (BLOCKER 1: Never drop/replace non-empty ledger)
        -- ---------------------------------------------------------------------
        SET @query_cnt = 'SELECT COUNT(*) INTO @tbl_rows FROM `accounting_ledgerentries`';
        PREPARE stmt_cnt FROM @query_cnt;
        EXECUTE stmt_cnt;
        DEALLOCATE PREPARE stmt_cnt;

        SET v_live_rows = @tbl_rows;

        IF v_live_rows > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'ABORT: `accounting_ledgerentries` contains data (> 0 rows). Refusing to replace table.';
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- GUARD 4: Collision checks (staging and backup tables must not already exist)
    -- -------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_new_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_new_20260917';

    IF v_new_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Staging table `accounting_ledgerentries_new_20260917` already exists.';
    END IF;

    SELECT COUNT(*) INTO v_backup_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_backup_20260917';

    IF v_backup_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Backup table `accounting_ledgerentries_backup_20260917` already exists. Refusing to overwrite.';
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 5: Create NEW staging table with exact EF Core schema & production FK collation
    -- -------------------------------------------------------------------------
    CREATE TABLE `accounting_ledgerentries_new_20260917` (
        `Id` bigint(20) NOT NULL AUTO_INCREMENT,
        `JournalTransactionId` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        `AccountId` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        `Debit` decimal(18,2) NOT NULL DEFAULT 0.00,
        `Credit` decimal(18,2) NOT NULL DEFAULT 0.00,
        `Currency` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SYP',
        `Memo` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
        PRIMARY KEY (`Id`),
        KEY `IX_ledg_journal` (`JournalTransactionId`),
        KEY `IX_ledg_account_currency` (`AccountId`, `Currency`),
        CONSTRAINT `FK_ledg_account`
            FOREIGN KEY (`AccountId`) REFERENCES `accounting_accounts` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_ledg_journal`
            FOREIGN KEY (`JournalTransactionId`) REFERENCES `accounting_journaltransactions` (`Id`) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic;

    -- -------------------------------------------------------------------------
    -- STEP 6: Deep validation of NEW staging table before any swap
    -- -------------------------------------------------------------------------
    -- 6.1 Column count must be exactly 11
    SELECT COUNT(*) INTO v_stg_col_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_new_20260917';

    IF v_stg_col_count != 11 THEN
        DROP TABLE `accounting_ledgerentries_new_20260917`;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Staging table column count is not 11. Aborted without touching live table.';
    END IF;

    -- 6.2 Primary key exists on Id
    SELECT COUNT(*) INTO v_stg_pk_count
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_new_20260917'
      AND CONSTRAINT_NAME = 'PRIMARY'
      AND COLUMN_NAME = 'Id';

    IF v_stg_pk_count = 0 THEN
        DROP TABLE `accounting_ledgerentries_new_20260917`;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Staging table missing Primary Key on Id. Aborted without touching live table.';
    END IF;

    -- 6.3 Both Foreign Keys exist and reference parent tables
    SELECT COUNT(DISTINCT LOWER(REFERENCED_TABLE_NAME)) INTO v_stg_fk_count
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_new_20260917'
      AND LOWER(REFERENCED_TABLE_NAME) IN ('accounting_accounts', 'accounting_journaltransactions');

    IF v_stg_fk_count != 2 THEN
        DROP TABLE `accounting_ledgerentries_new_20260917`;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Staging table Foreign Keys to parent tables are missing. Aborted without touching live table.';
    END IF;

    -- 6.4 Row count is 0
    SELECT COUNT(*) INTO v_stg_rows FROM `accounting_ledgerentries_new_20260917`;
    IF v_stg_rows != 0 THEN
        DROP TABLE `accounting_ledgerentries_new_20260917`;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ABORT: Staging table is not empty. Aborted without touching live table.';
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 7: Atomic Staged Swap
    -- -------------------------------------------------------------------------
    IF v_live_exists > 0 THEN
        -- Atomically rename live table to backup, and new table to live
        RENAME TABLE
          `accounting_ledgerentries` TO `accounting_ledgerentries_backup_20260917`,
          `accounting_ledgerentries_new_20260917` TO `accounting_ledgerentries`;
    ELSE
        -- If table did not exist at all, simply rename new to live
        RENAME TABLE
          `accounting_ledgerentries_new_20260917` TO `accounting_ledgerentries`;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 8: Truthful Migration History Synchronization (lowercase)
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = '__efmigrationshistory'
    ) THEN
        INSERT IGNORE INTO `__efmigrationshistory` (`MigrationId`, `ProductVersion`)
        VALUES ('20260917154500_ReconcileAccountingLedgerEntriesSchema', '6.0.12');
    END IF;

    SELECT 'SUCCESS: `accounting_ledgerentries` atomic staged swap completed successfully.' AS Status;
END proc_block $$

DELIMITER ;

-- Execute reconciliation procedure
CALL sp_reconcile_accounting_ledgerentries();

-- Clean up procedure
DROP PROCEDURE IF EXISTS sp_reconcile_accounting_ledgerentries;
