using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Modules.Accounting.Data.Migrations
{
    public partial class ReconcileAccountingLedgerEntriesSchema : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Raw SQL reconciliation using safe atomic staged swap with production collation and casing
            migrationBuilder.Sql(@"
                DELIMITER $$
                DROP PROCEDURE IF EXISTS sp_reconcile_migration_ledgerentries $$
                CREATE PROCEDURE sp_reconcile_migration_ledgerentries()
                proc_block: BEGIN
                    DECLARE v_credit_exists INT DEFAULT 0;
                    DECLARE v_row_count INT DEFAULT 0;
                    DECLARE v_stg_col_count INT DEFAULT 0;

                    SELECT COUNT(*) INTO v_credit_exists
                    FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND LOWER(TABLE_NAME) = 'accounting_ledgerentries'
                      AND LOWER(COLUMN_NAME) = 'credit';

                    IF v_credit_exists = 0 THEN
                        IF EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = 'accounting_ledgerentries') THEN
                            SELECT COUNT(*) INTO v_row_count FROM `accounting_ledgerentries`;
                            IF v_row_count > 0 THEN
                                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ABORT: accounting_ledgerentries contains rows (> 0). Refusing to replace table.';
                            END IF;
                        END IF;

                        -- Create staging table first with exact production FK collation
                        DROP TABLE IF EXISTS `accounting_ledgerentries_new_20260917`;
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

                        -- Validate staging table
                        SELECT COUNT(*) INTO v_stg_col_count
                        FROM information_schema.COLUMNS
                        WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_new_20260917';

                        IF v_stg_col_count != 11 THEN
                            DROP TABLE `accounting_ledgerentries_new_20260917`;
                            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ABORT: Staging table validation failed.';
                        END IF;

                        -- Atomic swap
                        IF EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = 'accounting_ledgerentries') THEN
                            RENAME TABLE
                              `accounting_ledgerentries` TO `accounting_ledgerentries_backup_20260917`,
                              `accounting_ledgerentries_new_20260917` TO `accounting_ledgerentries`;
                        ELSE
                            RENAME TABLE
                              `accounting_ledgerentries_new_20260917` TO `accounting_ledgerentries`;
                        END IF;
                    END IF;
                END proc_block $$
                DELIMITER ;
                CALL sp_reconcile_migration_ledgerentries();
                DROP PROCEDURE IF EXISTS sp_reconcile_migration_ledgerentries;
            ", suppressTransaction: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                DELIMITER $$
                DROP PROCEDURE IF EXISTS sp_rollback_migration_ledgerentries $$
                CREATE PROCEDURE sp_rollback_migration_ledgerentries()
                proc_block: BEGIN
                    IF EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = 'accounting_ledgerentries_backup_20260917') THEN
                        RENAME TABLE
                          `accounting_ledgerentries` TO `accounting_ledgerentries_quarantine_20260917`,
                          `accounting_ledgerentries_backup_20260917` TO `accounting_ledgerentries`;
                    END IF;
                END proc_block $$
                DELIMITER ;
                CALL sp_rollback_migration_ledgerentries();
                DROP PROCEDURE IF EXISTS sp_rollback_migration_ledgerentries;
            ", suppressTransaction: true);
        }
    }
}
