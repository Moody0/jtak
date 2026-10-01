# Live tracking correction — local source changes, 30 September 2026

## Location contract

- The delivery destination is the saved pin for this order. Neither the customer's current GPS nor their currently selected address replaces it.
- The driver marker comes only from fresh same-order driver telemetry. Missing/stale coordinates must not become a default city or a merchant pickup pin.
- New driver clients send GPS capture time and reported accuracy. They reject fixes older than 60 seconds, more than 30 seconds in the future, or with reported accuracy worse than 100 metres.
- The API validates incoming coordinates/metadata, preserves capture time, ignores older fixes, and serializes UTC timestamps explicitly. Older clients without metadata remain compatible, but do not receive the new client-side accuracy protection until updated.
- Customer tracking treats legacy zone-less server timestamps as UTC and only displays live fixes up to 90 seconds old. It rejects responses for a different order and hides driver GPS after delivery/cancellation/rejection.
- The map focuses on the driver instead of zooming across countries when the saved destination is more than 100 km away. This does not modify the destination.
- ETA is an explicitly approximate straight-line estimate, not road-routing data. Missing route coordinates, stale GPS, regional distances, or estimates over 180 minutes produce an unavailable ETA, not an invented/capped number.
- Order details and telemetry refresh together every four seconds without overlapping refreshes; GPS animation starts outside widget build.

## Local verification

Customer regression fixtures were corrected to distinguish authoritative SYP final prices from USD fallback pricing and to match existing localized price formatting and store labels. No customer price formula was altered to satisfy those tests.

Run the full suites from their respective directories:

```powershell
# jtak-backend-main
dotnet test Modules.Accounting.Tests/Modules.Accounting.Tests.csproj --no-restore -p:RollForward=Major
# jtak-mobile-master and jtak-mobile-delivery-master separately
E:/flutter/flutter/bin/flutter.bat test --no-pub
```

API/controller coverage includes fresh Homs coordinates, stale GPS, terminal orders, invalid pickup coordinates, UTC serialization, and unauthorized customer access. Driver coverage includes stationary heartbeats, actual capture metadata, inaccurate fixes, and stale cached fixes. Customer coverage includes cross-order response races, absent coordinates, legacy timezones, terminal orders, and unavailable ETA. UTC is the internal timestamp standard, not an app country or display-timezone setting.

## Release and real-phone check

These fixes are not part of the previously uploaded `server-release-20260930` ZIPs. No APK, ZIP or production publish was created for this correction. There are no new database columns or SQL migrations.

When release is authorized, deploy the updated backend and update both the customer and driver apps. The dashboard and warehouse app have no source changes in this correction.

For a Homs test, choose a Homs delivery pin at checkout, enable precise GPS on the driver phone, accept/assign and start delivery, and compare the driver's reported position against its phone map. The saved order address remains unchanged if either phone moves elsewhere. Disable GPS long enough for telemetry to expire and verify the driver marker/ETA become unavailable; complete or cancel the order and verify continuing driver movement is no longer visible.

Automated tests cannot establish the physical accuracy of a real phone or verify the current production payload for order #61. That requires the real-phone check; no existing production order/address was edited.
