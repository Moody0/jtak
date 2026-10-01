# Restaurant + market checkout

One checkout may contain one restaurant and one market. It creates two independent orders, not a multi-stop order shared between the merchants.

## Order ownership and money

- Each child order contains only its merchant's products, delivery fee, commission snapshot, driver wage, cash-to-collect amount and delivery OTP.
- Each merchant decides only its own order. Its three-minute driver-matching window starts after its acceptance; the other merchant does not have to accept first.
- A merchant rejection or no-driver timeout cancels only that child order. The other order can proceed and be delivered independently.
- Each order is offered, claimed, tracked, delivered and accounted for by its own order ID. The two orders may have different drivers and arrival times.
- Captain earnings remain a platform/driver accounting amount, not an additional charge to the customer. Each order snapshots the existing admin driver-pricing configuration separately.
- The customer's combined checkout confirmation is display-only. Never use its combined total as a child order's COD amount or ledger posting.

Example: restaurant products 2,725.50 SYP + its 100 SYP delivery fee = 2,825.50 SYP COD. Market products 135 SYP + its 70 SYP delivery fee = 205 SYP COD. Combined checkout display: 3,030.50 SYP. Each driver collects only their assigned order's amount; their wage is not added again.

## Changes in this patch

- Fresh checkout and idempotent replay expose nullable `merchantKind` on the order response; replay also preserves the COD payment method.
- Customer confirmation includes both orders' products, separate collection amounts, combined delivery fees and total, without truncating fractional SYP amounts.
- Tracking selectors distinguish the restaurant and market even when legacy detail payloads omit merchant kind. Explicit type survives local persistence and reordered responses.
- Local display enrichment matches both product ID and merchant ID and preserves server IDs, status, timestamps, destination and money for each child.
- Cart/payment/confirmation explain separate fees, COD, tracking, cancellation and possible different arrival times. Confirmation does not claim preparation has started before a driver accepts.
- Failed InMemory checkout compensation also removes queued creation notifications. Relational checkout rolls both child inserts and outbox messages back in its transaction.
- Phone-width confirmation rows wrap instead of overflowing.

`merchantKind` is DTO-only: no database schema migration or SQL synchronization file is required for this patch. No APK, publish folder or release ZIP was produced.

## Verification

Automated checks cover valid/invalid cart mixes, same-key replay without extra orders/events, separate delivery fees and wages, combined COD equality, stock-failure rollback (InMemory and SQLite), independent merchant rejection, independent dispatch timers and timeout cancellation, missing/reordered merchant types, shared product IDs, response snapshot preservation and phone-width confirmation layout.

Before rollout, perform a physical-device test: check out from both merchants, accept only the restaurant, verify only that order is offered, then reject the market. Complete the restaurant delivery and compare the driver's collected cash/wage, merchant statement and admin ledger against that order alone. Repeat with both accepted and two different drivers.

## Broader review limitations

This targeted change is not whole-system production sign-off. The prior review identified separate crash-recovery/concurrency risks requiring follow-up: merchant acceptance and matching-window initialization use separate saves; timeout completion and item cancellation use separate writes; driver assignment can precede route creation; simultaneous claims can exceed projected uncollected COD exposure. The independence regression tests above do not simulate process termination at those boundaries. Production MariaDB, push notifications and real devices still require end-to-end verification.
