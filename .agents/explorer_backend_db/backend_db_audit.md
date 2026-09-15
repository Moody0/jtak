# JTAK Ecosystem Audit: Backend & Database Technical Audit Report

**Target Repositories & Assets:**
- Backend API: `D:\work\jtak\jtak-backend-main` (`jtak.sln`)
- Production SQL Scripts: `D:\work\jtak\update_production_db.sql`, `cleanup_duplicate_addresses.sql`, `sql/apply_20260910113000_addMerchantKind.sql`
**Auditor Archetype:** explorer_backend_db (Backend & Database Audit Specialist)
**Audit Date:** 2026-09-13
**Audit Status:** Complete — Read-Only Mode (Zero unauthorized source modifications applied)

---

## Executive Summary

A comprehensive quality, architecture, security, and database integrity audit was conducted on `jtak-backend-main` and all workspace database migration scripts. While the backend solution compiles cleanly under .NET SDK 6.0.428 (0 errors, 0 warnings), deep forensic inspection revealed **critical vulnerabilities, fatal production database schema drift, broken EF Core migrations, missing access controls, and severe credential leaks** that will cause system failures, data corruption, and catastrophic security breaches if deployed to production without remediation.

### Key Headline Findings:
1. **Critical Authentication Backdoor**: A hardcoded master SMS OTP bypass (`"123456"` / `"1234"`) in `OAuthTokenController.cs:214` allows unauthorized login to any account.
2. **Fatal Production Database Schema Incompatibility (`update_production_db.sql`)**: The script contains obsolete/mismatched column definitions across `Catalog_Merchant`, `Catalog_Products`, `Orders_Orders`, `Orders_OrderDetails`, and `Accounting_LedgerEntries`. If imported, inserting orders or running ledger reconciliations throws immediate MySQL runtime exceptions (e.g. unknown column `Debit`, missing `OwnerId`, missing default values for non-existent columns).
3. **Severe Migration Drift & Corrupted Migrations**: EF Core migrations were partially handwritten or generated without `.Designer.cs` metadata or snapshot synchronization (`AddProductBatchesAndReservations.Designer.cs` has an empty model builder; bilingual and USD pricing exist only in an ad-hoc `.sql` script; `OrdersDbContextModelSnapshot` lacks 5 proof-of-delivery columns).
4. **Secret Leaks & Cryptographic Ephemeral Keys**: Live Google Firebase RSA private keys, Twilio credentials, and SendGrid API keys are committed in plaintext. OpenIddict uses ephemeral in-memory signing keys that invalidate all user sessions upon server restarts.
5. **SignalR Security & Broken Endpoints**: `NotificationHub` is disabled in `Startup.cs:252`. `TrackingHub` allows unauthenticated clients to track arbitrary order IDs, and allows any authenticated customer to join the fleet radar dispatch channel.
6. **Insecure Direct Object References (IDOR)**: `Customer/AddressController` allows any user to edit or delete any other customer's saved address. `Warehouse/BatchesController` allows any merchant to view any rival's batch data, supplier lots, and cost prices.

---

## 1. Compiler & Build Verification

### 1.1 SDK and Environment Diagnostics
- **Command Executed**: `dotnet --info`
- **.NET SDK Version**: `6.0.428` (Commit `ef6f5ce48c`)
- **Host Runtime Version**: `Microsoft.NETCore.App 6.0.36`
- **Operating System**: Windows 10 (10.0.19045), RID: `win10-x64`
- **Solution File**: `D:\work\jtak\jtak-backend-main\jtak.sln`

### 1.2 Compilation Outcome
- **Command Executed**: `dotnet build jtak.sln`
- **Status**: Succeeded
- **Errors**: 0
- **Warnings**: 0
- **Build Duration**: 4.13 seconds
- **Compilation Targets Built**:
  - `Modules.Accounting.Entities.dll`
  - `App.Shared.Entities.dll`
  - `Modules.Shipping.Entities.dll`
  - `Modules.Orders.Entities.dll`
  - `Modules.Catalog.Entities.dll`
  - `App.Shared.Data.dll`
  - `Modules.Shipping.Data.dll`
  - `Modules.Accounting.Data.dll`
  - `Modules.Catalog.Data.dll`
  - `Modules.Orders.Data.dll`
  - `App.Shared.Services.dll`
  - `Modules.Accounting.Services.dll`
  - `Modules.Orders.Services.dll`
  - `Modules.Shipping.Services.dll`
  - `Modules.Catalog.Services.dll`
  - `Modules.Accounting.Tests.dll`
  - `App.dll`

### 1.3 Test Suite Diagnostics
- **Command Executed**: `dotnet test jtak.sln`
- **Status**: Passed (Total: 49, Passed: 49, Failed: 0, Skipped: 0)
- **Defect Identified**: Only `Modules.Accounting.Tests` is present in the solution. There is **zero automated test coverage** for the core Web API application (`App`), Catalog module, Orders module, Shipping module, Authentication flow, or SignalR hubs.

### 1.4 Solution Directory & Project Naming Defect
- **File**: `D:\work\jtak\jtak-backend-main\jtak.sln` lines 44-51
- **Observation**: The physical directories `Modules.Shipping.Data`, `Modules.Shipping.Entities`, and `Modules.Shipping.Services` at the solution root actually contain the **Accounting** module (`Modules.Accounting.Data.csproj`, `Modules.Accounting.Entities.csproj`, `Modules.Accounting.Services.csproj`), while the actual Shipping module resides under `Modules\Shipping\...`.
- **Impact**: Confusing project layout causes build script errors and cross-referencing mistakes during maintenance.

---

## 2. Security & Authentication Audit

### Issue SEC-01: Hardcoded Master Backdoor OTP in SMS Grant Flow
- **Severity**: Critical (CVSS 9.8)
- **File**: `app/ApiControllers/V1/Authorization/OAuthTokenController.cs`
- **Lines**: 214–216
- **Verbatim Code**:
  ```csharp
  var isMasterTestCode = request.Code == "123456" || request.Code == "1234";
  var isCodeValid = isMasterTestCode || request.Username.Contains("+90555555555");
  ```
- **Root Cause**: Hardcoded developer test credentials were left in production authentication paths.
- **Impact**: Any attacker can authenticate as ANY user on the platform (including admin, delivery captain, or merchant) simply by supplying their phone number and entering `"123456"` or `"1234"`. No SMS OTP is dispatched or verified.
- **Remediation**: Remove `isMasterTestCode` and the `+90555555555` bypass completely from production code. Wrap testing overrides in `#if DEBUG` with strict environment variable guards if needed in staging.

### Issue SEC-02: Secret Leakage — Live Google Cloud Service Account RSA Private Key
- **Severity**: Critical (CVSS 9.8)
- **File**: `app/jtak-339412-firebase-adminsdk-fyug6-170c77def3.json`
- **Lines**: 1–13
- **Observation**: A production Google Cloud / Firebase Admin SDK Service Account JSON file containing an active 2048-bit RSA Private Key (`client_email`: `firebase-adminsdk-fyug6@jtak-339412.iam.gserviceaccount.com`, `private_key_id`: `170c77def3c53d7eea8838f4fe90b894fb184bf1`) is committed directly in the application directory.
- **Impact**: Full administrative compromise of Firebase project `jtak-339412`, enabling push notification spoofing, Firebase database manipulation, and cloud asset compromise.
- **Remediation**: Immediately revoke the service account key in the Google Cloud Console. Regenerate a new key, add `*firebase-adminsdk*.json` to `.gitignore`, and inject the credentials via environment variables or secret vaults (e.g. Azure Key Vault / AWS Secrets Manager).

### Issue SEC-03: Hardcoded Third-Party API Secrets & Unencrypted Database Connection
- **Severity**: Critical (CVSS 9.1)
- **File**: `app/appsettings.json`
- **Lines**: 7–11, 41–43, 49, 58
- **Verbatim Code**:
  ```json
  "DefaultConnection": "Server=localhost; Database=jtak_db; Uid=jtak_db; Pwd=O255hm_3y; SslMode=None;",
  "TwilioAccountSid": "AC3e324745a2541a9c9d912bb61158537a",
  "TwilioAuthToken": "10b0da0070d5af233fa4851f75ae5814",
  "SendGridKey": "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",
  "SmtpPassword": "_K3u1bj9"
  ```
- **Impact**: Live API keys for Twilio, SendGrid, and SMTP are publicly accessible in git history. Furthermore, `SslMode=None` causes database communication to travel unencrypted in plaintext across the internal network.
- **Remediation**: Revoke and rotate all leaked API keys. Externalize configuration via environment variables. Enable `SslMode=Preferred` or `SslMode=Required`.

### Issue SEC-04: Ephemeral In-Memory Signing Keys & 180-Day Token Lifespan
- **Severity**: High (CVSS 7.5)
- **File**: `app/Helpers/StartUp/OpenIddictHelper.cs`
- **Lines**: 110, 141–143
- **Verbatim Code**:
  ```csharp
  options.SetAccessTokenLifetime(TimeSpan.FromDays(180));
  ...
  options.AddEphemeralEncryptionKey();
  options.AddEphemeralSigningKey();
  ```
- **Root Cause**: Certificate registration code was commented out due to IIS permission difficulties (lines 123–140), falling back to ephemeral keys.
- **Impact**:
  1. Every application pool recycle or server restart destroys the encryption and signing keys, immediately invalidating every active session across mobile and web clients (users are logged out unexpectedly).
  2. In multi-instance or load-balanced deployments, tokens issued by one instance fail validation on others.
  3. A token lifetime of 180 days without short-lived access tokens and token revocation creates severe exposure if an access token is intercepted.
- **Remediation**: Implement a persistent asymmetric X.509 certificate or store RSA keys in a shared Key Vault / Data Protection store. Reduce access token lifetime to 15–60 minutes, using refresh tokens for renewal.

### Issue SEC-05: Prohibited CORS Wildcard with Credentials
- **Severity**: High (CVSS 7.4)
- **File**: `app/Helpers/StartUp/CorsHelper.cs`
- **Lines**: 15–25
- **Verbatim Code**:
  ```csharp
  builder.AllowCredentials()
         .WithOrigins("*",
         "https://localhost:5001",
         "https://localhost:4200",
         "http://localhost:4200",
         AppDomainHelper.BaseUrl,
         AppDomainHelper.DashboardUrl)
         .SetIsOriginAllowedToAllowWildcardSubdomains()
         .AllowAnyHeader()
         .AllowCredentials()
         .AllowAnyMethod();
  ```
- **Root Cause**: Combining `WithOrigins("*")` with `AllowCredentials()`.
- **Impact**: Under W3C CORS specifications and ASP.NET Core runtime validation, wildcard origins with credentials are explicitly prohibited and throw `InvalidOperationException` at runtime or expose authenticated endpoints to cross-site credential reflection attacks.
- **Remediation**: Remove `"*"` from `WithOrigins()`. Explicitly declare trusted production domains (e.g. `https://jtak.app`, `https://dash.jtak.app`).

### Issue SEC-06: Production Exception Stack Trace & Schema Leakage
- **Severity**: Medium (CVSS 5.3)
- **File**: `app/Helpers/ExceptionMiddleware.cs`
- **Lines**: 51–54
- **Verbatim Code**:
  ```csharp
  var response = _env.IsDevelopment()
      ? ApiErr.Create(ex)
      : ApiErr.Create(ex);// ApiErr.Create(_Errors.ErrorTryLater);
  ```
- **Observation**: In production environments, raw exception messages (`ex.Message`), which include internal database errors, table names, and query failures, are returned to the client. Additionally, `OAuthTokenController.cs:347` executes `Forbid("ForbidException: " + e, ...)` which dumps raw exception stack traces into token response bodies.
- **Remediation**: In production, return sanitized generic error messages (`ApiErr.Create(_Errors.ErrorTryLater)`), while logging detailed exceptions internally to Serilog / Application Insights.

---

## 3. API Controllers & Endpoints Audit

### Issue API-01: Insecure Direct Object Reference (IDOR) on Customer Addresses
- **Severity**: Critical (CVSS 8.5)
- **File**: `app/ApiControllers/V1/Customer/AddressController.cs`
- **Lines**: 102–146
- **Observation**:
  - `Edit(int id, AddressDto model)` loads `_service.FindAsync(id)` and updates address fields without validating that `entity.UserId == User.GetUserId()`.
  - `Delete(int id)` executes `_service.DeleteAsync(id)` with zero ownership check.
- **Impact**: Any customer can overwrite or delete the home/work address, coordinates, and personal details of any other customer on the platform by guessing or iterating address IDs.
- **Remediation**: Add ownership verification:
  ```csharp
  if (entity.UserId != uid.Value) return Forbid();
  ```

### Issue API-02: Insecure Direct Object Reference (IDOR) on Warehouse Batches
- **Severity**: High (CVSS 7.5)
- **File**: `app/ApiControllers/V1/Warehouse/Catalog/BatchesController.cs`
- **Lines**: 98–103
- **Observation**: `GetById(int id)` fetches batch details directly from `_batchService.GetBatchByIdAsync(id)` without verifying that `batch.MerchantId` belongs to the requesting merchant.
- **Impact**: A merchant can query any batch ID in the system to view competitors' purchase cost prices (`CostPrice`), stock levels, lot numbers, and expiration dates.
- **Remediation**: Check `merchantIds.Contains(batch.MerchantId)` before returning batch details.

### Issue API-03: Missing RBAC Policy on Warehouse Controllers
- **Severity**: High (CVSS 7.2)
- **Files**:
  - `app/ApiControllers/V1/Warehouse/Catalog/BatchesController.cs:20`
  - `app/ApiControllers/V1/Warehouse/Catalog/ProductsController.cs:26`
- **Observation**: Both controllers use bare `[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]` without specifying `Policy = nameof(AppPermissionKey.MerchantPermission)`.
- **Impact**: Any authenticated Customer or Delivery user can call Warehouse batch management and inventory adjustment APIs.
- **Remediation**: Apply `Policy = nameof(AppPermissionKey.MerchantPermission)` to all Warehouse controllers.

### Issue API-04: Conflicting Anonymous Attribute & NullReferenceException
- **Severity**: High (CVSS 6.5)
- **File**: `app/ApiControllers/V1/NotificationsController.cs`
- **Lines**: 39–46
- **Verbatim Code**:
  ```csharp
  [HttpGet]
  [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
  [AllowAnonymous]
  [Route("{page}")]
  public async Task<ActionResult<NotificationMessageDto[]>> GetNotifications(int page = 0)
  {
      var user = await _userManager.GetUserAsync(User);
      var notifications = (await _notificationService.GetNotifications(user.Id))
  ```
- **Observation**: `[AllowAnonymous]` overrides `[Authorize]`. If an unauthenticated user requests `GET /api/v1/Notifications/0`, `user` is `null`, causing `user.Id` to throw a `NullReferenceException` immediately.
- **Remediation**: Remove `[AllowAnonymous]`.

### Issue API-05: Missing File on Firebase Notification Endpoints
- **Severity**: High (CVSS 6.5)
- **File**: `app/ApiControllers/V1/NotificationsController.cs`
- **Lines**: 97, 122
- **Verbatim Code**:
  ```csharp
  string path = _env.ContentRootPath + "/rightbite-4e059-firebase-adminsdk-8hcrm-eb184d3cf3.json";
  ```
- **Observation**: The hardcoded file `rightbite-4e059-firebase-adminsdk-8hcrm-eb184d3cf3.json` does not exist on disk. Calling `Subscribe` or `Unsubscribe` throws `FileNotFoundException`.
- **Remediation**: Point to the correct Firebase options service or configuration setting.

### Issue API-06: Unrestricted File Upload & Path Traversal
- **Severity**: High (CVSS 7.5)
- **File**: `app/ApiControllers/V1/ServicesController.cs`
- **Lines**: 41–50, 80–100, 112–140
- **Observation**:
  1. `SaveUploaded`: Does not restrict file extensions, MIME types, or payload sizes.
  2. `Play`: Directly concatenates user input `fileName` into physical paths without path sanitization (`$"{_env.ContentRootPath}\\Streaming\\{id}\\{fileName}"`), creating Directory Traversal risk.
  3. `PreviewImageApi`: Accepts unbounded `w` and `h` query parameters. Requesting `?w=50000&h=50000` causes huge image memory allocation and disk-filling DoS.
- **Remediation**: Enforce strict file extension allowlists, sanitize `fileName` with `Path.GetFileName()`, and clamp image dimensions (`Math.Clamp(w, 16, 2048)`).

### Issue API-07: Pending Cart Reuse Data Accumulation
- **Severity**: Medium (CVSS 5.3)
- **File**: `app/ApiControllers/V1/Customer/Orders/CartController.cs`
- **Lines**: 140–163
- **Observation**: When an existing pending cart is reused (`cart = await _orderService.Queryable().FirstOrDefaultAsync(x => x.UserId == user.Id && x.OrderStatus == OrderStatus.Pending)`), new `orderDetails` are inserted without deleting prior order details from that cart.
- **Impact**: Items from abandoned previous sessions reappear on the new order, charging customers for items they didn't currently select.
- **Remediation**: Delete or replace existing `OrderDetails` for the cart before inserting new ones.

### Issue API-08: Extreme Memory Inefficiency in Merchant Products Endpoint
- **Severity**: Medium (CVSS 5.0)
- **File**: `app/ApiControllers/V1/Customer/Catalog/ProductsController.cs`
- **Lines**: 128–172
- **Observation**: `GetMerchantProducts(int mid)` executes `_service.Queryable()...ToArrayAsync()`, loading **all active products in the entire database** into server memory, before filtering for `mid` in a C# `foreach` loop.
- **Impact**: In a catalog of 20,000+ items, every customer opening a store triggers a massive query that exhausts backend RAM and causes server lag.
- **Remediation**: Filter at the database level:
  ```csharp
  .Where(x => x.MerchantProducts.Any(mp => mp.MerchantId == mid && mp.IsActive))
  ```

### Issue API-09: Complete Absence of Rate Limiting
- **Severity**: Medium (CVSS 5.3)
- **Observation**: No rate-limiting middleware is configured anywhere in the pipeline.
- **Impact**: SMS OTP brute force, inventory scraping, and order submission denial-of-service are trivial to execute against the API.
- **Remediation**: Integrate ASP.NET Core Rate Limiting middleware with token bucket / fixed window policies on auth, cart, and location endpoints.

---

## 4. Database Schema, Migrations & Data Integrity Audit

### Issue DB-01: Catastrophic Schema Drift in Production Script `update_production_db.sql`
- **Severity**: Critical (CVSS 9.3)
- **File**: `D:\work\jtak\update_production_db.sql`
- **Analysis**: A detailed comparison between the table schemas in `update_production_db.sql` and the Entity Framework Core entity classes revealed fatal discrepancies across multiple core tables:

| Table Name | `update_production_db.sql` Definition | EF Core Entity (`C#` Source) | Runtime Consequence |
|---|---|---|---|
| `Catalog_Merchant` | `UserId VARCHAR(36)` | `OwnerId Guid` | `Unknown column 'm.OwnerId' in 'field list'` on any merchant query/insert. |
| `Catalog_Merchant` | Missing `DeletionDate`, `DeletedBy` | Inherits `SoftDeleteEntity` | EF Core soft-delete filter `WHERE DeletionDate IS NULL` crashes immediately. |
| `Catalog_Merchant` | `IsActive`, `FullAddress`, `PhoneNumber`, `IBANTitle`, `IBAN` | `Active`, `Address`, `Phone1`, `Phone2`, `IBAN1Title`, `IBAN1` | Mismatched column names cause mapping failures. |
| `Catalog_Products` | `IsActive`, `Photo`, `ProductUnit INT`, `ShortDescription`, `IsHome` | `Active`, `Photos`, `Unit VARCHAR`, `Currency` | Unknown column queries and data truncation. |
| `Catalog_Products` | Missing `DeletionDate`, `DeletedBy` | Inherits `SoftDeleteEntity` | Soft delete queries fail. |
| `Catalog_Products` | `ProductCategoryId INT NOT NULL` | `int? ProductCategoryId` (nullable) | Null category products fail with NOT NULL constraint violation. |
| `Catalog_MerchantProduct` | `IsActive TINYINT(1) NOT NULL` (no default) | Property does not exist on entity | In MySQL strict mode, inserting merchant product throws missing default value error. |
| `Orders_Orders` | `PurchaseDate NOT NULL`, `ShippingCost NOT NULL`, `ShippingMethod NOT NULL`, `PaymentStatus NOT NULL` | `PurchaseDate?` (nullable); `ShippingCost`, `ShippingMethod`, `PaymentStatus` DO NOT EXIST on `Order.cs` | Inserting an order fails with `Field 'ShippingCost' doesn't have a default value`. |
| `Orders_OrderDetails` | `Count INT NOT NULL`, `SingleMerchantPrice NOT NULL`, `SingleProfitOutOfMerchantPricePercent NOT NULL` | `Quantity INT`; prices are `SinglePrice`, `SingleFinalPrice`, `SingleMerchantProfit` | Inserting order details fails; column `Quantity` missing. |
| `Accounting_LedgerEntries` | `Id CHAR(36) NOT NULL`, `EntryType INT`, `Amount DECIMAL`, `Sequence INT` | `Id BIGINT AUTO_INCREMENT`, `Debit DECIMAL`, `Credit DECIMAL`, `Memo VARCHAR` | `LedgerService` queries `Debit`/`Credit`, causing fatal SQL crash on every double-entry posting! |

- **Root Cause**: `update_production_db.sql` was assembled from legacy scripts or disparate prototype schemas and was never verified against actual EF Core models.
- **Remediation**: Completely regenerate `update_production_db.sql` using idempotent EF Core migration scripts generated directly from the current DbContexts (`dotnet ef migrations script --idempotent`).

### Issue DB-02: Ghost EF Core Migration Registration in `update_production_db.sql`
- **Severity**: Critical (CVSS 9.0)
- **File**: `D:\work\jtak\update_production_db.sql` lines 1040–1081
- **Observation**: The script executes `INSERT IGNORE INTO __EFMigrationsHistory` for all 32 migrations (including `20260911120259_AddDoubleEntryLedgerTables`), while simultaneously creating tables with incompatible schemas!
- **Impact**: Because the migrations are marked as already applied in `__EFMigrationsHistory`, running `Database.Migrate()` on startup will NEVER run the actual EF migrations that would create the correct columns (`Debit`, `Credit`, etc.), permanently locking the database in a broken state.
- **Remediation**: Do not manually fabricate `__EFMigrationsHistory` records for migrations whose true DDL was not executed.

### Issue DB-03: Silent Migration Swallowing in Application Startup
- **Severity**: High (CVSS 7.5)
- **File**: `app/Startup.cs`
- **Lines**: 219–224
- **Verbatim Code**:
  ```csharp
  try { serviceScope.ServiceProvider.GetService<AppDbContext>()?.Database.Migrate(); } catch { }
  try { serviceScope.ServiceProvider.GetService<CatalogDbContext>()?.Database.Migrate(); } catch { }
  try { serviceScope.ServiceProvider.GetService<OrdersDbContext>()?.Database.Migrate(); } catch { }
  try { serviceScope.ServiceProvider.GetService<AccountingDbContext>()?.Database.Migrate(); } catch { }
  try { serviceScope.ServiceProvider.GetService<ShippingDbContext>()?.Database.Migrate(); } catch { }
  ```
- **Impact**: If any database migration fails (due to connection loss, syntax errors, or table locks), the exception is completely swallowed silently without logging. The application continues running with an incomplete database schema, causing cryptic runtime errors later.
- **Remediation**: Log exceptions with `ILogger` and abort startup (`throw`) if essential database migrations fail.

### Issue DB-04: Incomplete & Designer-Less Migrations
- **Severity**: High (CVSS 7.2)
- **Files**:
  - `Modules/Catalog/.../20260911160000_AddProductBatchesAndReservations.Designer.cs`: Lines 18–20 have an empty `BuildTargetModel`.
  - `Modules/Orders/.../20260909150000_addDeliveryLiveLocation.cs`: Missing `.Designer.cs`.
  - `Modules/Orders/.../20260911170000_AddOrderProofOfDeliveryAndOtp.cs`: Missing `.Designer.cs`.
  - `Modules/Shipping/.../20260911170000_AddShippingStopDetails.cs`: Missing `.Designer.cs`.
  - `Modules/Orders/.../OrdersDbContextModelSnapshot.cs`: Missing `DeliveryOtp`, `DeliveredAt`, `ProofOfDeliverySignature`, `ProofOfDeliveryPhotoUrl`, and `DeliveryNotes`.
  - `Modules/Shipping/.../ShippingDbContextModelSnapshot.cs`: Missing `StopType`, `StopTitle`, `IsDarkStore`, `VerificationCode`, and `Notes`.
- **Impact**: When new migrations are added via EF Core CLI, EF Core uses the ModelSnapshot. Because the snapshots lack these recent columns, EF will generate redundant or conflicting migrations.
- **Remediation**: Run `dotnet ef migrations add` properly to update the model snapshots and generate valid designer metadata.

### Issue DB-05: Missing EF Migration for Bilingual & USD Pricing
- **Severity**: Medium (CVSS 6.0)
- **File**: `Modules/Catalog/.../Add_Bilingual_And_Usd_Pricing.sql`
- **Observation**: `TitleEn`, `DescriptionEn` (on `Product.cs`) and `OriginalPrice` (on `MerchantProduct.cs`) exist in C# entity classes and in an ad-hoc `.sql` script, but **NO corresponding C# EF Core migration was ever created**.
- **Impact**: Any environment deployed using standard EF Core migrations lacks these columns, causing queries selecting `Product.TitleEn` to fail.
- **Remediation**: Create a formal EF Core migration `AddBilingualAndUsdPricing` that adds these columns and updates `CatalogDbContextModelSnapshot.cs`.

### Issue DB-06: Defective Address Cleanup Script (`cleanup_duplicate_addresses.sql`)
- **Severity**: Medium (CVSS 5.0)
- **File**: `D:\work\jtak\cleanup_duplicate_addresses.sql`
- **Lines**: 7–12
- **Observation**:
  ```sql
  DELETE a1 FROM `Addresses` a1
  INNER JOIN `Addresses` a2 
  WHERE a1.`Id` > a2.`Id` 
    AND a1.`UserId` = a2.`UserId` 
    AND COALESCE(a1.`Title`, '') = COALESCE(a2.`Title`, '') 
    AND COALESCE(a1.`FullAddress`, '') = COALESCE(a2.`FullAddress`, '');
  ```
- **Impact**: `WHERE a1.Id > a2.Id` deletes `a1` (the newer record) and retains `a2` (the older record). If the customer recently updated their GPS coordinates or apartment details on the newer address, this script deletes the updated address and retains the stale address without coordinates.
- **Remediation**: Change condition to `WHERE a1.Id < a2.Id` to preserve the latest record, or verify whether `Lng` and `Lat` are non-null before deletion.

### Issue DB-07: Total Absence of Optimistic Concurrency Control
- **Severity**: High (CVSS 7.0)
- **Observation**: None of the core business entities (`Order`, `OrderDetail`, `ProductBatch`, `BatchReservation`, `Account`, `Balance`) have a concurrency token (`[Timestamp]`, `byte[] RowVersion`, or `[ConcurrencyCheck]`).
- **Impact**:
  1. If two customers place orders for the last remaining stock of an item simultaneously, both read `QuantityOnHand = 1`, resulting in overselling.
  2. If an admin assigns a delivery driver while another merchant changes order items, the last write overwrites without conflict detection.
- **Remediation**: Add `byte[] RowVersion { get; set; }` with `[Timestamp]` to `ProductBatch`, `Order`, and `Balance`.

---

## 5. Real-time Communication & SignalR Hubs Audit

### Issue HUB-01: `NotificationHub` Endpoint Disabled in Configuration
- **Severity**: High (CVSS 7.1)
- **File**: `app/Startup.cs`
- **Line**: 252
- **Verbatim Code**:
  ```csharp
  //endpoints.MapHub<NotificationHub>("/chat");
  endpoints.MapHub<App.Shared.Services.Hubs.TrackingHub>("/hubs/tracking");
  ```
- **Observation**: `NotificationService` actively injects `IHubContext<NotificationHub>` to push notifications via SignalR (`_nHubContext.Clients.User(...).SendAsync(...)`). However, because the endpoint is commented out in `Startup.cs`, no client can ever connect to `NotificationHub`.
- **Remediation**: Uncomment and properly map `endpoints.MapHub<NotificationHub>("/hubs/notifications")`.

### Issue HUB-02: Unauthenticated Order Tracking & Radar Eavesdropping in `TrackingHub`
- **Severity**: Critical (CVSS 8.2)
- **File**: `app.Services/Hubs/TrackingHub.cs`
- **Lines**: 13–27
- **Verbatim Code**:
  ```csharp
  public async Task JoinOrderTracking(int orderId)
  {
      await Groups.AddToGroupAsync(Context.ConnectionId, $"order_{orderId}");
  }

  [Authorize]
  public async Task JoinFleetRadar()
  {
      await Groups.AddToGroupAsync(Context.ConnectionId, FleetDispatchGroup);
  }
  ```
- **Observation**:
  1. `JoinOrderTracking(int orderId)` has NO `[Authorize]` attribute and NO ownership check. Any unauthenticated anonymous websocket client can join `order_{orderId}` and stream real-time driver coordinates and delivery events.
  2. `JoinFleetRadar()` has bare `[Authorize]` without any role restriction. Any authenticated customer can join `FleetDispatchGroup` (`fleet_dispatch`) and receive real-time location broadcasts for ALL delivery drivers across the entire platform.
- **Remediation**:
  1. Add `[Authorize]` to `JoinOrderTracking` and verify that the calling `UserId` is the customer who placed the order, the merchant, the assigned courier, or an admin.
  2. Require `[Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]` on `JoinFleetRadar`.

### Issue HUB-03: Blocking Database Query in `NotificationHub.OnConnectedAsync`
- **Severity**: Medium (CVSS 5.0)
- **File**: `app.Services/Hubs/NotificationHub.cs`
- **Lines**: 43–48
- **Observation**: Calling `.ToList()` synchronously inside `OnConnectedAsync` executes a blocking database query on the thread pool during connection negotiation. Additionally, line 58 hardcodes removing the connection from `"YOS TEK Group"` which does not match the default notification group.
- **Remediation**: Use `await ToListAsync()` and fix group name consistency.

---

## 6. Prohibited Terminology Compliance

- **Rule**: Strict prohibition of the word "أسطول" anywhere in code, UI strings, and comments.
- **Scan Result**: A global regex search across all files in `D:\work\jtak` returned **0 matches**.
- **Status**: **PASS (100% Compliant)**.

---

## 7. Comprehensive Defect & Remediation Catalog

| ID | Area | Severity | File Reference | Root Cause | Concrete Fix Proposal |
|---|---|---|---|---|---|
| **SEC-01** | Auth | **Critical** | `OAuthTokenController.cs:214` | Hardcoded bypass `123456`/`1234` | Remove `isMasterTestCode` and require genuine OTP validation. |
| **SEC-02** | Security | **Critical** | `app/*firebase-adminsdk*.json` | Live GCP RSA key committed in git | Revoke key in GCP console; inject via environment variables. |
| **SEC-03** | Security | **Critical** | `appsettings.json:7-58` | Third-party secrets in config file | Rotate Twilio/SendGrid/DB secrets; use Secret Manager. |
| **DB-01** | Database | **Critical** | `update_production_db.sql:443-860` | Massive schema drift vs EF Core entities | Regenerate idempotent script using `dotnet ef migrations script`. |
| **DB-02** | Database | **Critical** | `update_production_db.sql:1040` | Fake `__EFMigrationsHistory` records | Remove manual inserts for migrations whose true DDL was not run. |
| **API-01** | API | **Critical** | `AddressController.cs:102-146` | IDOR on address edit and delete | Verify `entity.UserId == User.GetUserId()`. |
| **HUB-02** | SignalR | **Critical** | `TrackingHub.cs:13-27` | Unauthenticated order tracking & open radar | Require auth & role verification on tracking groups. |
| **SEC-04** | Auth | **High** | `OpenIddictHelper.cs:110-143` | Ephemeral keys & 180-day token lifetime | Use persistent X.509 certificate and reduce lifetime to 30 min. |
| **SEC-05** | Security | **High** | `CorsHelper.cs:15-25` | Wildcard CORS origin with `AllowCredentials` | Remove `"*"`; specify exact production origins. |
| **DB-03** | Database | **High** | `Startup.cs:219-224` | Migration exceptions swallowed in `catch {}` | Log exceptions and halt startup on migration failure. |
| **DB-04** | Database | **High** | Multiple Migration files & Snapshots | Missing `.Designer.cs` and outdated snapshots | Run `dotnet ef migrations add` to regenerate snapshots and metadata. |
| **DB-07** | Database | **High** | Entity Models | Zero concurrency tokens on mutable entities | Add `byte[] RowVersion` with `[Timestamp]` to `Order` and `ProductBatch`. |
| **API-02** | API | **High** | `BatchesController.cs:98-103` | IDOR on batch details inspection | Verify requesting merchant owns the batch. |
| **API-03** | API | **High** | `Warehouse/*Controllers.cs` | Bare `[Authorize]` without Merchant policy | Add `Policy = nameof(AppPermissionKey.MerchantPermission)`. |
| **API-04** | API | **High** | `NotificationsController.cs:39-46` | `[AllowAnonymous]` causes NRE on `user.Id` | Remove `[AllowAnonymous]` from user notifications endpoint. |
| **API-05** | API | **High** | `NotificationsController.cs:97` | Non-existent Firebase config filename | Point to active Firebase options/credentials. |
| **API-06** | API | **High** | `ServicesController.cs:41-140` | Unrestricted upload, path traversal, unbounded resize | Add file extension allowlist, sanitize paths, clamp resize dimensions. |
| **HUB-01** | SignalR | **High** | `Startup.cs:252` | `NotificationHub` endpoint commented out | Uncomment and map endpoint `/hubs/notifications`. |
| **SEC-06** | Security | **Medium** | `ExceptionMiddleware.cs:51-54` | Production leaks exception stack traces | Return sanitized generic message in production mode. |
| **API-07** | API | **Medium** | `CartController.cs:140-163` | Stale cart details accumulate on submit | Clear previous pending items before saving new cart details. |
| **API-08** | API | **Medium** | `Customer/ProductsController.cs:128` | Full catalog loaded in RAM before filtering | Filter by `MerchantId` in database query (`.Where(mp.MerchantId == mid)`). |
| **API-09** | API | **Medium** | Global Pipeline | No rate limiting configured | Implement ASP.NET Core rate limiting on public and auth endpoints. |
| **DB-05** | Database | **Medium** | Catalog Migrations | Bilingual & USD pricing not in EF migrations | Create official EF Core migration for `TitleEn`, `DescriptionEn`, `OriginalPrice`. |
| **DB-06** | Database | **Medium** | `cleanup_duplicate_addresses.sql` | Deletes newer address instead of older duplicate | Preserve latest updated address (`WHERE a1.Id < a2.Id`). |
| **HUB-03** | SignalR | **Medium** | `NotificationHub.cs:43-58` | Synchronous blocking DB query in hub connection | Change `.ToList()` to `await ToListAsync()`. |
