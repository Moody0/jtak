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
