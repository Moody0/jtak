const fs = require('fs');
const path = require('path');

const backendRoot = 'D:\\work\\jtak\\jtak-backend-main';
const sqlFile = 'D:\\work\\jtak\\update_production_db.sql';

// 1. Get migrations from SQL
const sqlContent = fs.readFileSync(sqlFile, 'utf8');
const sqlMigrations = new Set();
const checkRegex = /WHERE\s+`MigrationId`\s*=\s*'([^']+)'/gi;
let match;
while ((match = checkRegex.exec(sqlContent)) !== null) {
    sqlMigrations.add(match[1]);
}

// 2. Scan backend migration files
function getFiles(dir, filter) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
            if (file !== 'bin' && file !== 'obj' && file !== '.git') {
                results = results.concat(getFiles(fullPath, filter));
            }
        } else if (filter(fullPath)) {
            results.push(fullPath);
        }
    });
    return results;
}

const migrationFiles = getFiles(backendRoot, f => f.includes('Migrations') && f.endsWith('.cs') && !f.endsWith('.Designer.cs') && !f.endsWith('ModelSnapshot.cs'));
const backendMigrations = new Set();

migrationFiles.forEach(f => {
    const base = path.basename(f, '.cs');
    backendMigrations.add(base);
});

console.log('=== PARITY CHECK: BACKEND EF CORE vs UPDATE_PRODUCTION_DB.SQL ===');
console.log(`Backend EF Core migrations found: ${backendMigrations.size}`);
console.log(`SQL script migrations found: ${sqlMigrations.size}`);

const missingInSql = [...backendMigrations].filter(m => !sqlMigrations.has(m));
const extraInSql = [...sqlMigrations].filter(m => !backendMigrations.has(m));

console.log(`\nMissing in SQL (${missingInSql.length}):`);
missingInSql.forEach(m => console.log(`  - ${m}`));

console.log(`\nExtra in SQL (${extraInSql.length}):`);
extraInSql.forEach(m => console.log(`  - ${m}`));

if (missingInSql.length === 0 && extraInSql.length === 0) {
    console.log('\n✔ 100% PERFECT 1:1 MATCH BETWEEN BACKEND EF CORE MIGRATIONS AND UPDATE_PRODUCTION_DB.SQL!');
} else {
    console.log('\n❌ Discrepancies found!');
}
