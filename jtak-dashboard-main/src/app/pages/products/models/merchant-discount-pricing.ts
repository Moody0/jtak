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
