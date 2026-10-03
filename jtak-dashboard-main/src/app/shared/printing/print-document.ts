let activeCleanup: (() => void) | undefined;

/** Print one document without its surrounding navigation, dialogs or scroll limits. */
export function printDocument(selector: string, landscape = false): void {
  const candidates = Array.from(document.querySelectorAll<HTMLElement>(selector));
  const root = candidates.find(element => element.getClientRects().length > 0) || candidates[0];
  if (!root) return;
  activeCleanup?.();

  // A previous preview may have been closed without firing afterprint.
  document.querySelectorAll('[data-print-root], [data-print-parent]').forEach(element => {
    element.removeAttribute('data-print-root');
    element.removeAttribute('data-print-parent');
  });
  root.setAttribute('data-print-root', landscape ? 'landscape' : 'portrait');
  for (let parent = root.parentElement; parent; parent = parent.parentElement) {
    parent.setAttribute('data-print-parent', '');
  }
  document.body.classList.add('printing-document');

  const cleanup = () => {
    if (activeCleanup !== cleanup) return;
    activeCleanup = undefined;
    document.body.classList.remove('printing-document');
    document.querySelectorAll('[data-print-root], [data-print-parent]').forEach(element => {
      element.removeAttribute('data-print-root');
      element.removeAttribute('data-print-parent');
    });
    window.removeEventListener('afterprint', cleanup);
  };
  activeCleanup = cleanup;
  window.addEventListener('afterprint', cleanup, { once: true });
  // Wait for Arabic fonts and the updated Angular view before creating the preview.
  document.fonts.ready.then(() => requestAnimationFrame(() => {
    if (activeCleanup !== cleanup) return;
    try {
      window.print();
    } catch (error) {
      cleanup();
      throw error;
    }
  }));
}
