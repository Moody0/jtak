const fs = require('fs');
const path = require('path');

const sqlFile = 'D:\\work\\jtak\\update_production_db.sql';
const content = fs.readFileSync(sqlFile, 'utf8');
const lines = content.split(/\r?\n/);

console.log(`Auditing: ${sqlFile}`);
console.log(`Total Lines: ${lines.length}`);
console.log(`File Size: ${content.length} bytes`);

// 1. Check Transactions
const startTransactions = [];
const commits = [];
const rollbacks = [];

// 2. Check Delimiters & Procedures
let delimiterMode = ';';
let openProcedures = 0;
const procedureReports = [];

// 3. Check EF Migration Insertions vs Checks
const checkedMigrations = new Set();
const insertedMigrations = new Set();

let currentProc = null;
let currentLineNum = 0;

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;
    const trimmed = line.trim();

    if (trimmed.startsWith('--')) continue;

    if (trimmed === 'START TRANSACTION;') {
        startTransactions.push(lineNum);
    } else if (trimmed === 'COMMIT;') {
        commits.push(lineNum);
    } else if (trimmed === 'ROLLBACK;') {
        rollbacks.push(lineNum);
    }

    if (trimmed === 'DELIMITER //') {
        if (delimiterMode !== ';') {
            console.error(`Error line ${lineNum}: Unexpected DELIMITER // when already in ${delimiterMode}`);
        }
        delimiterMode = '//';
    } else if (trimmed === 'DELIMITER ;') {
        if (delimiterMode !== '//') {
            console.error(`Error line ${lineNum}: Unexpected DELIMITER ; when already in ${delimiterMode}`);
        }
        delimiterMode = ';';
    }

    if (trimmed.startsWith('CREATE PROCEDURE MigrationsScript()')) {
        openProcedures++;
        currentProc = { start: lineNum, checks: [], inserts: [] };
    }

    const checkMatch = line.match(/WHERE\s+`MigrationId`\s*=\s*'([^']+)'/i);
    if (checkMatch) {
        checkedMigrations.add(checkMatch[1]);
        if (currentProc) currentProc.checks.push(checkMatch[1]);
    }

    if (line.includes('INSERT INTO `__EFMigrationsHistory`') || line.includes('INSERT INTO __EFMigrationsHistory')) {
        // Look ahead for VALUES
        for (let j = i; j < Math.min(i + 5, lines.length); j++) {
            const valMatch = lines[j].match(/VALUES\s*\(\s*'([^']+)'/i);
            if (valMatch) {
                insertedMigrations.add(valMatch[1]);
                if (currentProc) currentProc.inserts.push(valMatch[1]);
                break;
            }
        }
    }

    if (trimmed === 'END //' || trimmed === 'END//') {
        openProcedures--;
        if (currentProc) {
            currentProc.end = lineNum;
            procedureReports.push(currentProc);
            currentProc = null;
        }
    }
}

console.log('\n--- TRANSACTION INTEGRITY ---');
console.log(`START TRANSACTION count: ${startTransactions.length}`);
console.log(`COMMIT count: ${commits.length}`);
console.log(`ROLLBACK count: ${rollbacks.length}`);
if (startTransactions.length === commits.length && rollbacks.length === 0) {
    console.log('✔ Transaction balance: PERFECT (All transactions cleanly committed).');
} else {
    console.error('❌ Transaction mismatch detected!');
}

console.log('\n--- DELIMITER & PROCEDURE INTEGRITY ---');
console.log(`Final delimiter mode: ${delimiterMode}`);
console.log(`Unclosed procedures: ${openProcedures}`);
console.log(`Total Migration procedures: ${procedureReports.length}`);

console.log('\n--- MIGRATION HISTORY PARITY ---');
console.log(`Unique migrations checked with IF NOT EXISTS: ${checkedMigrations.size}`);
console.log(`Unique migrations recorded in __EFMigrationsHistory: ${insertedMigrations.size}`);

const missingInserts = [...checkedMigrations].filter(m => !insertedMigrations.has(m));
const unCheckedInserts = [...insertedMigrations].filter(m => !checkedMigrations.has(m));

if (missingInserts.length > 0) {
    console.error('❌ Migrations checked but NEVER inserted into __EFMigrationsHistory:');
    missingInserts.forEach(m => console.error(`  - ${m}`));
} else {
    console.log('✔ Every checked migration has a corresponding INSERT INTO __EFMigrationsHistory.');
}

if (unCheckedInserts.length > 0) {
    console.warn('⚠ Migrations inserted without check:', unCheckedInserts);
} else {
    console.log('✔ Every inserted migration was guarded by an IF NOT EXISTS check.');
}

console.log('\n--- ALL REGISTERED MIGRATIONS IN SCRIPT ---');
Array.from(checkedMigrations).forEach((m, idx) => {
    console.log(`  ${(idx + 1).toString().padStart(2, ' ')}. ${m}`);
});
