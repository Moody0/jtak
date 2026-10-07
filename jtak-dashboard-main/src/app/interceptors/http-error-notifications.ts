// Track each failure separately so a component can still reset its form state
// without displaying an error already reported by the HTTP interceptor.
const notifiedErrors = new WeakSet<object>();

export function markHttpErrorNotified(error: object): void {
  notifiedErrors.add(error);
}

export function wasHttpErrorNotified(error: unknown): boolean {
  return typeof error === 'object' && error !== null && notifiedErrors.has(error);
}
