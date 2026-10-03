import { NgPagination } from './ng-pagination.component';
import { NgPaginationConfig } from './ng-pagination.config';

describe('Zero-based dashboard pagination', () => {
  it('clamps to the actual last page without offering an empty extra page', () => {
    const page = new NgPagination(new NgPaginationConfig()); page.collectionSize = 20; page.pageSize = 10;
    page.ngOnChanges({}); page.selectPage(2); expect(page.page).toBe(1);
    page.collectionSize = 0; page.ngOnChanges({}); expect(page.page).toBe(0);
  });
  it('keeps the selected page in a rotating range', () => {
    const page = new NgPagination(new NgPaginationConfig()); page.collectionSize = 200; page.pageSize = 10;
    page.maxSize = 3; page.rotate = true; page.ellipses = false; page.page = 9; page.ngOnChanges({});
    expect(page.pages).toContain(10); expect(page.pages).toEqual([9, 10, 11]);
  });
});
