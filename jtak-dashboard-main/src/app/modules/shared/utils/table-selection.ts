export type TableRowId = string | number;

/** Page-aware selection shared by all admin data tables. */
export class TableSelection<T> {
  private readonly ids = new Set<TableRowId>();

  constructor(private readonly identify: (item: T) => TableRowId) {}

  get count(): number {
    return this.ids.size;
  }

  isSelected(item: T): boolean {
    return this.ids.has(this.identify(item));
  }

  toggle(item: T, selected: boolean): void {
    const id = this.identify(item);
    selected ? this.ids.add(id) : this.ids.delete(id);
  }

  toggleAll(items: T[], selected: boolean): void {
    items.forEach((item) => this.toggle(item, selected));
  }

  allSelected(items: T[]): boolean {
    return items.length > 0 && items.every((item) => this.isSelected(item));
  }

  partiallySelected(items: T[]): boolean {
    const selectedOnPage = items.filter((item) => this.isSelected(item)).length;
    return selectedOnPage > 0 && selectedOnPage < items.length;
  }

  selectedItems(items: T[]): T[] {
    return items.filter((item) => this.isSelected(item));
  }

  clear(): void {
    this.ids.clear();
  }

  exportSelected(items: T[], filename: string): void {
    const selected = this.selectedItems(items);
    if (!selected.length) return;

    const records = selected.map((item: any) => {
      const record: Record<string, unknown> = {};
      Object.keys(item).forEach((key) => {
        const value = item[key];
        if (value === null || ['string', 'number', 'boolean'].includes(typeof value)) {
          record[key] = value;
        }
      });
      return record;
    });
    const columns = records.reduce<string[]>((result, record) => {
      Object.keys(record).forEach((key) => {
        if (!result.includes(key)) result.push(key);
      });
      return result;
    }, []);
    const escape = (value: unknown) => `"${String(value ?? '').replace(/"/g, '""')}"`;
    const csv = [columns.map(escape).join(','), ...records.map((record) => columns.map((column) => escape(record[column])).join(','))].join('\r\n');
    const url = URL.createObjectURL(new Blob(['\uFEFF', csv], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `${filename}-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }
}
