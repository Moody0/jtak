# Driver earnings and COD custody

These are local source changes only. No APK, publish folder, ZIP, deployment,
or database import was produced for this change.

## Money rules

- Customer collection remains the server-calculated order total minus any
  prepaid amount. Driver earnings are a separate allocation, not an extra
  customer charge. For goods of 1,887 SYP and delivery of 100 SYP, collect
  1,987 SYP even when the driver's wage is 50 SYP.
- A displayed order wage is the expected entitlement. The wallet recognizes
  earnings from posted delivery ledger entries, not merely accepting an order.
- COD custody is money held for JTAK. It must not be presented as withdrawable
  earnings or deducted by the driver without an explicit recorded settlement.
- Wallet totals distinguish lifetime net earnings, paid/offset earnings,
  unpaid earnings, reserved requests and available earnings. Correction and
  reversal entries are not reported as cash payouts. Fractional SYP values are
  preserved to two decimal places.

## Driver and dashboard workflow

1. In the driver app, open the Finance tab. The earnings card is separate from
   the COD custody card. Submit an earnings payout request within the available
   balance; custody remittance remains a different action.
2. In the dashboard, open Settlements, then the couriers tab, then the separate
   driver earnings requests table.
3. Approval reserves earnings only. It does not mean money has been handed over.
   A pending or approved request can be rejected before actual payment, releasing
   its reservation.
4. After physically paying the driver, confirm actual payment in the dashboard.
   This debits driver earnings liability and credits the company cash vault;
   it does not reduce COD custody. Insufficient treasury funds prevent posting.
5. Repeating payment confirmation returns the already completed transaction.
   A stable journal idempotency key and financial transactions prevent duplicate
   posting. Concurrent requests must not reserve or spend the same earnings twice.
6. Existing end-of-day settlement can explicitly offset earnings against COD
   custody. Finish or reject any active custody/payout request first. An offset
   counts as paid earnings, preventing a second withdrawal. If there is no COD
   custody, use the earnings payout workflow instead.

Pending or failed delivery accounting blocks new earnings reservations, approval
and payment until accounting is resolved. A failed refresh after successful
submission does not change that submission into a failure. An older balance
response cannot erase the newly reserved request.

## API and schema

- Delivery balances: `POST /api/v1/Delivery/Balances/Mine` retains custody fields
  and adds an `earnings` wallet containing the driver's own payout history.
- Earnings request: `POST /api/v1/Delivery/Balances/RequestEarningsPayout`.
- Admin approval/rejection retain the settlement request routes.
- Actual payment: `POST /api/v1/Admin/SettlementRequests/{id}/CompleteDriverEarnings`.
- Existing custody remittance routes remain separate.
- `SettlementPartyType.CaptainEarnings = 2` uses the existing byte field and
  settlement tables. This feature itself adds no database columns or tables;
  this is not confirmation that an older production schema is fully up to date.
- Old backend responses without an earnings wallet disable payout in the updated
  app; they never substitute custody cash for earnings.

## Local verification — 2026-09-30

- Backend accounting suite: 309 passed, zero failed or skipped. Includes actual
  ledger tests, insufficient balance/vault guards, reservation release, order
  reversals, EOD offsets and concurrent requests/payment confirmation.
- Driver app suite: 81 passed. Includes Arabic small-screen/large-text rendering,
  amount validation, customer total invariance, reserved request states, refresh
  failure and stale-response regression tests.
- Dart analysis of all eight changed driver files: no issues found.
- Dashboard earnings tests: five passed in headless Chrome. Template/type
  verification (`ngc --noEmit`) succeeded; existing NG8107 optional-chain warnings
  remain in other dashboard templates.
- Concurrency tests use independent relational SQLite contexts; a small adapter
  handles SQLite's decimal aggregation limitation. They do not replace testing
  actual MariaDB locking and server behavior.

Before a coordinated release, verify one real COD delivery, custody remittance,
approval, physical earnings payment and receipt on the target MariaDB-backed
server. Local tests are evidence, not a guarantee that every possible defect or
production configuration problem is absent.
