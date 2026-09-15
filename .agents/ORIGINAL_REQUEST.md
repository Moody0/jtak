# Original User Request

## 2026-09-10T11:32:15Z

Focused adversarial review and verification of the line diffs and architectural fixes made for the 7 critical release blockers across the JTAK ecosystem (Customer Flutter App, .NET Core Backend, Delivery Driver Flutter App), verifying strict adherence to the remediation plan, zero regressions, and clean static analysis.

Working directory: E:/work/jtak
Integrity mode: development

## Requirements

### R1. Line Diff Audit for Customer Flutter App (jtak-mobile-master)
- Review `lib/src/core/services/main_address_service.dart`: verify `setMainAddress` default `resetCart: false` and that startup GPS coordinate check never resets the customer's cart.
- Review `lib/src/core/controllers/catalog/markets_provider.dart`: verify total removal of hardcoded admin credentials and admin token request methods, and verify integration with the customer products endpoint.
- Review `lib/src/ui/pages/cart/order_payment_page.dart` & `lib/src/core/controllers/order/cart_provider.dart`: verify submission lock `_isSubmitting`, double-tap prevention, `ViewState.busy` re-entry guard, and client `idempotencyKey` UUID.
- Review `lib/src/core/models/order/order_model.dart` & `lib/src/ui/pages/orders/order_details_page.dart`: verify `deliveryUserPhone` mapping, nullable driver coordinate resolution (`LatLng?`), 3-minute freshness TTL check, dynamic phone dialing, and dynamic driver name in chat.
- Confirm zero visual or styling regressions to existing custom UI, smooth shine skeletons, or RTL alignments.

### R2. Line Diff Audit for .NET Core Backend (jtak-backend-main)
- Review `app/ApiControllers/V1/Customer/Catalog/ProductsController.cs`: verify implementation of `[HttpGet] [Route("Merchants")]` and `[HttpGet] [Route("Merchants/{mid}/Products")]`.
- Review `Modules/Catalog/Modules.Catalog.Data/Migrations/20260910113000_addMerchantKind.Designer.cs` & `sql/apply_20260910113000_addMerchantKind.sql`: verify EF Core designer schema mapping and SQL script correctness.
- Review `app/ApiControllers/V1/Admin/Orders/OrdersController.cs` & `app/ApiControllers/V1/Warehouse/Orders/OrdersController.cs`: verify that `MerchantAccept` is never blocked with `BadRequest` when `bestDelivery.Id == default`, and that courier assignment only executes when a driver is found.

### R3. Line Diff Audit for Delivery Driver App (jtak-mobile-delivery-master)
- Review `lib/src/core/services/location_service.dart`: verify strict enforcement of `LocationPermission.always` in `requireAlwaysPermission()`, upgrade prompt when `whileInUse`, and descriptive error redirecting to app settings when background location is withheld.

## Acceptance Criteria

### Static Analysis & Clean Build
- [ ] `flutter analyze lib/src/ui/pages/orders/order_details_page.dart` runs with 0 errors and 0 warnings.
- [ ] `flutter analyze lib/src/core/services/location_service.dart` runs with 0 errors and 0 warnings.
- [ ] No hardcoded passwords, emails, or fake phone numbers remain in any modified file.

### Functional Guardrails & Plan Adherence
- [ ] Driver coordinates never default to customer residence when missing or null.
- [ ] Checkout submission button cannot be triggered concurrently during in-flight network requests.
- [ ] Merchant order acceptance can proceed even when no courier is immediately in the active pool.
- [ ] Delivery driver app refuses order streaming unless continuous background location ("Always") is granted.

## 2026-09-13T16:12:05Z

Perform a comprehensive pre-production quality, security, and user journey audit across the entire JTAK ecosystem (`jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`, and the database). Deliver a detailed, phased remediation plan cataloging all discovered bugs, broken user journeys, API mismatches, and UI/UX defects for user review prior to server deployment. Do not implement code modifications before user review and approval.

Working directory: D:\work\jtak
Integrity mode: development

## Requirements

### R1. Compiler, Build & Static Code Verification
Run local build and diagnostic tools across all 5 codebases (.NET build for backend, Angular build for dashboard, Flutter analyze for Customer, Delivery, and Warehouse mobile apps). Identify any compilation failures, type errors, deprecated APIs, unhandled exceptions, and missing null checks.

### R2. End-to-End User Journey & API Contract Auditing
Audit the complete operational lifecycle across all user roles:
1. Customer: product browsing, cart, order placement, address selection, live order tracking.
2. Merchant / Warehouse: order notification, batch preparation, status transition to ready.
3. Delivery Captain: order assignment/acceptance, GPS telemetry sync, route fulfillment, proof-of-delivery (OTP/PIN).
4. Admin Dashboard: order oversight, captain assignment, live radar, financial reconciliation.
Verify that all API endpoints, request/response models, and status codes match exactly across the .NET backend and the client applications.

### R3. Database Schema & Data Integrity
Audit database migration scripts, table schemas, foreign key constraints, indexes, and nullability against backend Entity Framework models and SQL scripts. Identify any orphaned records, migration drift, or potential concurrency issues.

### R4. UI/UX, Arabic RTL & Terminology Compliance
Audit UI consistency, responsive layouts, RTL mirroring, and Arabic localization across Dashboard and Mobile apps. Strictly enforce the prohibition of the word "أسطول" anywhere in code, UI strings, and comments.

### R5. Phased Remediation Plan
Synthesize all findings into a structured, prioritized report categorized by severity (Critical / High / Medium / Low). For every issue, specify the exact subsystem, file paths, line references, root cause, and concrete fix proposal. Group all fixes into logical, sequential execution phases (Phase 1: Critical blockers, Phase 2: Integration & Journey fixes, Phase 3: UI/UX & Polish). Do not apply code changes before user review and sign-off.

## Acceptance Criteria

### Verification & Compiler Diagnostics
- [ ] .NET backend build status and warnings documented
- [ ] Angular dashboard build status and lint/compilation checks verified
- [ ] Flutter static analysis completed for Customer, Delivery, and Warehouse applications
- [ ] Database migration and schema consistency verified against EF models

### Journey & Contract Mapping
- [ ] Comprehensive API contract matrix verifying endpoints used by Customer, Delivery, Warehouse, and Dashboard against Backend controllers
- [ ] Identification of any enum/status code mismatches across backend and clients
- [ ] Verification of real-time GPS tracking and SignalR/WebSocket payloads between Delivery app, Backend, and Admin Dashboard

### Deliverables & Plan
- [ ] Structured audit report document created with severity ratings and exact file/line pointers
- [ ] Phased remediation plan clearly dividing work into reviewable implementation phases
- [ ] Strict compliance verification confirming zero occurrences of the prohibited term
- [ ] Zero unauthorized file modifications made to application source code during the audit phase

## 2026-09-13T16:56:58Z

Perform a comprehensive independent pre-production verification and readiness sign-off across all four implemented remediation phases in the JTAK ecosystem (`jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`, and the database). Validate security, business logic consistency, build integrity, real-time GPS telemetry, RTL localization, and deliver a definitive go/no-go deployment checklist.

Working directory: D:\work\jtak
Integrity mode: development

## Requirements

### R1. Security & Authorization Preflight Check
Verify that all security vulnerabilities resolved in Phases 1–3 are impenetrable:
1. Verify complete elimination of the master OTP backdoor (`OAuthTokenController.cs`).
2. Verify IDOR authorization guardrails (`AddressController.cs`, `BatchesController.cs`).
3. Verify SignalR telemetry hub authorization and dispatch group policies (`TrackingHub.cs`).
4. Verify persistent OpenIddict signing keys and token survivability across server recycles.

### R2. End-to-End Contract & Data Flow Parity
Verify seamless inter-system communication across Backend, Dashboard, and Mobile apps:
1. Verify order status enum consistency and absence of status code inversion (Delivered vs Cancelled).
2. Verify customer cart item cleanup upon re-ordering or new cart creation.
3. Verify product review entity mapping (`ProductId`).
4. Verify dual-broadcast SignalR telemetry streams (`OnCourierLocationUpdated` & legacy fallbacks).

### R3. Compilation, Build & Database Migration Verification
Run objective compiler and migration checks:
1. .NET Backend: Clean Release build (`dotnet build jtak.sln -c Release`) with 0 errors and test suite execution (`dotnet test jtak.sln`).
2. Angular Dashboard: Production bundle generation (`ng build --configuration=production`) with 0 errors.
3. Mobile Apps: Flutter diagnostic checks across Customer, Delivery, and Warehouse apps.
4. Database: Verify idempotency and syntax correctness of `update_production_db.sql` across all DbContext tables.

### R4. UI/UX, Arabic RTL & Terminology Compliance
Verify localization and compliance guardrails:
1. Verify bidirectional layout toggling (RTL/LTR) operates seamlessly through `TranslationService` without runtime `<link>` insertion bugs.
2. Strictly verify zero occurrences of the prohibited Arabic word across all source code, templates, and comments.
3. Verify courier and dispatch terminology consistency across backend hubs and admin UI.

### R5. Final Go/No-Go Deployment Report & Pre-Flight Checklist
Synthesize findings into an executive Production Readiness Document containing:
1. Comprehensive scorecard across all 4 phases.
2. Production deployment step-by-step instructions (IIS / Kestrel setup, DB execution order, environment variables).
3. Final Go / No-Go deployment recommendation.

## Acceptance Criteria

### Security & Integrity
- [ ] Confirmation that no master OTP or auth bypass exists in codebase
- [ ] Address and batch controllers reject unauthorized user ID tampering
- [ ] OpenIddict signing certificates are persistent across host restarts

### Lifecycle & Data Parity
- [ ] Order status enum values match 1:1 between backend, dashboard, and mobile clients
- [ ] Real-time courier coordinates broadcast correctly without unhandled exceptions
- [ ] Cart state transitions cleanly without persisting stale items

### Compilation & Scripts
- [ ] .NET backend compiles with 0 errors and 100% test pass rate
- [ ] Angular dashboard compiles in production mode with 0 errors
- [ ] `update_production_db.sql` is verified idempotent and executable

### Compliance & Localization
- [ ] 0 occurrences of the prohibited Arabic word confirmed by global scan
- [ ] RTL/LTR switching verified clean without stylesheet injection errors
- [ ] Final production deployment guide and Go/No-Go recommendation documented

## 2026-09-15T12:03:08Z

Remediate and harden the JTAK production ecosystem (Backend .NET 6, Angular 13 Dashboard, and 3 Flutter apps: Customer, Delivery, Warehouse) against critical order finalization, concurrency, cross-merchant inventory leakage, settlement calculation, electronic payment capture, and status resolution defects while preserving all existing dirty worktree changes and double-entry accounting architecture.

Working directory: D:\work\jtak
Integrity mode: development

## Critical Worktree & Safety Constraints
- The repository contains extensive modified and untracked work. Never execute `git reset`, `git checkout`, `git restore`, `git clean`, or delete/recreate files.
- Preserve the existing money-system, migrations, enum numeric values, Arabic user-facing messages, and API route signatures.
- Audit agents and test-design agents must remain strictly read-only.
- Assign exclusive file ownership to editing agents; never allow multiple agents to modify the same controller, service, or migration concurrently.
- Integrate patches sequentially via an integration agent and verify via an independent read-only verifier.

## Requirements

### R1. Atomic & Recoverable Delivery Finalization (P0)
Fulfill and finalize deliveries with complete atomicity. When an order transitions to `Delivered`, bill dues activation, courier wage posting, merchant payable posting, and delivery queue removal must execute within an atomic relational transaction or a durable, idempotent recovery outbox. Retrying after intermediate failure must safely resume and complete missing financial entries without generating duplicate ledger transactions or second-truth legacy balance discrepancies. Notification and SignalR errors must never produce a false API error after financial commit.

### R2. Concurrency-Safe StartShipping & Database Unique Constraints (P0)
Prevent race conditions and duplicate bill creation during courier merchant pickup. Add an EF migration enforcing a database-level unique constraint on `Bill(OrderId, MerchantId)`. Implement a concurrency-safe upsert and state-transition pattern where retrying or replaying `StartShipping` atomically advances or repairs the state and bill without failing or duplicating.

### R3. Warehouse Authorization, Server-Side Picking & Overselling Prevention (P0)
Enforce merchant data isolation and inventory integrity. Validate merchant ownership before processing barcode scans or stock mutations. Persist durable, server-authoritative picked quantities and states for batch-managed items (disallowing completion of picking until all required batch quantities are verified). Scope stock deductions strictly to the items owned by the authorized merchant, ensuring admin dark-store readiness does not deduct external restaurant items. For cart submission, prevent overselling by enforcing atomic/concurrency-controlled FEFO reservations, compensating and failing cleanly with a customer-facing error if managed stock is insufficient.

### R4. Electronic Payment Lifecycle & Chart-of-Accounts Alignment (P0)
Implement an explicit payment state machine (Pending, Authorized, Captured, Failed, Refunded) with immutable payment provider transaction references. Do not advance orders to fulfillment or post gateway assets merely because `PaymentMethod != COD`; require verified capture confirmation. Align gateway accounting with the seeded `1030-PGW-CLEARING` clearing account and model gateway-to-bank transfers so merchant payouts do not consume unrelated physical cash.

### R5. Immutable Captain Settlement Reservations (P0)
Ensure captain cash settlement settles strictly the immutable requested amount. Admin acceptance must not read or overwrite the settlement request with the captain's live float; verify that current custody is at least the requested amount, move exactly that amount to the company vault, and leave subsequent COD collections in captain custody for subsequent settlement cycles.

### R6. Cross-Context State Consistency & Resilient Notification Dispatch (P1)
Ensure cross-context consistency across cancellation, rejection, and preparation. Customer cancellation must release reservations atomically with status change; merchant rejection must not release stock without updating order items; order readiness must deduct stock atomically. Wrap notification and push dispatches in safe try-catch/outbox blocks so post-commit notification exceptions never surface as 500 errors or cause client retries of already-committed financial actions.

### R7. Universal Semantic Order-Status Truth Table & IDOR Authorization (P1)
Establish a unified semantic truth table resolving aggregate order statuses across mixed-item combinations (e.g. Delivered + Rejected, Delivered + Canceled, Partial Ready, Partial Accepted) uniformly across backend and all three Flutter apps (Customer, Delivery, Warehouse). Replace ad-hoc enum integer comparisons. Audit and secure all delivery endpoints (including `GetStops`, location telemetry, pickup, and delivery) against IDOR vulnerabilities, requiring verified assignment to the calling driver.

### R8. Authoritative Merchant KPIs & Dashboard Operations Hardening (P1 / P2)
Derive merchant sales summaries and KPIs strictly from delivered/active dues and posted ledger transactions, excluding canceled or unearned bills. Include completed settlement workflow payouts in merchant payout totals. In the Admin Dashboard, correct approval modal copy to reflect the prepare → ready → assign flow, disallow cancellation on delivered or terminal orders, and harden bulk cancellation to prevent ambiguous partial failures.

## Acceptance Criteria

### Delivery & Bill Concurrency
- [ ] Delivering an order commits state, bills, ledger entries, and delivery removal atomically, verified by failure injection tests after each step.
- [ ] `Bill(OrderId, MerchantId)` unique constraint exists in a valid EF migration and database schema.
- [ ] Concurrent or repeated `StartShipping` calls for the same order and merchant result in exactly 1 bill record and 0 deadlocks.

### Inventory, Picking & Warehouse Isolation
- [ ] In a mixed order (JTAK Market Dark Store + Restaurant), merchant A cannot pick or deduct items belonging to merchant B.
- [ ] Barcode picking persists scan timestamps and picked quantities in database; `CompletePicking` returns HTTP 400 if required tracked quantities are missing.
- [ ] Two simultaneous checkout orders competing for the last inventory unit allow exactly one order to succeed while the other receives a clear out-of-stock rejection with 0 over-reservations.

### Financial Integrity & Captain Settlement
- [ ] Captain requests settlement for 100, collects additional 50 in COD, admin accepts request: exactly 100 is transferred to vault, and captain cash custody remains exactly 50.
- [ ] Electronic orders remain in pending/unpaid state until payment capture webhook/callback arrives with provider transaction ID; gateway clearing account `1030-PGW-CLEARING` is debited upon capture.
- [ ] Every posted ledger transaction maintains strict equality of debits and credits and satisfies idempotency keys.

### Security, Semantics & Resilience
- [ ] Captain A attempting to read stops, start shipping, or deliver Captain B's order receives HTTP 403 Forbidden.
- [ ] Table-driven unit and integration tests verify identical aggregate order status resolution across backend and Flutter apps for all mixed-state permutations.
- [ ] Simulating notification/push failure immediately after order or settlement commit still returns HTTP 200/Success to the client without state rollback.
- [ ] Full solution compiles (`dotnet build`), tests pass (`dotnet test`), Angular dashboard builds (`npm run build`), and Flutter packages analyze clean (`flutter analyze`).



