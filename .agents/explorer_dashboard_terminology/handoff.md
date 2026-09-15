# Handoff Report: Dashboard & Terminology Audit Specialist

**Subagent**: `explorer_dashboard_terminology`  
**Parent Agent**: `orchestrator_audit` (`658135cc-d555-4d78-a1be-af45e0c20532`)  
**Timestamp**: 2026-09-13T16:21:00Z  
**Deliverable File**: `D:\work\jtak\.agents\explorer_dashboard_terminology\dashboard_terminology_audit.md`  

---

## 1. Executive Summary

A comprehensive pre-production quality, security, architectural, and terminology audit was conducted on the Angular admin dashboard (`jtak-dashboard-main`) and across the entire 5-repository JTAK ecosystem for prohibited terminology.

The audit verified zero source code modifications were performed during this audit phase (Strict Integrity Constraint honored).

### Key Takeaways:
- **Build Status**: Development build compiles cleanly (Exit code: 0, 5.60 MB initial bundle). Production build (`npm run build`) fails with exit code 1 due to 14 component SCSS files exceeding the 4.00 kB budget limit in `angular.json`.
- **Architectural Blocker**: Critical enum inversion between backend `OrderDetailStatus` (0=Pending, 1=MerchantAccepted, 2=ShippingStarted, 3=Delivered, 4=MerchantRejected, 5=CustomerPending) and dashboard frontend (which expects 2=Rejected, 3=UnderReview, 4=InTransit, 5=Delivered). This causes rejected orders to appear as active in-transit deliveries and delivered orders to appear as under review.
- **Security & Interceptor Flaw**: HTTP interceptor swallows errors via `return of(err)`, breaking `.subscribe({ error })` globally, and crashes on token refresh due to accessing uninitialized `authService.logout()`.
- **Real-Time GPS Gap**: `@microsoft/signalr` is not installed; dashboard uses 4s HTTP polling rather than backend SignalR `TrackingHub`.
- **Terminology Compliance**: Zero occurrences of the prohibited Arabic word "أسطول" across all 5 codebases, SQL migrations, and git commit history. An exhaustive inventory of 38 occurrences of the English token "fleet" in backend SignalR groups, controllers, and dashboard components was cataloged with concrete replacement recommendations.

---

## 2. Observation

1. **Angular CLI Build Tooling**:
   - `package.json`: Angular 13.2.1, Angular CLI 13.2.2, TypeScript 4.5.5, RxJS 7.5.2, Bootstrap 5.1.3, ng-bootstrap 11.0.0.
   - Node runtime: `v16.20.2`, NPM: `8.19.4`.
2. **Production Build Command**:
   - Running `npm run build` (`ng build --configuration=production`) failed with exit code 1:
     `Error: D:/work/jtak/jtak-dashboard-main/src/app/pages/products/components/products-list/products-list.component.scss exceeded maximum budget. Budget 4.00 kB was not met by 6.97 kB with a total of 10.97 kB.`
     (14 SCSS files exceeded 4.00 kB).
3. **Development Build Command**:
   - Running `npx ng build --configuration=development` completed with exit code 0 (Hash: `60423d99b5b3d15e`).
4. **TypeScript Diagnostics**:
   - `npx tsc --project tsconfig.app.json --noEmit` exited with code 0.
   - Global `npx tsc --noEmit` flagged orphaned imports in `refrences.model.ts:1,3` and `auth-http/index.ts:2`.
5. **Status Inversion in Orders and Dashboard**:
   - Backend `OrderStatus.cs:21-45`:
     `Pending = 0, MerchantAccepted = 1, ShippingStarted = 2, Delivered = 3, MerchantRejected = 4, CustomerPending = 5, CustomerCanceled = 6, DeliveryCanceled = 7`
   - Dashboard `orders-list.component.ts:63-79, 321-334` and `dashboard.component.ts:292-306`:
     Maps `4` to "In Transit" (actually `MerchantRejected`), `5` to "Delivered" (actually `CustomerPending`), `2` to "Rejected" (actually `ShippingStarted`), and `3` to "Under Review" (actually `Delivered`).
6. **HTTP Interceptor (`http.interceptor.ts`)**:
   - Line 33: calls `this.authService.logout()` before `this.authService = this.injector.get(...)` is executed at line 39.
   - Line 91: `return of(err);` emits error as normal payload, swallowing all HTTP 4xx/5xx exceptions.
7. **Auth Service (`auth.service.ts`)**:
   - Line 59: `this.getAuthByToken(GRANT_TYPES.REFRESH_TOKEN).pipe(...)` has no `.subscribe()`, so it never executes.
8. **SignalR & Live Radar**:
   - `package.json` lacks `@microsoft/signalr`.
   - `live-track-modal.component.ts:41` uses `interval(4000).subscribe(() => this.fetchTelemetry())` via HTTP GET.
9. **Terminology Search**:
   - `grep_search` and `git log -S` for "أسطول", "الأسطول", "أسطولنا", "اسطول": 0 results across `D:\work\jtak`.
   - `grep_search` for "fleet": 38 results across `jtak-backend-main` (28 matches) and `jtak-dashboard-main` (10 matches).

---

## 3. Logic Chain

1. **Production Build Failure**:
   - Observation: 14 component SCSS files exceed 4.00 kB (`angular.json` line 44).
   - Deduction: Modern component stylesheets contain rich CSS for dark/light themes, badges, responsive tables, and custom cards. The 4 kB budget threshold is unrealistically low for an enterprise dashboard. CI/CD production pipelines will consistently fail until this budget is raised to 12 kB / 16 kB.
2. **Order Lifecycle Disruption**:
   - Observation: Backend order detail states are 0=Pending, 1=MerchantAccepted, 2=ShippingStarted, 3=Delivered, 4=MerchantRejected, 5=CustomerPending.
   - Observation: Frontend components render 4 as "جاري التوصيل / In Transit" and 5 as "تم التسليم / Delivered".
   - Deduction: An order item rejected by a merchant (status 4) will appear on the admin dashboard as actively out for delivery with a motorcycle icon. An order completed and delivered by a courier (status 3) will appear as "Under Review". This prevents administrators from properly managing dispatches, returns, and disputes.
3. **Silent Error Cascade**:
   - Observation: `catchError` returns `of(err)` in `http.interceptor.ts:91`.
   - Deduction: Because RxJS considers `of(...)` a successful emission, the error handler in `.subscribe({ error })` is never called. Form submissions, batch updates, and financial settlements that receive 400 or 500 will enter the `next` handler, potentially presenting false success messages to the user while leaving data desynchronized on the backend.
4. **Terminology Compliance Assurance**:
   - Observation: 0 instances of "أسطول" in any file.
   - Observation: UI strings use "المناديب", "الكباتن", and "ورديات التوصيل".
   - Deduction: The Arabic localization is strictly compliant with the prohibition of "أسطول". Renaming the remaining 38 English "fleet" tokens to "courier" / "captain" across backend SignalR groups, controllers, and dashboard components will permanently safeguard against automated translation regressions.

---

## 4. Caveats

- **Runtime Browser Visual Verification**: Tests were conducted via Angular CLI builds, TypeScript diagnostics, and static AST inspection. Full visual verification of dynamic map rendering with Google Maps tiles requires a browser session with a live network connection to Google Maps APIs.
- **Zero Source Edits Applied**: Per the strict audit constraint, no application source code files were modified. All proposed code patches are detailed in the audit report for user review and approval prior to implementation.

---

## 5. Conclusion

`jtak-dashboard-main` is feature-complete with modern UI aesthetics, comprehensive Arabic translation coverage, responsive Metronic-based tables, and financial reconciliation modules. However, it cannot be deployed to production in its current state due to 3 critical blockers:
1. Production build budget failures in `angular.json`.
2. Severe order status code inversion between frontend and backend.
3. HTTP interceptor error swallowing that masks all API failure states.

Once these blockers and the accompanying token refresh and memory leak issues are remediated in Phase 1, the dashboard will achieve pre-production readiness.

---

## 6. Verification Method

To independently verify all findings:
1. **Verify Production Build Failure**:
   ```powershell
   cd D:\work\jtak\jtak-dashboard-main
   npm run build
   ```
   *Expected Result*: Exits with code 1, reporting 14 SCSS files exceeding 4.00 kB budget.
2. **Verify Development Build Success**:
   ```powershell
   cd D:\work\jtak\jtak-dashboard-main
   npx ng build --configuration=development
   ```
   *Expected Result*: Exits with code 0, generates bundles in `dist/dashboard`.
3. **Verify TypeScript Diagnostics**:
   ```powershell
   cd D:\work\jtak\jtak-dashboard-main
   npx tsc --project tsconfig.app.json --noEmit
   ```
   *Expected Result*: Exits with code 0.
4. **Verify Terminology Zero Tolerance ("أسطول")**:
   ```powershell
   # In any ripgrep-enabled environment:
   rg -i "أسطول" D:\work\jtak
   ```
   *Expected Result*: 0 matches found across the entire workspace.
5. **Inspect Audit Report**:
   Inspect `D:\work\jtak\.agents\explorer_dashboard_terminology\dashboard_terminology_audit.md`.

---

## 7. Prioritized Issue Catalog (Summary)

| Severity | Issue Count | Primary Issues |
|---|---|---|
| **Critical** | 4 | DSH-01 (Build budget), DSH-02 (Order status code inversion), DSH-03 (Interceptor error swallowing), DSH-04 (Interceptor refresh token crash) |
| **High** | 3 | DSH-05 (Dead startup token refresh), DSH-06 (Missing SignalR & Live Radar gap), DSH-07 (TableService subscription memory leak) |
| **Medium** | 5 | DSH-08 (Profile language switch desync), DSH-09 (RTL CSS duplication), DSH-10 (Hardcoded Google Maps key), DSH-11 (Orphaned dead model files), DSH-12 (38 English "fleet" tokens) |
| **Low** | 2 | DSH-13 (Missing local Arabic font fallback), DSH-14 (Method typo `setDelievry`) |
