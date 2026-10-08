export function merchantDiscountQuote(baseUsd: number, rate: number, markupPercent: number, requestedPercent: number) {
  if (![baseUsd, rate, markupPercent, requestedPercent].every(Number.isFinite) ||
      baseUsd <= 0 || rate <= 0 || markupPercent < 0 || requestedPercent < 0 || requestedPercent >= 100) return null;
  const local = (value: number) => Math.round(value + Number.EPSILON * Math.max(1, Math.abs(value)) * 4);
  const exactBase = baseUsd * rate;
  const merchantPrice = local(exactBase);
  const gross = exactBase * (1 + markupPercent / 100);
  const price = local(gross);
  const appliedBasePercent = Math.min(requestedPercent, markupPercent);
  const discounted = local(exactBase * (1 + (markupPercent - appliedBasePercent) / 100));
  const finalPrice = Math.max(merchantPrice, discounted);
  const discount = Math.max(0, price - finalPrice);
  return {
    merchantPrice, price, finalPrice, discount, markupPercent, appliedBasePercent,
    effectivePercent: price > 0 ? Math.round(discount / price * 10000) / 100 : 0,
    limited: requestedPercent > markupPercent,
  };
}

// The admin enters a saving against the customer's compare-at price. Keep the
// API's supplier-base discount convention and two-decimal storage precision.
export function merchantBaseDiscountFromSaving(baseUsd: number, rate: number, markupPercent: number, savingPercent: number): number {
  const maximumBasePercent = Math.min(markupPercent, 99.99);
  const maximum = merchantDiscountQuote(baseUsd, rate, markupPercent, maximumBasePercent);
  if (!maximum || !Number.isFinite(savingPercent) || savingPercent <= 0) return 0;
  if (savingPercent >= maximum.effectivePercent) return maximumBasePercent;
  const exactBase = baseUsd * rate;
  const targetPrice = Math.max(maximum.finalPrice, Math.round(maximum.price * (1 - savingPercent / 100)));
  const basePercent = (exactBase * (1 + markupPercent / 100) - targetPrice) / exactBase * 100;
  return Math.max(0, Math.min(maximumBasePercent, Math.round(basePercent * 100) / 100));
}
