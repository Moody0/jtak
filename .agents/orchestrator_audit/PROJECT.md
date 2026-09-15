# Project: JTAK Ecosystem Pre-Production Quality, Security & User Journey Audit

## Architecture & Ecosystem Scope
The JTAK platform consists of 5 primary software repositories, shared database scripts, and real-time communication channels:
1. **jtak-backend-main**: ASP.NET Core Web API with Entity Framework Core, SignalR Hubs for real-time order and driver tracking, Redis caching/messaging, JWT authentication.
2. **jtak-dashboard-main**: Angular SPA dashboard for Admin operations, order oversight, captain assignment, live radar, financial reconciliation.
3. **jtak-mobile-master**: Customer Flutter mobile application (product browsing, cart, checkout, address management, live order tracking).
4. **jtak-mobile-delivery-master**: Delivery Captain Flutter mobile application (order acceptance, GPS telemetry streaming, route fulfillment, proof-of-delivery OTP/PIN).
5. **jtak-mobile-warehouse-master**: Merchant/Warehouse Flutter mobile application (order notifications, batch preparation, status updates).
6. **Database & Schema**: SQL migration scripts, PostgreSQL/SQL Server schemas, Entity Framework Core migrations, indexes, constraints, and data integrity.

## Feature Inventory & Audit Matrix
| # | Feature / Area | Description | Milestone | Source |
|---|----------------|-------------|-----------|--------|
| 1 | Backend Diagnostics & Build | .NET compile, warnings, null safety, exception handling, deprecated APIs | M1: Backend Audit | R1 |
| 2 | Dashboard Diagnostics & Build | Angular/TS compilation, lint, type safety, deprecated APIs | M2: Dashboard Audit | R1 |
| 3 | Mobile Apps Diagnostics & Build | Flutter analyze across Customer, Delivery, and Warehouse apps | M3: Mobile Apps Audit | R1 |
| 4 | Database Schema & Data Integrity | EF Core migrations, SQL scripts, FK constraints, indexes, nullability drift | M4: Database Integrity | R3 |
| 5 | End-to-End User Journeys | 4 user roles: Customer, Merchant, Captain, Admin lifecycle verification | M5: E2E Journeys & API Contracts | R2 |
| 6 | API Contract Matrix & Enums | Cross-system endpoint, payload, enum, and status code synchronization | M5: E2E Journeys & API Contracts | R2 |
| 7 | Real-time GPS & Telemetry | SignalR hubs, WebSocket protocols, driver telemetry, radar sync | M5: E2E Journeys & API Contracts | R2 |
| 8 | Terminology Compliance ("أسطول") | Ecosystem-wide zero-tolerance search for prohibited term "أسطول" | M6: Terminology & UI/UX | R4 |
| 9 | UI/UX & RTL Localization | Arabic RTL layout, mirror rendering, font rendering, responsive UI | M6: Terminology & UI/UX | R4 |
| 10 | Adversarial & Forensic Verification | Independent challenger verification and forensic integrity checks | M7: Challenger & Forensic Audit | Verification |
| 11 | Deliverable Synthesis | Synthesis into AUDIT_REPORT.md and REMEDIATION_PLAN.md | M8: Synthesis & Delivery | R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend Diagnostic & Security Audit | `jtak-backend-main` compile, controllers, auth, exceptions, SignalR | None | IN_PROGRESS |
| M2 | Dashboard Diagnostic & UX Audit | `jtak-dashboard-main` compile, Angular components, services, radar | None | IN_PROGRESS |
| M3 | Mobile Apps Diagnostic Audit | Customer, Delivery, Warehouse `flutter analyze`, null safety, models | None | IN_PROGRESS |
| M4 | Database Schema & Integrity Audit | EF Core migrations, SQL scripts (`update_production_db.sql`), schema drift | M1 | IN_PROGRESS |
| M5 | E2E Journeys & API Contract Matrix | 4 roles lifecycle, endpoint matrix, enum parity, GPS tracking | M1, M2, M3 | IN_PROGRESS |
| M6 | Terminology & Arabic RTL Audit | Scan all files for prohibited term "أسطول", RTL layouts, Arabic strings | None | IN_PROGRESS |
| M7 | Challenger & Forensic Verification | Adversarial stress testing, verify zero unauthorized file modifications | M1-M6 | PLANNED |
| M8 | Final Synthesis & Phased Remediation Plan | Produce AUDIT_REPORT.md and REMEDIATION_PLAN.md | M7 | PLANNED |

## Code Layout & Write Boundaries
- **Strict Rule**: ZERO modifications to any source code in `jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`, or `.sql` files.
- **Allowed Write Paths**: Subagent working directories under `.agents/` and final deliverable markdown files:
  - `D:\work\jtak\.agents\AUDIT_REPORT.md`
  - `D:\work\jtak\.agents\REMEDIATION_PLAN.md`
  - `D:\work\jtak\AUDIT_REPORT.md` (root copy for user convenience)
  - `D:\work\jtak\REMEDIATION_PLAN.md` (root copy for user convenience)
