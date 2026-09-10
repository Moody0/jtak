param(
    [string]$ExcelPath = "C:\Users\moham\Downloads\Jtak full data.xlsx",
    [string]$OutputPath = "E:\work\jtak\clean_import_data.json"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "1. Opening Excel file: $ExcelPath"
$zip = [System.IO.Compression.ZipFile]::OpenRead($ExcelPath)

# Read sharedStrings
Write-Host "2. Reading shared strings table..."
$ssEntry = $zip.GetEntry('xl/sharedStrings.xml')
$ssStream = $ssEntry.Open()
$ssXml = [xml](New-Object System.IO.StreamReader($ssStream)).ReadToEnd()
$ssStream.Close()
$strings = [System.Collections.Generic.List[string]]::new()
foreach ($si in $ssXml.sst.si) {
    $strings.Add($si.InnerText)
}
Write-Host "Total shared strings loaded: $($strings.Count)"

function Parse-Worksheet($entryPath, $storeName, $merchantId) {
    Write-Host "Parsing $storeName ($entryPath)..."
    $entry = $zip.GetEntry($entryPath)
    if (-not $entry) {
        Write-Error "Entry not found: $entryPath"
        return @()
    }
    $stream = $entry.Open()
    $xml = [xml](New-Object System.IO.StreamReader($stream)).ReadToEnd()
    $stream.Close()

    $items = [System.Collections.Generic.List[object]]::new()
    $rows = $xml.worksheet.sheetData.row

    foreach ($row in $rows) {
        if ($row.r -eq "1") { continue } # Skip header row

        $cells = @{}
        foreach ($c in $row.c) {
            $colLetter = $c.r -replace '\d+', ''
            $val = ""
            if ($c.t -eq "s") {
                $idx = [int]$c.v
                if ($idx -lt $strings.Count) {
                    $val = $strings[$idx]
                }
            } else {
                $val = $c.v
            }
            $cells[$colLetter] = $val
        }

        $titleAr = if ($cells.ContainsKey('D') -and $cells['D']) { $cells['D'].ToString().Trim() } else { "" }
        $titleEn = if ($cells.ContainsKey('E') -and $cells['E']) { $cells['E'].ToString().Trim() } else { "" }
        $mainCat = if ($cells.ContainsKey('B') -and $cells['B']) { $cells['B'].ToString().Trim() } else { "عام" }
        $subCat = if ($cells.ContainsKey('C') -and $cells['C']) { $cells['C'].ToString().Trim() } else { $mainCat }
        $descAr = if ($cells.ContainsKey('F') -and $cells['F']) { $cells['F'].ToString().Trim() } else { "" }
        $descEn = if ($cells.ContainsKey('G') -and $cells['G']) { $cells['G'].ToString().Trim() } else { "" }
        $unit = if ($cells.ContainsKey('J') -and $cells['J']) { $cells['J'].ToString().Trim() } else { "قطعة" }
        $photo = if ($cells.ContainsKey('K') -and $cells['K']) { $cells['K'].ToString().Trim() } else { "" }

        # Skip rows with no title
        if ([string]::IsNullOrWhiteSpace($titleAr) -and [string]::IsNullOrWhiteSpace($titleEn)) {
            continue
        }

        # Fallback titles if one is empty
        if ([string]::IsNullOrWhiteSpace($titleAr)) { $titleAr = $titleEn }
        if ([string]::IsNullOrWhiteSpace($titleEn)) { $titleEn = $titleAr }

        # Parse prices
        $price = 0.0
        if ($cells.ContainsKey('H') -and $cells['H']) {
            [double]::TryParse($cells['H'].ToString(), [ref]$price) | Out-Null
        }
        $origPrice = 0.0
        if ($cells.ContainsKey('I') -and $cells['I']) {
            [double]::TryParse($cells['I'].ToString(), [ref]$origPrice) | Out-Null
        }

        $itemObj = [PSCustomObject]@{
            StoreName = $storeName
            MerchantId = $merchantId
            MainCategory = $mainCat
            SubCategory = $subCat
            TitleAr = $titleAr
            TitleEn = $titleEn
            DescriptionAr = $descAr
            DescriptionEn = $descEn
            PriceUsd = [Math]::Round($price, 4)
            OriginalPriceUsd = [Math]::Round($origPrice, 4)
            Unit = $unit
            PhotoUrl = $photo
        }
        $items.Add($itemObj)
    }

    Write-Host "Parsed $($items.Count) valid items for $storeName."
    return $items
}

$bestMarketItems = Parse-Worksheet 'xl/worksheets/sheet1.xml' 'Best Market' 18
$cloverMallItems = Parse-Worksheet 'xl/worksheets/sheet2.xml' 'Clover Mall' 19

$zip.Dispose()

$exportData = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("o")
    BestMarket = $bestMarketItems
    CloverMall = $cloverMallItems
    TotalCount = ($bestMarketItems.Count + $cloverMallItems.Count)
}

Write-Host "3. Exporting JSON to $OutputPath..."
$json = $exportData | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.Encoding]::UTF8)
Write-Host "Successfully exported $($exportData.TotalCount) items to $OutputPath."
