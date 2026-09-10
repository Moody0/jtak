## 2026-09-10T11:34:27Z

```
You are the Customer App Code Reviewer for the JTAK release blockers adversarial verification.
Working Directory: E:/work/jtak/.agents/explorer_customer

MANDATORY INSTRUCTION: Read E:/work/jtak/.agents/ORIGINAL_REQUEST.md and E:/work/jtak/.agents/orchestrator/PROJECT.md before starting work.

Your scope is to perform an exhaustive, line-by-line adversarial code and diff review of the Customer Flutter App in E:/work/jtak/jtak-mobile-master.
Verify the following requirements in detail:
1. `lib/src/core/services/main_address_service.dart`:
   - Check `setMainAddress` signature and implementations.
   - Verify default parameter `resetCart: false`.
   - Verify that startup GPS coordinate check never resets the customer's cart under any flow.
2. `lib/src/core/controllers/catalog/markets_provider.dart`:
   - Verify total removal of hardcoded admin credentials (emails, passwords) and admin token request methods.
   - Verify integration with the customer products endpoint (`/api/v1/Customer/Catalog/Products/...`).
3. `lib/src/ui/pages/cart/order_payment_page.dart` & `lib/src/core/controllers/order/cart_provider.dart`:
   - Verify submission lock `_isSubmitting`, double-tap prevention on checkout button.
   - Verify `ViewState.busy` re-entry guard.
   - Verify client `idempotencyKey` UUID generation and attachment to order submission payload.
4. `lib/src/core/models/order/order_model.dart` & `lib/src/ui/pages/orders/order_details_page.dart`:
   - Verify `deliveryUserPhone` JSON mapping in `OrderModel`.
   - Verify nullable driver coordinate resolution (`LatLng?`). Ensure driver coordinates NEVER default to customer residence coordinates when missing/null.
   - Verify 3-minute freshness TTL check on courier coordinates.
   - Verify dynamic phone dialing using `deliveryUserPhone` (and fallback behavior).
   - Verify dynamic driver name in chat initiation/display.
5. UI and UX Integrity:
   - Confirm zero visual or styling regressions to existing custom UI, smooth shine skeletons, RTL alignments in `order_details_page.dart` and `order_payment_page.dart`.

Document your complete findings with line numbers, code snippets, git diff analysis, and evidence chains in:
`E:/work/jtak/.agents/explorer_customer/handoff.md`.
Then send a summary message back to parent using send_message.
```
