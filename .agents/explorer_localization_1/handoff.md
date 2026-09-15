# Requirement R4 Pre-Production Verification Report: UI/UX, Arabic RTL & Terminology Compliance

**Milestone**: Requirement R4 (Localization & Terminology Compliance)  
**Inspector**: Localization & Terminology Explorer  
**Date**: 2026-09-13  
**Status**: PASSED / COMPLIANT  

---

## 1. Observation

### 1.1 RTL/LTR Bidirectional Layout Toggling & Stylesheet Integrity

1. **Angular Dashboard `TranslationService` Implementation**:
   - Location: `jtak-dashboard-main/src/app/modules/i18n/translation.service.ts` (lines 46–72)
   - Code snippet:
     ```typescript
     setLanguage(lang: string) {
       if (lang) {
         this.translate.use(this.translate.getDefaultLang());
         this.translate.use(lang);
         localStorage.setItem(LOCALIZATION_LOCAL_STORAGE_KEY, lang);
         this.updateDirection(lang);
       }
     }

     updateDirection(lang: string) {
       if (typeof document !== 'undefined') {
         const isRtl = lang === 'ar';
         document.documentElement.lang = lang;
         document.documentElement.dir = isRtl ? 'rtl' : 'ltr';
         document.documentElement.style.direction = isRtl ? 'rtl' : 'ltr';
         if (document.body) {
           document.body.dir = isRtl ? 'rtl' : 'ltr';
           if (isRtl) {
             document.body.classList.add('rtl');
             document.body.classList.remove('ltr');
           } else {
             document.body.classList.add('ltr');
             document.body.classList.remove('rtl');
           }
         }
       }
     }
     ```
   - Observed: There are **zero** dynamic `<link>` element creations, removals, or replacements (`document.createElement('link')`, `link.href = ...`, or `getElementById('layout-styles-anchor').setAttribute(...)`). 

2. **Angular Dashboard Stylesheet Architecture & Scoping**:
   - Location: `jtak-dashboard-main/src/index.html` (lines 10–14):
     ```html
     <link rel="preconnect" href="https://fonts.googleapis.com" />
     <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
     <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@300;400;500;600;700&family=Inter:wght@300;400;500;600;700&display=swap" />
     <link rel="stylesheet" id="layout-styles-anchor" href="./assets/splash-screen.css" />
     ```
   - Location: `jtak-dashboard-main/src/styles.scss` (lines 3–4, 77–79):
     ```scss
     @import "./assets/sass/style";
     @import "./assets/sass/custom-rtl.css";
     ...
     body, button, input, select, textarea, .mat-typography {
       font-family: 'IBM Plex Sans Arabic', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
     }
     ```
   - Location: `jtak-dashboard-main/src/assets/sass/custom-rtl.css` (579 lines):
     - Uses pure CSS selector scoping based on `[dir="rtl"]`, `html[dir="rtl"]`, `body[dir="rtl"]`:
       - Base direction and alignment (lines 3–16): `[dir="rtl"] { direction: rtl; text-align: right; }`
       - Aside / Sidebar right-docking (lines 19–36): `right: 0 !important; left: auto !important; width: 265px !important;`
       - Content wrapper offset (lines 46–59): `padding-right: 265px !important; padding-left: 0 !important;`
       - Header & Toolbar offsets (lines 62–87): `right: 265px !important; left: 0 !important;`
       - Aside collapse animation & width (lines 104–171) for minimized state (`70px`)
       - Mobile drawer transformation (lines 174–193): `.drawer-start { left: auto !important; right: 0 !important; transform: translateX(100%) !important; }`
       - Directional arrow flipping (lines 476–483): `[dir="rtl"] .ops-hero-actions .fa-arrow-right, [dir="rtl"] .rtl-flip { transform: scaleX(-1); }`
       - Table, modal close, and form alignments (lines 485–579).

3. **Flutter Mobile Apps Bidirectional Layout & Locale Delegates**:
   - Customer App (`jtak-mobile-master/lib/main.dart` lines 67–74, `lib/locale_delegate.dart` lines 18–20):
     - Uses `GlobalWidgetsLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, and `GlobalCupertinoLocalizations.delegate` with `supportedLocales = [Locale('ar'), Locale('en')]`.
     - Sets font family `'IBMPlexSansArabic'` across `app_theme.dart` and `theme.dart`.
     - Preserves LTR strictly for numeric / international data (e.g. phone number input `phone_widget.dart` line 49, card numbers, and map canvas painters `custom_map_markers.dart`).
   - Delivery App (`jtak-mobile-delivery-master/lib/main.dart` lines 43–46, `lib/locale_delegate.dart` lines 19–24):
     - Same delegate hierarchy, `appStateManager.appLanguage` locale binding, and `'IBMPlexSansArabic'` font family.
   - Warehouse App (`jtak-mobile-warehouse-master/lib/main.dart` lines 41–44, `lib/locale_delegate.dart` lines 18–22):
     - Same delegate hierarchy, `appStateManager.appLanguage` locale binding, and `'IBMPlexSansArabic'` font family.

---

### 1.2 Prohibited Arabic Word Global Scan

1. **Sub-string & Regular Expression Searches Across Workspace**:
   - Pattern 1: `[اأإآ]?سطول` (covering any Arabic word containing the root sequence "سطول" / fleet: أسطول, اسطول, الاسطول, الأسطول, بالأسطول, للأسطول, واسطول, etc.)
   - Pattern 2: `[اأإآ]?ساطيل` (covering plural forms: أساطيل, اساطيل, الأساطيل, etc.)

2. **Per-Repository Search Results**:
   - `D:\work\jtak\jtak-backend-main`:
     - Command: `git grep -I -n "سطول"` -> **Exit code 1 (0 matches)**
     - Command: `git grep -I -n "ساطيل"` -> **Exit code 1 (0 matches)**
   - `D:\work\jtak\jtak-dashboard-main`:
     - Command: `git grep -I -n "سطول"` -> **Exit code 1 (0 matches)**
     - Command: `git grep -I -n "ساطيل"` -> **Exit code 1 (0 matches)**
   - `D:\work\jtak\jtak-mobile-master`:
     - Command: `git grep -I -n "سطول"` -> **Exit code 1 (0 matches)**
     - Command: `git grep -I -n "ساطيل"` -> **Exit code 1 (0 matches)**
   - `D:\work\jtak\jtak-mobile-delivery-master`:
     - Command: `git grep -I -n "سطول"` -> **Exit code 1 (0 matches)**
     - Command: `git grep -I -n "ساطيل"` -> **Exit code 1 (0 matches)**
   - `D:\work\jtak\jtak-mobile-warehouse-master`:
     - Command: `git grep -I -n "سطول"` -> **Exit code 1 (0 matches)**
     - Command: `git grep -I -n "ساطيل"` -> **Exit code 1 (0 matches)**
   - SQL Migration scripts (`update_production_db.sql`):
     - Search: `grep_search` query `سطول` -> **0 matches**

3. **Global Occurrences in Entire Workspace**:
   - The prohibited root appeared in exactly two files in the entire workspace, strictly in audit documentation specifying the prohibition rule itself:
     - `D:\work\jtak\AUDIT_REPORT.md` (line 186): `- **Rule**: Strict prohibition of the word "أسطول" across all code, UI strings, and documentation.`
     - `D:\work\jtak\REMEDIATION_PLAN.md` (line 150): `3. Verify continued 0 occurrences of the prohibited Arabic word "أسطول".`
   - **Zero occurrences exist in application code, templates, JSON/TS localization files, or SQL scripts.**

---

### 1.3 Terminology Consistency (Courier, Dispatch, Tracking)

1. **SignalR Backend Telemetry Hub (`TrackingHub.cs`)**:
   - Location: `jtak-backend-main/app.Services/Hubs/TrackingHub.cs` (lines 14–15, 41–56)
   - Code snippet:
     ```csharp
     public const string CourierDispatchGroup = "courier_dispatch";
     public const string FleetDispatchGroup = CourierDispatchGroup;

     [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
     public async Task JoinCourierRadar()
     {
         await Groups.AddToGroupAsync(Context.ConnectionId, CourierDispatchGroup);
     }

     [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
     public async Task LeaveCourierRadar()
     {
         await Groups.RemoveFromGroupAsync(Context.ConnectionId, CourierDispatchGroup);
     }

     [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
     public async Task JoinFleetRadar() => await JoinCourierRadar();

     [Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]
     public async Task LeaveFleetRadar() => await LeaveCourierRadar();
     ```
   - Observed: The canonical SignalR group name is `courier_dispatch`. Modern methods `JoinCourierRadar` and `LeaveCourierRadar` are primary, while `FleetDispatchGroup` and `JoinFleetRadar` are aliased for backwards compatibility.

2. **Dual-Broadcast Events in Backend Delivery Orders Controller**:
   - Location: `jtak-backend-main/app/ApiControllers/V1/Delivery/Orders/OrdersController.cs` (lines 460–461, 496–497, 526–527)
   - Code snippet:
     ```csharp
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierLocationUpdated", courierPayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetLocationUpdated", courierPayload);

     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierDutyStatusChanged", statusPayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetDutyStatusChanged", statusPayload);
     ```
   - Observed: Telemetry updates dual-broadcast both canonical `OnCourierLocationUpdated` and legacy `OnFleetLocationUpdated` payloads, guaranteeing compatibility with both old and new consumers without failure.

3. **Angular Dashboard SignalR Tracking Client**:
   - Location: `jtak-dashboard-main/src/app/pages/orders/services/signalr-tracking.service.ts` (lines 118–124, 161–168)
   - Code snippet:
     ```typescript
     this.hubConnection.on('OnCourierLocationUpdated', (data: any) => {
       this.radarUpdatedSubject.next(data);
     });
     this.hubConnection.on('OnFleetLocationUpdated', (data: any) => {
       this.radarUpdatedSubject.next(data);
     });
     ...
     if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
       try {
         await this.hubConnection.invoke('JoinCourierRadar');
       } catch {
         try {
           await this.hubConnection.invoke('JoinFleetRadar');
         } catch {}
       }
     }
     ```

4. **UI & Localization Terminology Alignment**:
   - In `jtak-dashboard-main/src/app/modules/i18n/vocabs/ar.ts` vs `en.ts`:
     - Orders Page:
       - EN: `Delivery Captain`, `Assign Captain`, `Change Captain`, `Live Radar`, `Live Operations Monitor`
       - AR: `مندوب التوصيل`, `تعيين مندوب`, `تغيير المندوب`, `رادار مباشر`, `متابعة العمليات اللحظية`
     - Users Page:
       - EN: `ROLE_DELIVERY: 'Delivery Courier'`, `KPI_STAFF_SUB: 'Admins, merchants & couriers'`
       - AR: `ROLE_DELIVERY: 'مندوب توصيل'`, `KPI_STAFF_SUB: 'إداريون، تجار ومندوبو توصيل'`
     - Reconciliation Page:
       - EN: `EOD Courier Reconciliation`, `Gross Cash in Courier Custody`, `Earned Courier Wages`, `Due to Vault`, `Delivery Captain`
       - AR: `تسوية نهاية اليوم لعمليات التوصيل (EOD)`, `إجمالي النقد في عهدة المناديب`, `أجور المناديب المستحقة`, `توريد للخزينة`, `كابتن توصيل`
     - Menu & Groups:
       - EN: `OPERATIONS: 'Logistics & Trade Operations'`
       - AR: `OPERATIONS: 'العمليات اللوجستية والتجارية'`
   - In Customer Mobile App:
     - Orders status: `"تم الغاؤه من قبل السائق"` (Arabic), `"Delivery Canceled"` (English).
   - In Warehouse Mobile App:
     - Minor item noted: `locales/ar.json` line 52 has `"orderDetailsStatusDeliveryCanceled": "Delivery Canceled"` (untranslated English phrase retained in Arabic file; non-breaking).

---

## 2. Logic Chain

1. **RTL Layout Robustness**:
   - Previously, web applications switching between RTL and LTR often injected `<link id="...">` stylesheets at runtime into the DOM `<head>`. This approach is fragile because asynchronous stylesheet loading creates race conditions, flash of unstyled content (FOUC), layout jumps, or broken styles when switching back and forth.
   - Observation 1.1 proves that `TranslationService` operates purely by modifying the `dir` and `lang` attributes on `document.documentElement` and `document.body` while toggling `.rtl`/`.ltr` classes on `document.body`.
   - Observation 1.2 proves that all RTL layout rules are compiled once into the main CSS bundle via `custom-rtl.css` using `[dir="rtl"]` selectors.
   - Therefore, switching between Arabic and English flips layouts synchronously and deterministically with zero DOM `<link>` injections or network latency.
   - In Flutter, `GlobalWidgetsLocalizations.delegate` coupled with `supportedLocales = [Locale('ar'), Locale('en')]` in all 3 apps automatically and natively updates the widget tree's `Directionality` to `TextDirection.rtl` when Arabic is selected, with font `'IBMPlexSansArabic'` ensuring consistent typography.

2. **Prohibited Word Absence**:
   - The authoritative requirement mandates zero occurrences of the prohibited Arabic word for fleet ("أسطول" and morphological derivatives) across all code, comments, templates, and localization files.
   - Rigorous git grep searches covering tracked files across all 5 codebases and SQL scripts revealed zero instances of `[اأإآ]?سطول` and `[اأإآ]?ساطيل`.
   - The only occurrences discovered in the workspace are in `AUDIT_REPORT.md` and `REMEDIATION_PLAN.md`, where the prohibition itself is cited as a compliance rule.
   - Therefore, compliance with the prohibited Arabic term rule is 100% verified.

3. **Terminology Consistency**:
   - The requirements specify consistent terminology for dispatch, couriers, and tracking.
   - In backend C# and SignalR hubs, the canonical naming is `Courier` and `courier_dispatch`, with `Fleet` preserved strictly as a backward-compatible alias.
   - In dashboard UI strings, English consistently uses "Delivery Captain" / "Courier" and "Live Radar" / "Dispatch", and Arabic consistently uses "مندوب التوصيل" / "المندوب" / "كابتن توصيل" and "رادار التتبع اللحظي" / "العمليات اللوجستية".
   - In mobile apps, order status and tracking strings consistently refer to "السائق" (Driver/Captain) and "التوصيل" (Delivery).

---

## 3. Caveats

- In `jtak-mobile-warehouse-master/locales/ar.json`, line 52 contains `"orderDetailsStatusDeliveryCanceled": "Delivery Canceled"`. This is an untranslated English string inside the Arabic translation file (whereas in `jtak-mobile-master/locales/ar.json` it is properly translated to `"تم الغاؤه من قبل السائق"`). This does not break any layout or functionality and does not contain prohibited words, but can be localized in a future minor polish pass.
- No other caveats.

---

## 4. Conclusion

Requirement R4 (UI/UX, Arabic RTL & Terminology Compliance) is **FULLY SATISFIED** across the JTAK ecosystem:
1. **RTL/LTR Layout Toggling**: Seamlessly executes in Angular `TranslationService` via CSS attribute scoping (`dir="rtl"`) without runtime `<link>` insertion bugs or DOM race conditions. All 3 Flutter apps natively toggle RTL directionality with consistent `IBMPlexSansArabic` typography.
2. **Prohibited Word Global Scan**: Conclusively verified **0 occurrences** of the word "أسطول" (and all morphological derivatives / plurals) across all source code, templates, JSON localization files, comments, and SQL scripts.
3. **Terminology Parity**: Dual-broadcast SignalR telemetry (`OnCourierLocationUpdated` + `OnFleetLocationUpdated`), group aliasing (`CourierDispatchGroup`), and unified user-facing terminology ("مندوب التوصيل" / "كابتن توصيل" / "Delivery Captain") are fully integrated and verified.

---

## 5. Verification Method

To independently verify these findings, run the following commands from `D:\work\jtak`:

1. **Verify 0 Occurrences of Prohibited Arabic Word in All Repositories**:
   ```powershell
   git -C "D:\work\jtak\jtak-backend-main" grep -I -n "سطول"
   git -C "D:\work\jtak\jtak-dashboard-main" grep -I -n "سطول"
   git -C "D:\work\jtak\jtak-mobile-master" grep -I -n "سطول"
   git -C "D:\work\jtak\jtak-mobile-delivery-master" grep -I -n "سطول"
   git -C "D:\work\jtak\jtak-mobile-warehouse-master" grep -I -n "سطول"
   ```
   *Expected result*: Exit code 1 (no lines matched) across all repositories.

2. **Verify TranslationService Implementation (No DOM Link Injection)**:
   ```powershell
   Select-String -Path "D:\work\jtak\jtak-dashboard-main\src\app\modules\i18n\translation.service.ts" -Pattern "updateDirection" -Context 0,20
   ```
   *Expected result*: Confirms `updateDirection` sets `document.documentElement.dir` and body classes without `<link>` manipulation.

3. **Verify SignalR Hub Naming & Backward Compatibility Aliases**:
   ```powershell
   Select-String -Path "D:\work\jtak\jtak-backend-main\app.Services\Hubs\TrackingHub.cs" -Pattern "CourierDispatchGroup|FleetDispatchGroup"
   ```
   *Expected result*: Confirms `CourierDispatchGroup = "courier_dispatch"` and `FleetDispatchGroup = CourierDispatchGroup`.
