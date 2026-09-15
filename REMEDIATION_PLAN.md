# JTAK Ecosystem Remediation Plan (Phased Roadmap)

**Target Ecosystem**: Backend, Dashboard, Customer App, Delivery App, Warehouse App, Database  
**Status**: Awaiting User Review & Sign-Off (No implementation will begin prior to user approval)

---

## Phase 1: Critical Deployment & Server Blockers (Immediate Pre-Flight)

> **Objective**: Eliminate critical authentication vulnerabilities, resolve fatal production database schema drift, and fix production build blockers before pushing code to the server.

### Task 1.1: Remove Master OTP Backdoor & Secure Auth Flow
- **Files**: `jtak-backend-main/app/ApiControllers/V1/Authorization/OAuthTokenController.cs:214–216`
- **Actions**:
  1. Remove `isMasterTestCode` (`"123456"` / `"1234"`) and the test number bypass (`+90555555555`).
  2. Enforce strict verification against genuine SMS OTP records.
  3. Verify with unit tests in `OAuthTokenControllerTests`.

### Task 1.2: Regenerate Production Database Migration Script (`update_production_db.sql`)
- **Files**: `D:\work\jtak\update_production_db.sql`
- **Actions**:
  1. Replace the obsolete manual DDL script with a clean, idempotent script generated directly from current EF Core DbContexts:
     ```bash
     dotnet ef migrations script --idempotent --context CatalogDbContext -o sql/catalog_prod.sql
     dotnet ef migrations script --idempotent --context OrdersDbContext -o sql/orders_prod.sql
     dotnet ef migrations script --idempotent --context AccountingDbContext -o sql/accounting_prod.sql
     dotnet ef migrations script --idempotent --context ShippingDbContext -o sql/shipping_prod.sql
     ```
  2. Remove fake manual inserts into `__EFMigrationsHistory` (lines 1040–1081).
  3. Ensure `Catalog_Merchant` (`OwnerId`), `Accounting_LedgerEntries` (`Debit`/`Credit`), and `Orders_Orders` have 100% schema alignment with C# entities.

### Task 1.3: Add Missing Customer Product Details Endpoint (`GET /Products/{id}`)
- **Files**: `jtak-backend-main/app/ApiControllers/V1/Customer/Catalog/ProductsController.cs`
- **Actions**:
  1. Implement `[HttpGet("{id}")]` returning `ProductDetailsDto` with prices, merchant info, categories, and photos.
  2. Unblocks the Customer mobile app's `product_details_provider.dart:23`, fixing the 404 error when customers view product pages.

### Task 1.4: Fix Angular Dashboard Production Build Budget
- **Files**: `jtak-dashboard-main/angular.json:44`
- **Actions**:
  1. Increase `anyComponentStyle` threshold in `angular.json`:
     - `maximumWarning`: `12kb`
     - `maximumError`: `16kb`
  2. Execute `npm run build` and verify 0 errors and successful production bundle generation.

### Task 1.5: Secret Revocation & Credential Isolation
- **Files**: `jtak-backend-main/app/*firebase-adminsdk*.json`, `appsettings.json`
- **Actions**:
  1. Revoke the committed Firebase Service Account key in GCP Console and generate a new key.
  2. Add `*firebase-adminsdk*.json` and sensitive config overrides to `.gitignore`.
  3. Move Twilio, SendGrid, and Database passwords to environment variables.

---

## Phase 2: Core User Journey & Data Integrity Fixes

> **Objective**: Fix order lifecycle status synchronization across all apps, prevent customer cart/review corruption, and close IDOR access control gaps.

### Task 2.1: Fix Order Status Code Inversion on Admin Dashboard
- **Files**:
  - `jtak-dashboard-main/src/app/pages/orders/models/order-status.enum.ts` (New)
  - `jtak-dashboard-main/src/app/pages/orders/components/orders-list/orders-list.component.ts`
  - `jtak-dashboard-main/src/app/pages/dashboard/dashboard.component.ts`
- **Actions**:
  1. Create a centralized enum matching backend `OrderDetailStatus`:
     - 0: `Pending`
     - 1: `MerchantAccepted`
     - 2: `ShippingStarted`
     - 3: `Delivered`
     - 4: `MerchantRejected`
     - 5: `CustomerPending`
     - 6: `CustomerCanceled`
     - 7: `DeliveryCanceled`
  2. Update all status labels, badge colors, and KPI counters in `orders-list` and `dashboard` to correct the inversion where in-transit orders displayed as rejected.

### Task 2.2: Fix Product Review Entity Mapping Bug
- **Files**: `jtak-backend-main/app/ApiControllers/V1/Customer/ProductReviewsController.cs:128`
- **Actions**:
  1. Change `ProductId = x.Id` to `ProductId = x.ProductId`.
  2. Ensures customer dish ratings correctly link to the actual catalog product rather than the order detail primary key.

### Task 2.3: Prevent Pending Cart Item Accumulation
- **Files**: `jtak-backend-main/app/ApiControllers/V1/Customer/Orders/CartController.cs:140–163`
- **Actions**:
  1. When reusing a customer's pending cart, delete or synchronize existing `OrderDetails` before saving new items.
  2. Prevents abandoned items from earlier sessions from being charged to the customer.

### Task 2.4: Secure IDOR Vulnerabilities on Customer Address & Warehouse Batches
- **Files**:
  - `jtak-backend-main/app/ApiControllers/V1/Customer/AddressController.cs:102–146`
  - `jtak-backend-main/app/ApiControllers/V1/Warehouse/Catalog/BatchesController.cs:20, 98–103`
  - `jtak-backend-main/app/ApiControllers/V1/Warehouse/Catalog/ProductsController.cs:26`
- **Actions**:
  1. In `AddressController`, verify `entity.UserId == User.GetUserId()` before allowing edit/delete.
  2. In `BatchesController`, verify requesting merchant owns the batch before returning details.
  3. Add `[Authorize(Policy = nameof(AppPermissionKey.MerchantPermission))]` to Warehouse controllers.

### Task 2.5: Secure SignalR Telemetry & Radar Access
- **Files**: `jtak-backend-main/app.Services/Hubs/TrackingHub.cs:13–27`
- **Actions**:
  1. Add `[Authorize]` and ownership verification to `JoinOrderTracking(int orderId)`.
  2. Require admin permission policy on `JoinFleetRadar()`.

---

## Phase 3: Real-Time Infrastructure & Operational Stability

> **Objective**: Implement true real-time radar on the dashboard, resolve memory leaks, and stabilize user session persistence.

### Task 3.1: Dashboard HTTP Interceptor Overhaul
- **Files**: `jtak-dashboard-main/src/app/interceptors/http.interceptor.ts`
- **Actions**:
  1. Change `catchError` from `return of(err)` to `return throwError(() => err)`.
  2. Safely resolve `AuthService` via Angular Injector without calling premature logout on refresh requests.
  3. Dynamically set `Accept-Language` from `TranslationService.getSelectedLanguage()`.

### Task 3.2: Eliminate Unbounded Subscription Memory Leak in Dashboard
- **Files**: `jtak-dashboard-main/src/app/_metronic/shared/crud-table/services/table.service.ts:164–182`
- **Actions**:
  1. Cancel or clean completed subscriptions in `_subscriptions` array.
  2. Use `take(1)` on HTTP calls to prevent memory growth during 5-second polling.

### Task 3.3: Persistent OpenIddict Signing Keys & Session Stability
- **Files**: `jtak-backend-main/app/Helpers/StartUp/OpenIddictHelper.cs:110–143`
- **Actions**:
  1. Configure persistent X.509 signing certificates or DPAPI / Key Vault key storage.
  2. Prevent unexpected user logouts across mobile apps upon server recycles.
  3. Fix dead cold observable in `auth.service.ts:59–79` by chaining `.subscribe()`.

### Task 3.4: Integrate Real-Time Live Radar via SignalR in Dashboard
- **Files**:
  - `jtak-dashboard-main/package.json`
  - `jtak-dashboard-main/src/app/pages/orders/services/signalr-tracking.service.ts` (New)
- **Actions**:
  1. Install `@microsoft/signalr`.
  2. Map SignalR hub connection to `/hubs/tracking` with JWT token provider.
  3. Stream driver locations via `OnFleetLocationUpdated` to replace 4-second HTTP polling.

---

## Phase 4: UI/UX Polish, Terminology Standardization & Hygiene

> **Objective**: Remove legacy code, standardize terminology, and ensure flawless Arabic RTL rendering.

### Task 4.1: Standardize English "fleet" Identifiers to Courier / Dispatch
- **Files**: 38 files across backend SignalR, controllers, and frontend templates
- **Actions**:
  1. Rename backend identifiers (e.g. `FleetDispatchGroup` -> `CourierDispatchGroup`, `FleetReconciliationController` -> `CourierReconciliationController`).
  2. Rename frontend variables (e.g. `activeTab === 'fleet'` -> `activeTab === 'couriers'`).
  3. Verify continued 0 occurrences of the prohibited Arabic word "أسطول".

### Task 4.2: Fix Language Switch Direction Desynchronization
- **Files**:
  - `jtak-dashboard-main/src/app/_metronic/partials/layout/extras/dropdown-inner/user-inner/user-inner.component.ts:38`
  - `jtak-dashboard-main/src/app/app.component.ts:82–86`
- **Actions**:
  1. Ensure language toggle updates DOM `dir="rtl"` / `dir="ltr"` smoothly.
  2. Remove redundant runtime `<link href="./assets/sass/custom-rtl.css">` injection in `app.component.ts` (already bundled in `styles.scss`).

### Task 4.3: Bundle Local Offline Arabic Font Fallback
- **Files**: `jtak-dashboard-main/src/index.html`, `src/assets/fonts/`
- **Actions**:
  1. Add local `IBM Plex Sans Arabic` `.woff2` files to `assets/fonts/` to prevent font flash or fallback shifts on slow connections.

### Task 4.4: Clean Dead Orphaned Stubs
- **Files**:
  - `src/app/modules/shared/models/refrences.model.ts`
  - `src/app/modules/auth/services/auth-http/index.ts`
- **Actions**:
  1. Remove dead template scaffolding stubs to keep root `npx tsc --noEmit` 100% clean.

---

## Verification & Acceptance Protocol per Phase

| Phase | Verification Method | Pass Criteria |
| :--- | :--- | :--- |
| **Phase 1** | Run `dotnet test`, `dotnet build`, `ng build --prod`, test SMS auth with non-OTP | Backend & Dashboard prod builds succeed with 0 errors; backdoor OTP rejected. |
| **Phase 2** | End-to-end status change simulation; place order, submit review, verify IDOR guards | Order statuses match 1:1 between backend, mobile apps, and dashboard; reviews mapped correctly. |
| **Phase 3** | Restart backend, verify token persistence; inspect memory profiler on dashboard polling | Sessions survive backend restart; memory usage remains flat over 1 hour. |
| **Phase 4** | Global regex scan for prohibited terms; toggle language between Arabic and English | 0 occurrences of prohibited terms; RTL/LTR flips seamlessly. |
