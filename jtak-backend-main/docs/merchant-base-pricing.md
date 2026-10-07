# Merchant base pricing (order money version 4)

All new customer catalog orders use this policy. Existing order snapshots and
posted payments retain their original version; no historical repair is applied.

## Product pricing

- A USD quote is converted using the configured USD/SYP rate, retaining precision
  for the markup and discount calculations.
- A quote submitted through the merchant app is explicitly in SYP. Saving it
  clears its USD reference so subsequent exchange-rate changes do not reprice it.
- Both the platform markup and the requested discount use that same supplier
  base: `base * (1 + (markupPercent - appliedDiscountPercent) / 100)`.
- Discount is limited to the markup. The supplier quote is never reduced.
- The final customer unit price is rounded to a whole SYP. Compare-at savings and
  customer discount badges are calculated from the actual before/after prices.
- The admin distinguishes the requested percentage of the supplier base from
  the customer's effective saving relative to the marked-up compare-at price.

## Order accounting

Checkout captures each supplier quote in `OrderDetail.SingleMerchantProfit` and
locks `CommissionRatePercent`, ownership, compare-at price, and customer price.
Money snapshot version 4 uses these captured values for order views, invoices,
driver collection, completion, and ledger posting. Delivery fees and courier
earnings are accounted for separately from the product split.

For an external merchant:

```
merchant payable = sum(quantity * captured merchant base)
platform product share = charged product subtotal - merchant payable
```

If the base is missing, recover it from the product price **before discount**:
`base = compareAt / (1 + markupPercent / 100)`. Never subtract the markup
percentage from the customer's total. Do not use current catalog prices to
reconstruct past checkout amounts.

For a platform-owned dark store, the existing ownership rule remains: sales go
to the platform sales account instead of creating a payable to an external
merchant.

Example, supplier 550 SYP and markup 10%:

| Base discount | Customer unit price | Merchant payable | Platform product share |
| --- | ---: | ---: | ---: |
| None | 605 | 550 | 55 |
| 9% | 556 (555.5 before rounding) | 550 | 6 |
| 10% or higher | 550 | 550 | 0 |

No new schema columns are required: the existing version and checkout base
fields carry the new policy. Deploy the API and dashboard changes together;
update the merchant app for its price preview to match the API.

## Merchant incoming order display

The merchant app uses the captured `SingleMerchantProfit` for unit prices,
quantity totals, the order list, and the financial summary ("صافي المبلغ للمتجر").
The summary excludes rejected/canceled lines and lines awaiting customer
approval. Pending merchant approval lines show the proposed merchant amount.
Customer prices and courier collection amounts remain separate. For four units
at base 550 and customer price 605, the merchant sees unit 550 and total 2,200;
the customer's product subtotal is 2,420 and the platform share is 220.

These screens use checkout snapshots rather than today's product prices. If
neither a saved base nor a pre-discount price with captured markup is available,
they show an unavailable amount instead of treating the customer total as net.
