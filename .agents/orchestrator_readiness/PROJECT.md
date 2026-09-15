# Project: JTAK Pre-Production Verification & Readiness Sign-off

## Architecture
- JTAK Ecosystem:
  - `jtak-backend-main` (.NET 8 Clean Architecture / OpenIddict / EF Core / SignalR)
  - `jtak-dashboard-main` (Angular Admin/Operations Dashboard)
  - `jtak-mobile-master` (Customer Flutter App)
  - `jtak-mobile-delivery-master` (Delivery Captain Flutter App)
  - `jtak-mobile-warehouse-master` (Warehouse/Merchant Flutter App)
  - Database: SQL Server schema & `update_production_db.sql`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1.1 OTP Backdoor Elimination | Verify elimination of master OTP backdoor in OAuthTokenController.cs | M1 | ORIGINAL_REQUEST.md |
| 2 | R1.2 IDOR Guardrails | Verify AddressController.cs & BatchesController.cs reject unauthorized user ID tampering | M1 | ORIGINAL_REQUEST.md |
| 3 | R1.3 SignalR Authorization | Verify TrackingHub.cs authorization and dispatch group policies | M1 | ORIGINAL_REQUEST.md |
| 4 | R1.4 OpenIddict Key Persistence | Verify persistent signing keys and token survivability across restarts | M1 | ORIGINAL_REQUEST.md |
| 5 | R2.1 Enum Parity | Verify order status enum consistency and absence of status code inversion | M1 | ORIGINAL_REQUEST.md |
| 6 | R2.2 Cart Cleanup | Verify customer cart item cleanup upon re-ordering or new cart creation | M1 | ORIGINAL_REQUEST.md |
| 7 | R2.3 Product Review Mapping | Verify product review entity mapping (ProductId) | M1 | ORIGINAL_REQUEST.md |
| 8 | R2.4 Dual-Broadcast Telemetry | Verify OnCourierLocationUpdated & legacy fallback SignalR streams | M1 | ORIGINAL_REQUEST.md |
| 9 | R3.1 .NET Backend Build & Tests | Clean Release build and test suite execution with 0 errors | M2 | ORIGINAL_REQUEST.md |
| 10 | R3.2 Angular Dashboard Build | Production bundle generation (ng build --configuration=production) with 0 errors | M2 | ORIGINAL_REQUEST.md |
| 11 | R3.3 Mobile Apps Diagnostics | Flutter diagnostics across Customer, Delivery, Warehouse apps | M2 | ORIGINAL_REQUEST.md |
| 12 | R3.4 Database Migration Verification | Verify idempotency and syntax of update_production_db.sql across all tables | M2 | ORIGINAL_REQUEST.md |
| 13 | R4.1 RTL/LTR Layout Toggling | Verify bidirectional layout toggling in TranslationService without link insertion bugs | M3 | ORIGINAL_REQUEST.md |
| 14 | R4.2 Prohibited Word Scan | Strictly verify zero occurrences of prohibited Arabic word across all source/templates/comments | M3 | ORIGINAL_REQUEST.md |
| 15 | R4.3 Terminology Consistency | Verify courier/dispatch terminology consistency across backend hubs and admin UI | M3 | ORIGINAL_REQUEST.md |
| 16 | R5.1 Forensic Integrity & Verification | Forensic audit of all fixes and adversarial stress verification | M4 | ORIGINAL_REQUEST.md |
| 17 | R5.2 Executive Readiness Report | Comprehensive scorecard, deployment guide, Go/No-Go checklist | M5 | ORIGINAL_REQUEST.md |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Security & Contract Verification | R1 (Security) & R2 (Data Flow & Contract Parity) | none | BLOCKED: DEFECTS_FOUND |
| 2 | Build & Migration Verification | R3 (Compilation: .NET, Angular, Flutter, DB Migration) | none | DONE |
| 3 | Localization & Terminology | R4 (RTL/LTR & Prohibited Word & Terminology) | none | DONE |
| 4 | Forensic Integrity & Challenger Audit | Forensic integrity audit & adversarial validation of all claims | M1, M2, M3 | FAILED: INTEGRITY_VIOLATION |
| 5 | Readiness Report & Sign-Off | R5 (Final Go/No-Go Report & Deployment Guide) | M1, M2, M3, M4 | IN_PROGRESS |

## Code Layout & Workspaces
- Backend: `D:\work\jtak\jtak-backend-main`
- Dashboard: `D:\work\jtak\jtak-dashboard-main`
- Customer App: `D:\work\jtak\jtak-mobile-master`
- Delivery App: `D:\work\jtak\jtak-mobile-delivery-master`
- Warehouse App: `D:\work\jtak\jtak-mobile-warehouse-master`
- Database Script: `D:\work\jtak\update_production_db.sql` or relevant db paths
