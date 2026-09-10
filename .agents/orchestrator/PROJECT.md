# Project: JTAK Release Blockers Adversarial Verification

## Architecture
- JTAK Ecosystem:
  - Customer Mobile App: `E:/work/jtak/jtak-mobile-master` (Flutter)
  - Backend API: `E:/work/jtak/jtak-backend-main` (.NET Core / EF Core)
  - Delivery Driver Mobile App: `E:/work/jtak/jtak-mobile-delivery-master` (Flutter)

## Feature & Blocker Inventory
| # | Feature / Fix | Target Files | Verification Scope | Status |
|---|---------------|--------------|-------------------|--------|
| B1 | Main Address GPS & Cart Preservation | `lib/src/core/services/main_address_service.dart` in Customer App | Verify `setMainAddress` default `resetCart: false`, startup GPS check never resets cart | PLANNED |
| B2 | Removal of Admin Token & Customer Products Endpoint | `lib/src/core/controllers/catalog/markets_provider.dart` in Customer App | Verify total removal of admin credentials/endpoints, customer products endpoint integration | PLANNED |
| B3 | Cart Double-Submit & Idempotency Lock | `lib/src/ui/pages/cart/order_payment_page.dart`, `lib/src/core/controllers/order/cart_provider.dart` | Verify `_isSubmitting`, double-tap lock, `ViewState.busy`, UUID idempotencyKey | PLANNED |
| B4 | Driver Phone, Coordinate Fallback & TTL | `lib/src/core/models/order/order_model.dart`, `lib/src/ui/pages/orders/order_details_page.dart` | Verify `deliveryUserPhone`, nullable `LatLng?`, 3-min TTL, dynamic phone dialing & chat name, zero visual/RTL regressions | PLANNED |
| B5 | Backend Customer Catalog Products & Merchants Endpoints | `app/ApiControllers/V1/Customer/Catalog/ProductsController.cs` in Backend | Verify `[HttpGet] [Route("Merchants")]` and `[HttpGet] [Route("Merchants/{mid}/Products")]` | PLANNED |
| B6 | Backend MerchantKind EF Migration & SQL Script | `Modules/Catalog/Modules.Catalog.Data/Migrations/20260910113000_addMerchantKind.Designer.cs`, `sql/apply_20260910113000_addMerchantKind.sql` | Verify EF Core designer schema mapping & SQL correctness | PLANNED |
| B7 | Backend MerchantAccept Decoupling from Active Courier | `app/ApiControllers/V1/Admin/Orders/OrdersController.cs`, `app/ApiControllers/V1/Warehouse/Orders/OrdersController.cs` | Verify MerchantAccept is never blocked with BadRequest when no driver, courier assigned only if found | PLANNED |
| B8 | Delivery App Continuous Background Location Always Enforcement | `lib/src/core/services/location_service.dart` in Delivery App | Verify `LocationPermission.always` in `requireAlwaysPermission()`, upgrade prompt when whileInUse, settings redirect | PLANNED |
| B9 | Static Analysis & Secret Hygiene Execution | Customer App & Delivery App | `flutter analyze` on target files (0 err/0 warn), check no hardcoded secrets/fake phones | PLANNED |
| B10 | Forensic Integrity Audit | All 3 repositories | Binary veto integrity check for facades, hardcoded answers, cheating | PLANNED |

## Milestones & Workstreams
- **M1: Customer Flutter App Review** (B1, B2, B3, B4)
- **M2: .NET Core Backend Review** (B5, B6, B7)
- **M3: Delivery Driver App Review** (B8)
- **M4: Static Analysis, Secret Hygiene & Functional Guardrails Verification** (B9)
- **M5: Forensic Integrity Audit** (B10)
- **M6: Synthesis & Final Orchestration Handoff**
