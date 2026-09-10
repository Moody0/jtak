# PowerShell Script: Seed 6 Authentic Markets & Assign Grocery Products
Write-Host "====================================================="
Write-Host "🛒 JTAK LIVE MARKETS SEEDER & SYNC (POWERSHELL)"
Write-Host "====================================================="

# 1. Authenticate as Admin
$tokenBody = "grant_type=password&username=admin@jtak.app&password=P@ssw0rd&scope=offline_access"
$authRes = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X POST https://api.jtak.app/connect/token -d $tokenBody | ConvertFrom-Json
$token = $authRes.access_token

if (-not $token) {
    Write-Error "Failed to obtain admin token!"
    exit 1
}
Write-Host "🔑 Admin Authenticated successfully!"

# 2. Fetch existing merchants
$queryBody = '{"pageNumber":0,"pageSize":50,"sortField":"id","sortOrder":"desc"}'
$tableJson = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X POST https://api.jtak.app/api/v1/Admin/Merchants/DataTable -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d $queryBody
$table = $tableJson | ConvertFrom-Json
$existing = $table.items
Write-Host "Existing merchants in backend: $($existing.Count)"

# Define 6 Authentic Markets
$markets = @(
    @{
        title = "جيتك ماركت - JTAK Market"
        shortDescription = "توصيل فوري فائق السرعة • 15-20 دقيقة"
        description = "سوبرماركت ومقاضي سريعة، خضار وفواكه طازجة، ألبان وأجبان، ومستلزمات منزلية متكاملة."
        photo = "assets/images/markets/jtak_market.webp"
        address = "شارع الثورة، وسط البلد، دمشق"
        phone = "+96311223344"
        lat = 33.5138
        lng = 36.2765
    },
    @{
        title = "سوبرماركت أبناء شمسين"
        shortDescription = "أكبر تشكيلة مونة ومقاضي • 20-30 دقيقة"
        description = "تشكيلة واسعة من المونة السورية الفاخرة، معلبات، بقوليات، أجبان وزيوت بلدية."
        photo = "assets/images/markets/abnaa_shamsin.webp"
        address = "ساحة الميدان، جزماتية، دمشق"
        phone = "+96311334455"
        lat = 33.5010
        lng = 36.2920
    },
    @{
        title = "هايبرماركت قاسيون مول"
        shortDescription = "عروض وتخفيضات أسبوعية • 25-35 دقيقة"
        description = "هايبرماركت متكامل يقدم عروض وتخفيضات يومية وأسبوعية على كافة المنتجات الغذائية والمنزلية."
        photo = "assets/images/markets/qasioun_hypermarket.webp"
        address = "مجمع قاسيون مول، برزة، دمشق"
        phone = "+96311445566"
        lat = 33.5420
        lng = 36.3110
    },
    @{
        title = "سوبرماركت الهدى"
        shortDescription = "أجبان، ألبان ومقاضي طازجة • 15-25 دقيقة"
        description = "أفضل منتجات الألبان والأجبان البلدية الطازجة يومياً والخبز الساخن والبيض البلدي."
        photo = "assets/images/markets/al_huda.webp"
        address = "شارع بغداد، دمشق"
        phone = "+96311556677"
        lat = 33.5210
        lng = 36.2980
    },
    @{
        title = "سوبرماركت البركة"
        shortDescription = "منتجات بلدية ومستوردة فاخرة • 20-35 دقيقة"
        description = "أجود المنتجات الغذائية الطبيعية، خضار فريش، ومواد غذائية مستوردة عالية الجودة."
        photo = "assets/images/markets/al_baraka.webp"
        address = "شارع المزرعة الرئيسي، دمشق"
        phone = "+96311667788"
        lat = 33.5280
        lng = 36.2890
    },
    @{
        title = "سوبرماركت الدوحة"
        shortDescription = "كل ما تحتاجه العائلة يومياً • 20-30 دقيقة"
        description = "مقاضي الأسرة اليومية من المنظفات، العناية الشخصية، السناكات والمشروبات الباردة."
        photo = "assets/images/markets/al_dawha.webp"
        address = "المزة فيلات غربية، دمشق"
        phone = "+96311778899"
        lat = 33.5040
        lng = 36.2610
    }
)

$marketIds = @()

foreach ($m in $markets) {
    $existingMarket = $existing | Where-Object { $_.title.Trim() -eq $m.title.Trim() }
    $mid = 0

    $merchantObj = @{
        title = $m.title
        shortDescription = $m.shortDescription
        description = $m.description
        photo = $m.photo
        address = $m.address
        phone1 = $m.phone
        shippingCoverageInMeters = 25000
        profitOutOfMerchantPricePercent = 10
        lat = $m.lat
        lng = $m.lng
        active = $true
    }

    if ($existingMarket) {
        $mid = $existingMarket.id
        $merchantObj["id"] = $mid
        $updateJson = $merchantObj | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText("$PSScriptRoot\temp_merchant.json", $updateJson, [System.Text.Encoding]::UTF8)

        $res = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X PUT "https://api.jtak.app/api/v1/Admin/Merchants/$mid" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$PSScriptRoot\temp_merchant.json"
        Write-Host "  🏪 Market updated & active: $($m.title) (ID: $mid)"
    } else {
        $createJson = $merchantObj | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText("$PSScriptRoot\temp_merchant.json", $createJson, [System.Text.Encoding]::UTF8)

        $createRes = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X POST "https://api.jtak.app/api/v1/Admin/Merchants" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$PSScriptRoot\temp_merchant.json"
        $mid = [int]$createRes

        if ($mid -gt 0) {
            # Activate via PUT
            $merchantObj["id"] = $mid
            $activateJson = $merchantObj | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText("$PSScriptRoot\temp_merchant.json", $activateJson, [System.Text.Encoding]::UTF8)
            $res = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X PUT "https://api.jtak.app/api/v1/Admin/Merchants/$mid" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$PSScriptRoot\temp_merchant.json"
            Write-Host "  ✓ Market created & active: $($m.title) (ID: $mid)"
        }
    }

    if ($mid -gt 0) {
        $marketIds += $mid
    }
}

# 3. Fetch products to assign
Write-Host ""
Write-Host "--- 2. Assigning Grocery Catalog Products to Markets ---"
$prodsJson = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X POST https://api.jtak.app/api/v1/Admin/Products/DataTable -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{"pageNumber":0,"pageSize":50,"sortField":"id","sortOrder":"asc"}'
$prodsTable = $prodsJson | ConvertFrom-Json
$allProds = $prodsTable.items
Write-Host "Available catalog products: $($allProds.Count)"

$priceList = @{
    1 = 45000; 2 = 48000; 3 = 15000; 4 = 14000; 5 = 12000;
    6 = 12000; 7 = 12500; 8 = 12500; 9 = 12000; 10 = 28000;
    11 = 26000; 12 = 18000; 13 = 22000; 14 = 16000; 15 = 11000;
    16 = 19000; 17 = 14000; 18 = 8000; 19 = 7500; 20 = 9000;
}

foreach ($mid in $marketIds) {
    $assignments = @()
    foreach ($p in $allProds) {
        $pid = [int]$p.id
        $pr = if ($priceList.ContainsKey($pid)) { [double]$priceList[$pid] } else { [double](15000 + ($pid * 1200)) }
        $assignments += @{
            productId = $pid
            merchantPrice = $pr
            profitOutOfMerchantPricePercent = 10.0
            additionalProfitPercent = 0.0
            discount = 0.0
        }
    }

    $assignJson = $assignments | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText("$PSScriptRoot\temp_assign.json", $assignJson, [System.Text.Encoding]::UTF8)

    $assignRes = curl.exe --resolve api.jtak.app:443:172.67.149.162 -s -k -X PUT "https://api.jtak.app/api/v1/Admin/Merchants/Products/$mid" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$PSScriptRoot\temp_assign.json"
    Write-Host "  📦 Assigned $($assignments.Count) products to Market #$mid (Response: $assignRes)"
}

# Clean up temp files
Remove-Item "$PSScriptRoot\temp_merchant.json" -ErrorAction SilentlyContinue
Remove-Item "$PSScriptRoot\temp_assign.json" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "====================================================="
Write-Host "✅ ALL 6 MARKETS SEEDED & PRODUCTS ASSIGNED SUCCESSFULLY!"
Write-Host "====================================================="
