# Progress Tracker - Security & Contracts Explorer

**Last visited**: 2026-09-13T20:05:00Z
**Status**: INVESTIGATION_COMPLETE

## Tasks
- [x] R1.1 Master OTP & bypass eradication verification (`OAuthTokenController.cs`, OTP services)
  - Release build compiles out `#if DEBUG` bypass
  - Found critical plaintext OTP exposure in `AccountController.cs:325` (`return code;`)
  - Found hardcoded admin credentials in `jtak-mobile-delivery-master/lib/src/core/controllers/user_provider.dart:76-77`
  - Proof of delivery OTP comparison verified in `OrdersController.cs:556-565`
- [x] R1.2 IDOR authorization guardrails verification (`AddressController.cs`, `BatchesController.cs`)
  - `AddressController.cs` strictly enforces caller ownership (`entity.UserId != uid.Value`)
  - `BatchesController.cs` (Warehouse) strictly scopes queries and mutations to caller's `merchantIds`
- [x] R1.3 SignalR telemetry hub authorization & dispatch group policies (`TrackingHub.cs`)
  - `JoinCourierRadar` and `JoinFleetRadar` strictly require `AdminPermission`
  - `JoinOrderTracking` requires authentication, but lacks order ownership check
- [x] R1.4 OpenIddict key persistence & token survivability (`Program.cs`, startup)
  - Data Protection keys persisted to `keys/` directory
  - Development signing/encryption certificates used (production X.509 cert loading commented out)
  - Directory path `"keys"` is relative
- [x] R2.1 Order status enum parity & inversion check (Backend, Dashboard, Customer, Delivery, Warehouse)
  - Backend, Dashboard, Customer, and Warehouse aligned (0..7)
  - Status inversion on Dashboard is resolved
  - Defect found: Delivery app `order_details_status_enum.dart` lacks `deliveryCanceled = 7` and throws exception
- [x] R2.2 Customer cart item cleanup upon re-ordering or new cart creation
  - Backend `CartController.cs` purges existing pending order details before adding new items
  - Mobile `CartProvider` purges local cart and storage on submit and replace
- [x] R2.3 Product review entity mapping (`ProductId`) across all layers
  - Backend `ProductReviewsController.cs:129` correctly maps `ProductId = x.ProductId`
  - Defect found: `Customer/ProductReviewsController.cs:147` lacks IDOR ownership check on `Delete`
  - Defect found: Mobile `reviews_widgets.dart:55` passes `item.productId` instead of `item.id` to delete
- [x] R2.4 Dual-broadcast SignalR telemetry streams (`OnCourierLocationUpdated` & legacy fallbacks)
  - Backend dual-broadcasts `OnCourierLocationUpdated` & `OnFleetLocationUpdated`
  - Dashboard consumes both streams in `signalr-tracking.service.ts`
- [ ] Synthesize findings and write structured 5-component `handoff.md`
- [ ] Update `BRIEFING.md`
- [ ] Send completion message to parent
