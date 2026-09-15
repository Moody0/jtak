# JTAK Dashboard & Terminology Audit Report

**Date**: 2026-09-13  
**Auditor**: Dashboard & Terminology Audit Specialist  
**Target Subsystems**:
- `jtak-dashboard-main` (Angular 13 SPA)
- Ecosystem-wide Terminology Compliance ("أسطول" & "fleet" across all 5 repositories, database migrations, and documentation)

---

## 1. Executive Summary

A comprehensive pre-production diagnostic, architectural, UI/UX, and terminology compliance audit was conducted across `jtak-dashboard-main` and the wider JTAK ecosystem.

### Key Audit Findings:
1. **Production Build Failure (Severity: Critical)**: `npm run build` (`ng build --configuration=production`) fails with exit code 1. 14 component SCSS files exceed the 4.00 kB `anyComponentStyle` budget limit configured in `angular.json` (ranging from 4.49 kB to 10.97 kB). Development build compiles successfully (5.60 MB initial bundle).
2. **Critical Order Status Code Inversion (Severity: Critical)**: A severe enum mismatch exists between the ASP.NET Core backend `OrderDetailStatus` enum and the Angular Dashboard frontend logic. The frontend hardcodes numbers (0=Pending, 1=Ready, 2=Rejected, 3=Review, 4=In Transit, 5=Delivered), whereas backend status 2 is `ShippingStarted`, 3 is `Delivered`, 4 is `MerchantRejected`, and 5 is `CustomerPending`. Consequently, **rejected orders appear as "In Transit"**, **delivered orders appear as "Under Review"**, and **orders being shipped appear as "Rejected"** in the Admin operations UI.
3. **HTTP Interceptor Error Swallowing (Severity: Critical)**: In `src/app/interceptors/http.interceptor.ts`, `catchError` returns `of(err)`. This converts every HTTP error (400, 401, 500) into a successful emission (`next`), completely breaking error handling and `.subscribe({ error })` callbacks throughout the entire application. In addition, the 401 token refresh flow calls `this.authService.logout()` before `authService` is instantiated via Angular Injector.
4. **Auth Startup Token Refresh is Dead Code (Severity: High)**: In `src/app/modules/auth/services/auth.service.ts`, `restoreSession()` builds an RxJS pipe for `getAuthByToken(GRANT_TYPES.REFRESH_TOKEN)` but never calls `.subscribe()`. As a cold observable, it is never executed when the app loads with an expired token.
5. **SignalR & Live Radar Disconnect (Severity: High)**: The backend exposes real-time driver telemetry on `TrackingHub` (`JoinFleetRadar`, `OnFleetLocationUpdated`), but the Dashboard has no SignalR client dependency (`@microsoft/signalr` is missing from `package.json`), no SignalR hub connection, and no global city radar map. Instead, individual orders are tracked via 4-second HTTP polling (`/Admin/Orders/{id}/LiveTrack`).
6. **Continuous Subscription Memory Leak (Severity: High)**: In `_metronic/shared/crud-table/services/table.service.ts`, `fetchPost()` pushes subscriptions to `this._subscriptions` without pruning completed observables. Since `orders-list.component.ts` polls `fetchPost()` every 5 seconds, the array grows unboundedly.
7. **Strict Terminology Compliance ("أسطول") (Severity: Clean / High for "fleet")**: The prohibited Arabic word "أسطول" and all its variations ("الأسطول", "أسطولنا", "اسطول") have **ZERO occurrences** across the entire 5-repository codebase, SQL scripts, and git commit history. However, the English token **"fleet"** appears in 38 locations across backend SignalR groups, reconciliation controllers, database ledger descriptions, and dashboard components.

---

## 2. Compiler, Build & Diagnostic Verification

### 2.1 Tooling & Environment
- **Node.js**: `v16.20.2` (Supported by Angular 13: Node 14.15 – 16.x)
- **NPM**: `8.19.4`
- **Angular Core & CLI**: `13.2.1` / `13.2.2`
- **TypeScript**: `~4.5.5`
- **RxJS**: `~7.5.2`

### 2.2 Compilation Diagnostics

#### Development Build (`npx ng build --configuration=development`):
- **Result**: `SUCCESS` (Exit code: 0)
- **Time**: 24,586 ms
- **Hash**: `60423d99b5b3d15e`
- **Initial Total Size**: 5.60 MB (`vendor.js`: 3.28 MB, `styles.css`: 1.61 MB, `main.js`: 566 kB, `polyfills.js`: 137 kB, `runtime.js`: 12.5 kB)

#### Production Build (`npm run build` / `ng build --configuration=production`):
- **Result**: `FAILED` (Exit code: 1)
- **Cause**: Budget limits defined in `angular.json` line 44:
  ```json
  {
    "type": "anyComponentStyle",
    "maximumWarning": "2kb",
    "maximumError": "4kb"
  }
  ```
- **Failing Components (14 files exceeding 4.00 kB budget)**:
  1. `src/app/pages/banners/components/banners-list/banners-list.component.scss`: **9.72 kB** (exceeded by 5.72 kB)
  2. `src/app/pages/bills/components/bills-list/bills-list.component.scss`: **8.04 kB** (exceeded by 4.04 kB)
  3. `src/app/pages/categories/components/categories-list/categories-list.component.scss`: **9.79 kB** (exceeded by 5.79 kB)
  4. `src/app/pages/categories/components/edit-category-modal/edit-category-modal.component.scss`: **7.12 kB** (exceeded by 3.12 kB)
  5. `src/app/pages/inventory-batches/components/batch-list/batch-list.component.scss`: **9.34 kB** (exceeded by 5.34 kB)
  6. `src/app/pages/merchant/components/edit-merchant-modal/edit-merchant-modal.component.scss`: **6.58 kB** (exceeded by 2.58 kB)
  7. `src/app/pages/merchant/components/merchants-list/merchants-list.component.scss`: **10.85 kB** (exceeded by 6.85 kB)
  8. `src/app/pages/orders/components/orders-list/orders-list.component.scss`: **10.63 kB** (exceeded by 6.63 kB)
  9. `src/app/pages/payments/components/payments-list/payments-list.component.scss`: **7.09 kB** (exceeded by 3.09 kB)
  10. `src/app/pages/products/components/edit-product-modal/edit-product-modal.component.scss`: **6.47 kB** (exceeded by 2.47 kB)
  11. `src/app/pages/products/components/products-list/products-list.component.scss`: **10.97 kB** (exceeded by 6.97 kB)
  12. `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.scss`: **8.55 kB** (exceeded by 4.55 kB)
  13. `src/app/pages/users/components/edit-user-modal/edit-user-modal.component.scss`: **4.49 kB** (exceeded by 504 bytes)
  14. `src/app/pages/users/components/users-list/users-list.component.scss`: **9.14 kB** (exceeded by 5.14 kB)

*Remediation*: Update `angular.json` line 42-45: increase `maximumWarning` to `12kb` and `maximumError` to `16kb`, or extract duplicated card/table utility classes into `src/styles.scss`.

### 2.3 TypeScript Static Typechecking
- Running `npx tsc --project tsconfig.app.json --noEmit` exited cleanly with **0 errors**.
- Running global `npx tsc --noEmit` flagged 2 orphaned files referencing missing modules:
  1. `src/app/modules/shared/models/refrences.model.ts`:
     - Line 1: `import { Brand } from 'src/app/pages/brands/models/brand.model';` (File does not exist)
     - Line 3: `import { Color } from 'src/app/pages/colors/models/color.model';` (File does not exist)
     - *Audit Note*: This file is orphaned dead code; not imported anywhere in the app.
  2. `src/app/modules/auth/services/auth-http/index.ts`:
     - Line 2: `export { AuthHTTPService } from './fake/auth-fake-http.service';` (File does not exist)
     - *Audit Note*: Dead export stub left over from Metronic template scaffolding.
  3. Declaration conflicts between `@types/googlemaps` and `@angular/google-maps`.

### 2.4 Linting & Deprecations
- **No Linter Configured**: `package.json` contains no `lint` script, and no `.eslintrc` or `tslint.json` configuration exists.
- **RxJS Deprecations**:
  - `Observable.subscribe(nextFn, errorFn)` multi-argument syntax is used in `users-list.component.ts:75`, `orders-list.component.ts:183`, `products-list.component.ts:287`, rather than the standard observer object `{ next: ..., error: ... }`.
  - Missing unsubscription on multiple direct `.subscribe()` invocations across modals and table component instances.

---

## 3. Dashboard UI/UX & Architectural Audit

### 3.1 Critical Defect: Order Status Enum Inversion

#### File References:
- `src/app/pages/orders/components/orders-list/orders-list.component.ts`: Lines 63–79, 87–104, 279, 294–334, 341–357
- `src/app/pages/dashboard/dashboard.component.ts`: Lines 290–308
- Backend definition: `jtak-backend-main/Modules/Orders/Modules.Orders.Entities/OrderStatus.cs`: Lines 21–45

#### Root Cause Analysis:
The backend defines `OrderDetailStatus` as:
```csharp
public enum OrderDetailStatus
{
    Pending = 0,
    MerchantAccepted = 1,
    ShippingStarted = 2,
    Delivered = 3,
    MerchantRejected = 4,
    CustomerPending = 5,
    CustomerCanceled = 6,
    DeliveryCanceled = 7
}
```
However, the Angular Dashboard components hardcoded arbitrary status integers based on an assumed sequence:
```typescript
// orders-list.component.ts
getStatusLabel(status: number): string {
  switch (status) {
    case 0: return isAr ? 'قيد الانتظار' : 'Pending';
    case 1: return isAr ? 'مقبول' : 'Accepted';
    case 2: return isAr ? 'مرفوض' : 'Rejected';           // BUG: Backend 2 is ShippingStarted!
    case 3: return isAr ? 'مراجعة العميل' : 'Under Review'; // BUG: Backend 3 is Delivered!
    case 4: return isAr ? 'جاري التوصيل' : 'In Transit';   // BUG: Backend 4 is MerchantRejected!
    case 5: return isAr ? 'تم التسليم' : 'Delivered';     // BUG: Backend 5 is CustomerPending!
    case 6: return isAr ? 'ملغي' : 'Canceled';
    case 7: return isAr ? 'ملغي من السائق' : 'Canceled by Driver';
  }
}
```

#### Operational Impact:
| Real Order State (Backend) | Value | What Admin Sees on Dashboard | Severity |
|----------------------------|-------|------------------------------|----------|
| `Pending`                  | 0     | "قيد الانتظار" (Pending)      | Correct  |
| `MerchantAccepted`         | 1     | "مقبول" / "جاهز للتوصيل"      | Correct  |
| **`ShippingStarted`**      | 2     | **"مرفوض" (Rejected)** with red badge | **Critical** (Orders out for delivery appear rejected) |
| **`Delivered`**            | 3     | **"مراجعة العميل" (Under Review)** | **Critical** (Completed deliveries appear pending review) |
| **`MerchantRejected`**     | 4     | **"جاري التوصيل" (In Transit)** with bike icon | **Critical** (Rejected items appear actively shipping) |
| **`CustomerPending`**      | 5     | **"تم التسليم" (Delivered)** with green badge | **Critical** (Unresolved customer changes appear delivered) |

#### Fix Proposal:
Create a centralized enum file `src/app/pages/orders/models/order-status.enum.ts` mirroring backend `OrderDetailStatus` exactly:
```typescript
export enum OrderDetailStatus {
  Pending = 0,
  MerchantAccepted = 1,
  ShippingStarted = 2,
  Delivered = 3,
  MerchantRejected = 4,
  CustomerPending = 5,
  CustomerCanceled = 6,
  DeliveryCanceled = 7,
}
```
Update all filter tabs, KPI counts, status badges, and translation labels in `orders-list.component.ts` and `dashboard.component.ts` to consume this enum.

---

### 3.2 Critical Defect: HTTP Interceptor Error Handling & Token Refresh Flaws

#### File Reference: `src/app/interceptors/http.interceptor.ts`
- **Lines 15**: `import { LanguageService } from 'typescript';` (Unused runtime import from typescript package).
- **Lines 30–36**:
  ```typescript
  if (req.url.includes('connect/token')) {
    if (req.body?.grant_type === GRANT_TYPES.REFRESH_TOKEN) {
      this.authService.logout(); // BUG: this.authService is undefined! Throws TypeError!
    }
    return this.handleRequest(req, next);
  }
  ```
  `this.authService` has not been initialized via `this.injector.get(AuthService)` yet (which only occurs at line 39 inside the `!req.url.includes('connect/token')` block). If a refresh token request is sent, accessing `this.authService.logout()` crashes with `Cannot read properties of undefined (reading 'logout')`. Furthermore, logging out *before* sending the refresh request is logically inverted.
- **Lines 63–93**:
  ```typescript
  return next.handle(req).pipe(
    catchError((err: any) => {
      if (isPlatformBrowser(this.platformId)) {
        if (err instanceof HttpErrorResponse) {
          if (err.status === 401) {
            this.authService.login(GRANT_TYPES.REFRESH_TOKEN).subscribe(...);
          } else if (!req.headers.has('X-Silent-Error') && !req.url.includes('/Batches/Kpis')) {
            // Toastr display
          }
        }
      }
      return of(err); // CATASTROPHIC BUG: Swallows error and returns as next() value!
    })
  );
  ```
  `return of(err)` causes the observable stream to complete successfully with `err` as its emitted value. Consequently:
  - `.subscribe({ error: (e) => ... })` is never executed anywhere in the app.
  - Component code expecting data models receives `HttpErrorResponse` instances instead.
  - Settle shift in `reconciliation-list.component.ts:146` treats failed settlements as successes because `next()` fires.
- **Lines 50–54**:
  ```typescript
  req = req.clone({
    setHeaders: {
      'Accept-Language': 'ar', // Hardcoded 'ar', ignores active language
    },
  });
  ```
- **Line 75**: Hardcoded URL string check `!req.url.includes('/Batches/Kpis')` instead of using standard header flags.

#### Fix Proposal:
Rewrite `http.interceptor.ts`:
1. Use `throwError(() => err)` in `catchError` so errors propagate correctly to component observers.
2. Implement proper token refresh locking with `BehaviorSubject<boolean>` and `switchMap` to retry failed 401 requests with the new access token.
3. Inject `AuthService` safely using `Injector` in a getter or lazy resolver.
4. Dynamically inject `Accept-Language` from `TranslationService.getSelectedLanguage()`.

---

### 3.3 Auth Service Startup Token Refresh Defect

#### File Reference: `src/app/modules/auth/services/auth.service.ts`
- **Lines 56–80**:
  ```typescript
  if (expiryDate !== undefined && expiryDate < new Date()) {
    console.log('is expiered');
    // If auth is expired, try getting refresh token
    this.getAuthByToken(GRANT_TYPES.REFRESH_TOKEN)
      .pipe(
        map((auth: AuthModel) => { ... }),
        switchMap(() => this.getUserByToken()),
        map((user) => { ... }),
        catchError((err) => { ... }),
        finalize(() => this.isLoadingSubject.next(false))
      ); // BUG: Cold observable created without .subscribe()!
  }
  ```
  Because `.subscribe()` is never chained, the HTTP request to refresh the expired token is **never executed**. The user is restored from `localStorage` with an expired access token, leading to immediate 401 errors on subsequent API calls.

---

### 3.4 Live Radar & Real-Time Tracking Gap

#### Current Architecture:
1. **Backend SignalR Capability**:
   - `TrackingHub` (`/hubs/tracking`) supports `JoinFleetRadar()` and `LeaveFleetRadar()`.
   - Broadcasts real-time events to group `fleet_dispatch`:
     - `OnFleetLocationUpdated`: `{ driverId, lat, lng, heading, speed, updatedAt }`
     - `OnFleetDutyStatusChanged`: `{ driverId, isOnline, hasActiveOrders }`
     - `OnNewAvailableOrder`: `{ orderId }`
     - `OnOrderClaimed`: `{ orderId, driverId, driverName }`
2. **Dashboard Disconnect**:
   - Package `@microsoft/signalr` is **NOT installed** in `package.json`.
   - The dashboard connects to zero WebSockets or SignalR hubs.
   - `LiveTrackModalComponent` relies on `interval(4000).subscribe(() => this.fetchTelemetry())` via HTTP GET `/Admin/Orders/{id}/LiveTrack`.
   - There is no live dispatch radar map showing all active drivers across the city.
   - Section 5 of `dashboard.component.html` labeled "Live Operations Radar" is merely a static table of the 5 most recent orders.

#### Fix Proposal:
1. Add `@microsoft/signalr` to `package.json`.
2. Create `SignalrTrackingService` connecting to `/hubs/tracking` with bearer token auth.
3. Build a dedicated Live Dispatch Radar page/modal rendering a multi-marker Google Map showing active drivers with real-time heading and status, streaming from `OnFleetLocationUpdated`.

---

### 3.5 State Management & Memory Leaks

#### File Reference: `src/app/_metronic/shared/crud-table/services/table.service.ts`
- **Lines 164–182**:
  ```typescript
  public fetchPost(queryParams: any = null) {
    ...
    const request = this.http.post<TableResponseModel<T>>(url, body, { params })
      .pipe(
        tap((res) => { ... }),
        finalize(() => { this._isLoading$.next(false); })
      )
      .subscribe();
    this._subscriptions.push(request); // Pushes without pruning completed subscriptions
  }
  ```
- In `orders-list.component.ts:256`:
  ```typescript
  this.subs.sink = interval(5000).subscribe(() => this.ordersService.fetchPost());
  ```
  Every 5 seconds, a new `Subscription` object is permanently retained in `_subscriptions`. During a standard 8-hour admin session, this pushes 5,760 subscription objects into memory without garbage collection.
- *Fix*: Replace manual subscription pushing with `take(1)` or unsubscribe prior requests before initiating a new fetch.

---

### 3.6 Security & Configuration: Hardcoded Google Maps API Key

#### File Reference: `src/index.html` Line 20
```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAp9HzSnfyp3c1mSKtOGANwhmFSGa3Rm20&loading=async"></script>
```
The Google Maps API key is hardcoded directly in `index.html`. It should be:
1. Loaded dynamically via an Angular factory or APP_INITIALIZER from `environment.googleMapsApiKey`.
2. Strictly restricted by HTTP Referrer in Google Cloud Console (`*.jtak.app/*`).

---

### 3.7 UI/UX, RTL Mirroring & Font Rendering

#### Findings:
1. **Language Switching Layout Desynchronization**:
   - In `src/app/_metronic/partials/layout/extras/dropdown-inner/user-inner/user-inner.component.ts:38`:
     ```typescript
     selectLanguage(lang: string) {
       this.translationService.setLanguage(lang);
       this.setLanguage(lang);
       // document.location.reload(); // Commented out!
     }
     ```
     When an admin switches language from the user profile dropdown, the dictionary updates, but `app.component.ts`'s `setLayoutDirection()` is not triggered and the page is not reloaded. As a result, the UI text changes to Arabic, but the layout remains in LTR mode!
2. **Redundant RTL CSS Import & DOM Injection**:
   - `src/styles.scss:4`: `@import "./assets/sass/custom-rtl.css";` bundles the entire 579-line RTL stylesheet into `styles.css`.
   - `src/app/app.component.ts:82–86`: Dynamically creates and injects `<link id="custom-rtl-style" href="./assets/sass/custom-rtl.css">` into `<head>`. This causes double-evaluation of RTL rules and unnecessary HTTP requests for a pre-bundled stylesheet.
3. **No Local Font Fallback for Arabic**:
   - `index.html` loads `IBM Plex Sans Arabic` from `fonts.googleapis.com`.
   - No local `.woff2` font files are present under `src/assets/`. If the admin operates under slow connectivity or restricted networks, Arabic text falls back to generic system sans-serif, causing UI layout shifts.
4. **Hardcoded Arabic Strings in TypeScript**:
   - `orders-list.component.ts` and `dashboard.component.ts` use inline ternary operators (`isAr ? 'مقبول' : 'Accepted'`) instead of consuming `TranslateService.instant('ORDERS_PAGE.STATUS_...')` from the comprehensive translation dictionaries in `ar.ts` and `en.ts`.

---

## 4. Core Functional Modules Audit

### 4.1 Admin Order Oversight
- **Search & Filter**: Operates smoothly across Order ID, customer name, and phone number.
- **Bulk Actions**: `bulkCancel()` uses `forkJoin(selected.map(...))` and confirms via `BulkConfirmModalComponent`.
- **Order Details Expand/Collapse**: Toggles inline product items smoothly for multi-item orders.

### 4.2 Captain Assignment & Unassignment
- **Endpoint Parity**:
  - Assign / Change: `PUT /api/v1/Admin/Orders/SetDelivery/{id}/{uid}`
  - Unassign: `PUT /api/v1/Admin/Orders/UnassignDelivery/{id}`
  - Both endpoints are verified on `jtak-backend-main/app/ApiControllers/V1/Admin/Orders/OrdersController.cs:303, 340`.
  - When `uid === '00000000-0000-0000-0000-000000000000'`, backend correctly delegates to `UnassignDelivery(id)` and broadcasts `OnNewAvailableOrder` to the driver pool.
- **Minor Typo**: Service method is named `setDelievry` instead of `setDelivery` in `orders.service.ts:35`.

### 4.3 Dark Store FEFO Inventory Batches
- **Endpoint Parity**: `Admin/Batches` GET and POST are supported.
- **Stubbed KPI Method**: `getKpis` in `inventory-batch.service.ts:39` returns `of(null)` with a developer note citing previous 400 Bad Request issues. KPI cards are instead computed reactively on the client side from the batches collection.

### 4.4 Financial Reconciliation & EOD Cash Settlement
- **Endpoint Parity**:
  - `GET /api/v1/Admin/FleetReconciliation/Captains`
  - `GET /api/v1/Admin/FleetReconciliation/Captain/{captainId}/Statement`
  - `POST /api/v1/Admin/FleetReconciliation/Settle`
  - `GET /api/v1/Admin/FleetReconciliation/History`
  - Endpoints match perfectly with `FleetReconciliationController.cs`.
- **Business Logic Enforcement**:
  - Front-end correctly validates that non-zero discrepancy between physical cash received and expected net cash due requires a mandatory `discrepancyReason` before submission (`reconciliation-list.component.ts:129–132`).
  - Ledger statement modal properly renders cash float, wages earned, and net vault remittance.

---

## 5. Strict Terminology Compliance Audit ("أسطول" & "fleet")

### 5.1 Prohibition Compliance: Arabic Word "أسطول"
A rigorous, case-insensitive, ecosystem-wide static scan was conducted across all 5 codebases, database SQL migrations, JSON files, and markdown documentation using ripgrep and git log:
- **Search Patterns**: `"أسطول"`, `"الأسطول"`, `"أسطولنا"`, `"اسطول"`, `"الاسطول"`, `[أاإآ]?سطول`
- **Result**: **0 OCCURRENCES FOUND**.
- **Audit Verdict**: **STRICT COMPLIANCE CONFIRMED**. The Arabic codebase consistently uses professional logistics terms:
  - `"المناديب"` (Couriers)
  - `"الكباتن"` (Captains)
  - `"فريق التوصيل"` (Delivery Team)
  - `"إدارة التوصيل"` (Delivery Management)

---

### 5.2 Ecosystem Inventory of English Term "fleet"
The English word `fleet` is used in backend SignalR group names, controllers, services, database ledger descriptions, and frontend templates. While English identifiers do not violate Arabic UI rules, standardizing them prevents future translation regressions or accidental introduction of "أسطول" via AI or external localization tools.

#### Complete Catalog of "fleet" Occurrences (38 Instances):

| # | Subsystem | File Path | Line | Code Context | Recommended Replacement |
|---|-----------|-----------|------|--------------|-------------------------|
| 1 | Backend | `app.Services/Hubs/TrackingHub.cs` | 11 | `public const string FleetDispatchGroup = "fleet_dispatch";` | `CourierDispatchGroup = "courier_dispatch";` |
| 2 | Backend | `app.Services/Hubs/TrackingHub.cs` | 24 | `public async Task JoinFleetRadar()` | `JoinCourierRadar()` / `JoinDeliveryRadar()` |
| 3 | Backend | `app.Services/Hubs/TrackingHub.cs` | 26 | `Groups.AddToGroupAsync(..., FleetDispatchGroup);` | `Groups.AddToGroupAsync(..., CourierDispatchGroup);` |
| 4 | Backend | `app.Services/Hubs/TrackingHub.cs` | 29 | `public async Task LeaveFleetRadar()` | `LeaveCourierRadar()` |
| 5 | Backend | `app.Services/Hubs/TrackingHub.cs` | 31 | `Groups.RemoveFromGroupAsync(..., FleetDispatchGroup);` | `Groups.RemoveFromGroupAsync(..., CourierDispatchGroup);` |
| 6 | Backend | `app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` | 329 | `SendAsync("OnOrderClaimed", ...)` to `FleetDispatchGroup` | Use `CourierDispatchGroup` |
| 7 | Backend | `app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` | 451 | `var fleetPayload = new { ... }` | `var courierPayload = new { ... }` |
| 8 | Backend | `app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` | 460 | `SendAsync("OnFleetLocationUpdated", fleetPayload);` | `SendAsync("OnCourierLocationUpdated", ...)` |
| 9 | Backend | `app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` | 489 | `SendAsync("OnFleetDutyStatusChanged", ...);` | `SendAsync("OnCourierDutyStatusChanged", ...)` |
| 10 | Backend | `app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` | 523 | `SendAsync("OnFleetLocationUpdated", livePayload);` | `SendAsync("OnCourierLocationUpdated", ...)` |
| 11 | Backend | `app/ApiControllers/V1/Warehouse/Orders/OrdersController.cs` | 417 | `// Complete merchant acceptance and fleet dispatch` | `// Complete merchant acceptance and courier dispatch` |
| 12 | Backend | `app/ApiControllers/V1/Admin/Orders/OrdersController.cs` | 295 | `SendAsync("OnNewAvailableOrder", ...)` to `FleetDispatchGroup` | Use `CourierDispatchGroup` |
| 13 | Backend | `app/ApiControllers/V1/Admin/Orders/OrdersController.cs` | 332 | `SendAsync("OnNewAvailableOrder", ...)` to `FleetDispatchGroup` | Use `CourierDispatchGroup` |
| 14 | Backend | `app/ApiControllers/V1/Admin/Accounting/FleetReconciliationController.cs` | 23 | `public class FleetReconciliationController : SolApiController` | `CourierReconciliationController` |
| 15 | Backend | `app/ApiControllers/V1/Admin/Accounting/FleetReconciliationController.cs` | 28 | `public FleetReconciliationController(...)` | `public CourierReconciliationController(...)` |
| 16 | Backend | `app/ApiControllers/V1/Admin/Accounting/FleetReconciliationController.cs` | 37 | `/// Get real-time EOD financial position for all delivery fleet captains` | `/// ... for all delivery captains / couriers` |
| 17 | Backend | `app/ApiControllers/V1/Admin/Accounting/FleetReconciliationController.cs` | 42 | `_reconciliationService.GetFleetSettlementSummariesAsync();` | `GetCourierSettlementSummariesAsync()` |
| 18 | Backend | `Modules.Shipping.Services/IEodReconciliationService.cs` | 63 | `Task<List<...>> GetFleetSettlementSummariesAsync();` | `GetCourierSettlementSummariesAsync()` |
| 19 | Backend | `Modules.Shipping.Services/EodReconciliationService.cs` | 34 | `public async Task<List<...>> GetFleetSettlementSummariesAsync()` | `GetCourierSettlementSummariesAsync()` |
| 20 | Backend | `Modules.Shipping.Services/EodReconciliationService.cs` | 213 | `ReferenceType = "FleetSettlement"` | `ReferenceType = "CourierSettlement"` |
| 21 | Backend | `Modules.Shipping.Services/EodReconciliationService.cs` | 216 | `Description = $"EOD Fleet Settlement: Captain..."` | `Description = $"EOD Courier Settlement: Captain..."` |
| 22 | Backend | `Modules.Accounting.Tests/EodReconciliationServiceTests.cs` | 204 | `GetFleetSettlementSummariesAsync_AggregatesFleetCorrectly()` | `..._AggregatesCouriersCorrectly()` |
| 23 | Backend | `Modules.Accounting.Tests/EodReconciliationServiceTests.cs` | 239 | `eodService.GetFleetSettlementSummariesAsync()` | `eodService.GetCourierSettlementSummariesAsync()` |
| 24 | Backend | `publish_output/App.xml` | 19 | `FleetReconciliationController.GetCaptains` | `CourierReconciliationController.GetCaptains` |
| 25 | Backend | `publish_output/App.xml` | 21 | `...for all delivery fleet captains` | `...for all delivery captains` |
| 26 | Backend | `publish_output/App.xml` | 24 | `FleetReconciliationController.GetCaptainStatement` | `CourierReconciliationController.GetCaptainStatement` |
| 27 | Backend | `publish_output/App.xml` | 29 | `FleetReconciliationController.SettleShift` | `CourierReconciliationController.SettleShift` |
| 28 | Backend | `publish_output/App.xml` | 34 | `FleetReconciliationController.GetHistory` | `CourierReconciliationController.GetHistory` |
| 29 | Dashboard | `src/app/pages/reconciliation/services/reconciliation.service.ts` | 17 | `baseUrl = .../Admin/FleetReconciliation;` | `baseUrl = .../Admin/CourierReconciliation;` |
| 30 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.ts` | 18 | `activeTab: 'fleet' \| 'history' = 'fleet';` | `activeTab: 'couriers' \| 'history' = 'couriers';` |
| 31 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.ts` | 60 | `console.error('Failed to load fleet reconciliation summaries', err);` | `console.error('Failed to load courier reconciliation...', err);` |
| 32 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.ts` | 105 | `get activeFleetCount(): number` | `get activeCouriersCount(): number` |
| 33 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 11 | `<strong>{{ activeFleetCount }}</strong>` | `<strong>{{ activeCouriersCount }}</strong>` |
| 34 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 78 | `{{ activeFleetCount }}` | `{{ activeCouriersCount }}` |
| 35 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 88 | `[class.active]="activeTab === 'fleet'"` | `[class.active]="activeTab === 'couriers'"` |
| 36 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 100 | `*ngIf="activeTab === 'fleet'"` | `*ngIf="activeTab === 'couriers'"` |
| 37 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 110 | `<!-- TAB 1: FLEET ACTIVE RECONCILIATION -->` | `<!-- TAB 1: ACTIVE COURIER RECONCILIATION -->` |
| 38 | Dashboard | `src/app/pages/reconciliation/components/reconciliation-list/reconciliation-list.component.html` | 111 | `<div class="ops-orders-card" *ngIf="activeTab === 'fleet'">` | `...*ngIf="activeTab === 'couriers'"` |

---

## 6. Prioritized Issue Catalog

| ID | Subsystem | Severity | Issue Description | Exact File & Line Reference | Fix Recommendation |
|---|---|---|---|---|---|
| **DSH-01** | Dashboard | **Critical** | Production build fails due to SCSS budget violation (14 components exceed 4 kB) | `angular.json:44` | Increase budget to 12 kB warning / 16 kB error |
| **DSH-02** | Dashboard | **Critical** | Order status code inversion: rejected orders shown as in-transit, delivered as under review | `orders-list.component.ts:63–79, 321–334`, `dashboard.component.ts:292–306` | Align status codes to backend `OrderDetailStatus` enum |
| **DSH-03** | Dashboard | **Critical** | HTTP Interceptor swallows all HTTP errors via `return of(err)`, breaking `.subscribe({ error })` | `http.interceptor.ts:91` | Replace `of(err)` with `throwError(() => err)` |
| **DSH-04** | Dashboard | **Critical** | HTTP Interceptor calls `logout()` on uninitialized `authService` on refresh token request | `http.interceptor.ts:33` | Remove premature logout; resolve `AuthService` safely via Injector |
| **DSH-05** | Dashboard | **High** | Session restore token refresh is cold observable without `.subscribe()`, rendering it dead code | `auth.service.ts:59–79` | Chain `.subscribe()` to trigger refresh on startup |
| **DSH-06** | Dashboard | **High** | Real-time GPS & Live Radar disconnect: `@microsoft/signalr` missing, using 4s HTTP polling | `package.json`, `live-track-modal.component.ts:41` | Install `@microsoft/signalr`, build live radar hub service |
| **DSH-07** | Dashboard | **High** | `TableService.fetchPost()` causes unbounded subscription array growth (memory leak) | `table.service.ts:181` | Cancel/clean previous subscription before initiating next fetch |
| **DSH-08** | Dashboard | **Medium** | Language switch from user profile dropdown does not update layout direction or reload | `user-inner.component.ts:38` | Invoke `setLayoutDirection()` or uncomment `document.location.reload()` |
| **DSH-09** | Dashboard | **Medium** | Redundant RTL stylesheet import (`styles.scss` imports it + `app.component.ts` injects link tag) | `styles.scss:4`, `app.component.ts:82–86` | Keep bundled import in `styles.scss`; remove dynamic link injection |
| **DSH-10** | Dashboard | **Medium** | Google Maps API key hardcoded in `index.html` | `index.html:20` | Externalize key to `environment.ts` and restrict by domain |
| **DSH-11** | Dashboard | **Medium** | Two orphaned dead files referencing non-existent modules break root `tsc` | `refrences.model.ts:1–3`, `auth-http/index.ts:2` | Delete or clean up orphaned model and stub export |
| **DSH-12** | Ecosystem | **Medium** | Prohibited term risk: 38 occurrences of "fleet" across backend and dashboard identifiers | 38 files listed in Section 5.2 | Rename "fleet" tokens to "courier" / "captain" across controllers & SignalR |
| **DSH-13** | Dashboard | **Low** | No local offline font fallback for `IBM Plex Sans Arabic` | `index.html:12` | Bundle local `.woff2` font files under `src/assets/fonts` |
| **DSH-14** | Dashboard | **Low** | Method typo: `setDelievry` in `OrdersService` | `orders.service.ts:35` | Rename method to `setDelivery` |
