# JTAK Pre-Production Quality, Security & Ecosystem Audit Report

**Date**: 2026-09-13  
**Audit Scope**:
1. Backend API (`jtak-backend-main`)
2. Admin Dashboard (`jtak-dashboard-main`)
3. Customer Mobile App (`jtak-mobile-master`)
4. Delivery Captain Mobile App (`jtak-mobile-delivery-master`)
5. Merchant/Warehouse Mobile App (`jtak-mobile-warehouse-master`)
6. Database & Migration Scripts (`update_production_db.sql`, `cleanup_duplicate_addresses.sql`)
7. Real-Time Telemetry & Arabic Terminology Compliance

---

## Executive Summary

A comprehensive pre-production audit across all 5 codebases and the database was completed under strict read-only execution. While individual projects compile in development mode, deep forensic analysis revealed **5 Critical Fatal Defects, 8 High-Risk Architectural Vulnerabilities, and multiple broken user journeys** that must be resolved prior to server deployment:

1. **Authentication Master Backdoor (Critical)**: `OAuthTokenController.cs:214` contains a hardcoded OTP bypass (`"123456"` / `"1234"`) allowing anyone to log in as any user, admin, or merchant without SMS verification.
2. **Fatal Database Schema Incompatibility (`update_production_db.sql`) (Critical)**: The SQL script contains obsolete table definitions for `Catalog_Merchant`, `Orders_Orders`, `Orders_OrderDetails`, and `Accounting_LedgerEntries`. If imported to the production server, inserting orders and running ledger reconciliations will immediately fail with MySQL column errors (e.g. unknown column `Debit`, missing `OwnerId`, missing default value for `ShippingCost`).
3. **Ghost Migration Registration (Critical)**: `update_production_db.sql` injects fake records into `__EFMigrationsHistory` for all 32 migrations without running the true EF Core DDL, permanently preventing EF Core from executing necessary schema updates.
4. **Order Status Code Inversion on Admin Dashboard (Critical)**: The Angular Dashboard hardcodes inverted status numbers compared to the backend and mobile apps. Status 2 (`ShippingStarted`) is displayed as "مرفوض" (Rejected), Status 3 (`Delivered`) is displayed as "مراجعة العميل" (Under Review), and Status 4 (`MerchantRejected`) is displayed as "جاري التوصيل" (In Transit).
5. **Customer App Broken Product Details (Critical)**: When a customer clicks a product, the app calls `GET /api/v1/Customer/Products/{id}`, but this endpoint does not exist on the backend, returning `404 Not Found`.
6. **Production Build Failure on Dashboard (High)**: `ng build --configuration=production` fails because 14 component SCSS files exceed the 4 kB budget limit in `angular.json`.
7. **HTTP Error Swallowing in Dashboard (High)**: `http.interceptor.ts:91` returns `of(err)`, converting all 400/401/500 errors into successful emissions and disabling error handlers.
8. **Credential & Secret Leaks (High)**: A live Google Cloud Firebase RSA private key and plaintext Twilio/SendGrid API keys are committed in repository files.
9. **Ephemeral Session Tokens (High)**: `OpenIddictHelper.cs` uses ephemeral signing keys, causing all user sessions across mobile apps and the dashboard to be destroyed on every backend restart.
10. **SignalR Eavesdropping (High)**: `TrackingHub.cs:13` allows unauthenticated clients to stream real-time driver coordinates for any order ID.

---

## 1. Compiler & Static Analysis Diagnostics

| Repository / Subsystem | Diagnostic Tool | Result | Errors | Warnings | Lints / Notes |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Backend API** (`jtak-backend-main`) | `dotnet build jtak.sln` | **Passed** | 0 | 0 | .NET SDK 6.0.428. 49/49 tests passed (accounting only). Zero automated tests for API/Orders/Shipping. |
| **Admin Dashboard** (`jtak-dashboard-main`) | `ng build --configuration=development`<br>`ng build --configuration=production` | **Dev: Passed**<br>**Prod: FAILED** | 0<br>14 | 0<br>0 | Production build fails: 14 SCSS files exceed 4 kB budget in `angular.json`. Initial bundle is 5.60 MB. |
| **Customer App** (`jtak-mobile-master`) | `flutter analyze` | **Passed** | 0 | 11 | 211 lints. Flutter 3.47.3 / Dart 3.13.3. Deprecated `WillPopScope` and raw color constants. |
| **Delivery Captain App** (`jtak-mobile-delivery-master`) | `flutter analyze` | **Passed** | 0 | 1 | 62 lints. Flutter 3.47.3 / Dart 3.13.3. Clean static state. |
| **Warehouse/Merchant App** (`jtak-mobile-warehouse-master`) | `flutter analyze` | **Passed** | 0 | 3 | 106 lints. Flutter 3.47.3 / Dart 3.13.3. Clean static state. |

---

## 2. Security & Access Control Vulnerabilities

### SEC-01: Hardcoded Master OTP in SMS Grant Flow
- **Severity**: Critical (CVSS 9.8)
- **File**: `jtak-backend-main/app/ApiControllers/V1/Authorization/OAuthTokenController.cs:214–216`
- **Root Cause**: `var isMasterTestCode = request.Code == "123456" || request.Code == "1234";`
- **Impact**: Any attacker can authenticate as any phone number (including admin, couriers, and merchants) by entering `"123456"`.
- **Fix**: Remove `isMasterTestCode` and require genuine OTP validation.

### SEC-02: Committed Google Cloud Firebase RSA Private Key
- **Severity**: Critical (CVSS 9.8)
- **File**: `jtak-backend-main/app/jtak-339412-firebase-adminsdk-fyug6-170c77def3.json`
- **Impact**: Active GCP private key committed to git history allows cloud infrastructure compromise and push notification spoofing.
- **Fix**: Revoke key in GCP console immediately, add pattern to `.gitignore`, and inject via environment variables.

### SEC-03: Committed Third-Party Secrets & Unencrypted DB Connection
- **Severity**: Critical (CVSS 9.1)
- **File**: `jtak-backend-main/app/appsettings.json:7-58`
- **Impact**: Live API keys for Twilio, SendGrid, and SMTP are committed in plaintext. `SslMode=None` transmits database credentials unencrypted.
- **Fix**: Rotate secrets, migrate to Secret Manager/environment variables, and set `SslMode=Preferred` or `Required`.

### SEC-04: Ephemeral In-Memory Signing Keys & 180-Day Token Lifespan
- **Severity**: High (CVSS 7.5)
- **File**: `jtak-backend-main/app/Helpers/StartUp/OpenIddictHelper.cs:110, 141–143`
- **Impact**: `AddEphemeralEncryptionKey()` and `AddEphemeralSigningKey()` cause all logged-in mobile and web users to be logged out whenever the backend restarts.
- **Fix**: Use a persistent X.509 certificate and reduce access token lifetime to 30 minutes with refresh tokens.

### SEC-05: Insecure Direct Object Reference (IDOR) on Customer Addresses
- **Severity**: Critical (CVSS 8.5)
- **File**: `jtak-backend-main/app/ApiControllers/V1/Customer/AddressController.cs:102–146`
- **Impact**: `Edit` and `Delete` methods do not verify `entity.UserId == User.GetUserId()`. Any customer can modify or delete other customers' saved addresses.
- **Fix**: Add ownership check `if (entity.UserId != uid.Value) return Forbid();`.

### SEC-06: Insecure Direct Object Reference (IDOR) on Warehouse Batches
- **Severity**: High (CVSS 7.5)
- **File**: `jtak-backend-main/app/ApiControllers/V1/Warehouse/Catalog/BatchesController.cs:98–103`
- **Impact**: `GetById(id)` does not verify merchant ownership. A merchant can inspect competitors' purchase cost prices (`CostPrice`) and supplier lots.
- **Fix**: Verify `merchantIds.Contains(batch.MerchantId)`.

### SEC-07: Unauthenticated Live Radar & Order Tracking in SignalR
- **Severity**: Critical (CVSS 8.2)
- **File**: `jtak-backend-main/app.Services/Hubs/TrackingHub.cs:13–27`
- **Impact**: `JoinOrderTracking(int orderId)` has no authorization check. Any anonymous client can stream real-time courier GPS coordinates. `JoinFleetRadar()` lacks role authorization, allowing customers to join dispatcher groups.
- **Fix**: Require `[Authorize]` and ownership verification on `JoinOrderTracking`, and admin role on radar groups.

---

## 3. Database Schema Drift & Data Integrity

### DB-01: Fatal Schema Mismatch in `update_production_db.sql`
- **Severity**: Critical (CVSS 9.3)
- **File**: `D:\work\jtak\update_production_db.sql`
- **Discrepancies**:
  - `Catalog_Merchant`: SQL script defines `UserId VARCHAR(36)`, but EF Core entity expects `OwnerId Guid`. Missing soft-delete columns `DeletionDate`, `DeletedBy`.
  - `Orders_Orders`: SQL defines non-existent `ShippingCost`, `ShippingMethod`, `PaymentStatus` as `NOT NULL` without defaults, causing order insertion failures.
  - `Orders_OrderDetails`: SQL defines `Count INT NOT NULL`, while EF Core entity expects `Quantity INT`.
  - `Accounting_LedgerEntries`: SQL defines `Id CHAR(36)`, `EntryType`, `Amount`. Entity expects `Id BIGINT AUTO_INCREMENT`, `Debit DECIMAL`, `Credit DECIMAL`, `Memo VARCHAR`. Double-entry accounting fails on all transactions.
- **Fix**: Regenerate `update_production_db.sql` directly from current DbContexts using `dotnet ef migrations script --idempotent`.

### DB-02: Fake `__EFMigrationsHistory` Records
- **Severity**: Critical (CVSS 9.0)
- **File**: `D:\work\jtak\update_production_db.sql:1040–1081`
- **Impact**: Inserts 32 migration records without executing their true DDL, preventing EF Core from ever creating the correct schema columns.
- **Fix**: Remove manual fake `__EFMigrationsHistory` inserts.

### DB-03: Silent Migration Swallowing in Startup
- **Severity**: High (CVSS 7.5)
- **File**: `jtak-backend-main/app/Startup.cs:219–224`
- **Impact**: `try { ...Database.Migrate(); } catch { }` silently catches all migration failures without logging, leaving the application running with a broken database.
- **Fix**: Log migration errors with `ILogger` and halt startup if migrations fail.

### DB-04: Outdated Migration Snapshots & Missing Designer Files
- **Severity**: High (CVSS 7.2)
- **Files**: `AddProductBatchesAndReservations.Designer.cs`, `OrdersDbContextModelSnapshot.cs`, `ShippingDbContextModelSnapshot.cs`
- **Impact**: Empty `BuildTargetModel` in batch migration; snapshots miss 5 proof-of-delivery columns (`DeliveryOtp`, `DeliveredAt`, `ProofOfDeliveryPhotoUrl`). Future migrations will generate duplicate/conflicting DDL.
- **Fix**: Resynchronize snapshots via `dotnet ef migrations add`.

### DB-05: Flawed Duplicate Address Cleanup Script
- **Severity**: Medium (CVSS 5.0)
- **File**: `D:\work\jtak\cleanup_duplicate_addresses.sql:7–12`
- **Impact**: `WHERE a1.Id > a2.Id` deletes newer updated addresses and preserves older addresses that lack GPS coordinates.
- **Fix**: Change condition to `WHERE a1.Id < a2.Id` to preserve the latest record.

---

## 4. End-to-End User Journey & API Contract Audit

### UJ-01: Customer Product Details 404 (Broken Journey)
- **Subsystems**: Customer App (`jtak-mobile-master`) <-> Backend API
- **Caller**: `product_details_provider.dart:23` calls `GET /Products/${product.id}`.
- **Backend**: `Customer/Catalog/ProductsController.cs` has NO `[HttpGet("{id}")]` endpoint!
- **Impact**: Clicking on any product to see full description, images, or similar products throws a 404 error.
- **Fix**: Add `[HttpGet("{id}")]` to `Customer/ProductsController.cs`.

### UJ-02: Product Review Linked to Wrong Product ID (Corrupted Journey)
- **Subsystems**: Customer App <-> Backend API
- **File**: `Customer/ProductReviewsController.cs:128`
- **Root Cause**: `ProductId = x.Id` assigns `OrderDetail.Id` instead of `x.ProductId`.
- **Impact**: Reviews submitted by customers are saved against random product IDs or invalid keys.
- **Fix**: Change assignment to `ProductId = x.ProductId`.

### UJ-03: Pending Cart Item Accumulation (Corrupted Cart Journey)
- **Subsystems**: Customer App <-> Backend API
- **File**: `Customer/Orders/CartController.cs:140–163`
- **Root Cause**: Reusing a pending cart adds new items without clearing prior unpurchased items.
- **Impact**: Abandoned items from earlier sessions appear on new orders, charging customers for items they didn't select.
- **Fix**: Clear or update existing `OrderDetails` before saving new cart contents.

### UJ-04: Order Status Code Inversion (Broken Admin Journey)
- **Subsystems**: Admin Dashboard (`jtak-dashboard-main`) <-> Backend & Mobile Apps
- **Files**: `orders-list.component.ts:63–79, 321–334`, `dashboard.component.ts:292–306`
- **Status Mapping Comparison**:
  | Status Code | Backend Entity & Mobile Apps | Dashboard Current Display (Inverted) | Consequence |
  | :---: | :--- | :--- | :--- |
  | **0** | `Pending` | `Pending` ("قيد الانتظار") | Correct |
  | **1** | `MerchantAccepted` | `Accepted` ("مقبول") | Correct |
  | **2** | **`ShippingStarted`** | **`Rejected` ("مرفوض")** | **Critical**: Couriers on the road appear rejected! |
  | **3** | **`Delivered`** | **`Under Review` ("مراجعة العميل")** | **Critical**: Completed deliveries appear stuck! |
  | **4** | **`MerchantRejected`** | **`In Transit` ("جاري التوصيل")** | **Critical**: Rejected orders appear active! |
  | **5** | **`CustomerPending`** | **`Delivered` ("تم التسليم")** | **Critical**: Pending modifications appear delivered! |
- **Fix**: Create `order-status.enum.ts` matching backend `OrderDetailStatus` and update all dashboard status lookups, KPI counters, and badge classes.

---

## 5. UI/UX, Build & Terminology Compliance

### UI-01: Production Build Failure (`angular.json` Budget Limits)
- **File**: `jtak-dashboard-main/angular.json:44`
- **Root Cause**: `anyComponentStyle` maximum error is set to 4 kB. 14 modern SCSS stylesheets range between 4.49 kB and 10.97 kB.
- **Fix**: Increase `maximumWarning` to 12 kB and `maximumError` to 16 kB in `angular.json`.

### UI-02: HTTP Interceptor Error Swallowing
- **File**: `jtak-dashboard-main/src/app/interceptors/http.interceptor.ts:33, 91`
- **Root Cause**: `return of(err)` in `catchError` treats all HTTP errors as successful emissions, breaking `.subscribe({ error })` everywhere. In line 33, `this.authService.logout()` is called before `authService` is resolved via the injector.
- **Fix**: Propagate errors with `throwError(() => err)`, remove premature logout, and lazily resolve `AuthService`.

### UI-03: Live Radar Disconnect
- **Subsystem**: Admin Dashboard
- **Root Cause**: `@microsoft/signalr` is missing from `package.json`. Dashboard has no WebSocket connection to `TrackingHub` and polls HTTP every 4 seconds.
- **Fix**: Install `@microsoft/signalr` and create a dedicated real-time radar service for driver tracking.

### UI-04: Strict Terminology Compliance
- **Rule**: Strict prohibition of the word "أسطول" across all code, UI strings, and documentation.
- **Scan Result**: **0 OCCURRENCES** across all 5 codebases, database SQL files, and git commit history. **100% COMPLIANT**.
- **Note on English Term "fleet"**: The English token `fleet` appears in 38 locations across backend SignalR groups (`fleet_dispatch`), controllers (`FleetReconciliationController`), and frontend services. These should be renamed to `courier` / `captain` to eliminate confusion.
