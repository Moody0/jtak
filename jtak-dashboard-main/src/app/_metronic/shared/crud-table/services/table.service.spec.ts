import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { HttpClient } from '@angular/common/http';
import { TableService } from './table.service';

class AuditTable extends TableService<any> {
  BASE_URL = '/api'; GET_ALL_URL = 'orders'; DEFAULT_SORT_FIELD = 'id';
}

describe('Order/support table state and requests', () => {
  let http: HttpTestingController;
  let table: AuditTable;
  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule] });
    http = TestBed.inject(HttpTestingController);
    table = new AuditTable(TestBed.inject(HttpClient));
    table.setDefaults();
  });
  afterEach(() => http.verify());
  it('sends one-based pages to the API for POST and GET', () => {
    table.paginator.page = 1;
    table.fetchPost();
    const post = http.expectOne('/api/orders');
    expect(post.request.body.pageNumber).toBe(2);
    post.flush({ items: [{ id: 2 }], totalRecords: 30 });
    table.fetch();
    const get = http.expectOne(request => request.url === '/api/orders');
    expect(get.request.params.get('pageNumber')).toBe('2');
    get.flush({ items: [], totalRecords: 30 });
  });
  it('resets pagination on search and filters', () => {
    table.paginator.page = 7;
    table.patchState({ searchTerm: 'Mohamed' });
    const search = http.expectOne('/api/orders');
    expect(search.request.body.pageNumber).toBe(1);
    search.flush({ items: [], totalRecords: 0 });
    table.paginator.page = 4;
    table.patchState({ filter: { status: 'READY' } });
    const filter = http.expectOne('/api/orders?status=READY');
    expect(filter.request.body.pageNumber).toBe(1);
    filter.flush({ items: [], totalRecords: 0 });
  });
  it('keeps page, sort and filters independent between services', () => {
    const other = new AuditTable(TestBed.inject(HttpClient));
    other.setDefaults();
    table.paginator.page = 6;
    table.patchStateWithoutFetch({ filter: { status: 'READY' }, searchTerm: '13' });
    expect(other.paginator.page).toBe(0);
    expect(other.filter).toEqual({});
    expect(other.searchTerm).toBe('');
    expect(other.sorting.column).toBe('id');
    table.setDefaults();
    expect(table.paginator.page).toBe(0);
    expect(table.sorting.column).toBe('id');
  });
  it('exposes request failure and clears it after a successful retry', () => {
    let error = ''; const subscription = table.listError$.subscribe(value => error = value);
    table.fetchPost(); http.expectOne('/api/orders').flush({}, { status: 500, statusText: 'Offline' });
    expect(error).toContain('تعذر'); table.fetchPost();
    http.expectOne('/api/orders').flush({ items: [], totalRecords: 0 }); expect(error).toBe(''); subscription.unsubscribe();
  });
  it('shows a server table error instead of treating it as an empty successful result', () => {
    let error = ''; const subscription = table.listError$.subscribe(value => error = value);
    table.fetchPost(); http.expectOne('/api/orders').flush({ items: [], totalRecords: 0, error: true });
    expect(error).toContain('تعذر'); subscription.unsubscribe();
  });
  it('cancels older requests instead of showing stale search results', () => {
    table.fetchPost();
    const old = http.expectOne('/api/orders');
    table.patchState({ searchTerm: '14' });
    expect(old.cancelled).toBeTrue();
    http.expectOne('/api/orders').flush({ items: [{ id: 14 }], totalRecords: 1 });
    let items: any[] = [];
    const subscription = table.items$.subscribe(value => items = value);
    expect(items).toEqual([{ id: 14 }]);
    subscription.unsubscribe();
  });
});
