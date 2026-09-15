$sqlPath = "D:\work\jtak\update_production_db.sql"
$lines = Get-Content $sqlPath

Write-Host "=== TOTAL LINES ==="
Write-Host $lines.Count

Write-Host "`n=== SECTIONS ==="
$lines | Where-Object { $_ -match "^-- SECTION:" }

Write-Host "`n=== MIGRATION IDS IN SCRIPT ==="
$migrations = $lines | Where-Object { $_ -match "MigrationId.*=.*'([^']+)'" } | ForEach-Object {
    if ($_ -match "'([^']+)'") { $matches[1] }
} | Select-Object -Unique
$migrations

Write-Host "`n=== TRANSACTIONS & COMMITS ==="
$trans = $lines | Where-Object { $_ -match "^(START TRANSACTION|COMMIT|ROLLBACK)" }
$trans

Write-Host "`n=== SYNTAX & DELIMITER CHECK ==="
$delims = $lines | Where-Object { $_ -match "DELIMITER" }
Write-Host "Delimiter occurrences: $($delims.Count)"
