import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService, TableResponseModel } from 'src/app/_metronic/shared/crud-table';
import { Merchant } from '../models/merchant.model';
import { Observable, of } from 'rxjs';
import { map, catchError, switchMap, take, finalize, tap } from 'rxjs/operators';

@Injectable({
  providedIn: 'root',
})
export class MerchantsService extends TableService<Merchant> implements OnDestroy {
  private readonly workspaceStoragePrefix = 'jtak:merchant-workspace:';
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Merchants/DataTable';
  GET_ONE_URL = 'Admin/Merchants';
  CREATE_URL = 'Admin/Merchants';
  UPDATE_URL = 'Admin/Merchants';
  DELETE_URL = 'Admin/Merchants';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  public override fetchPost(queryParams: any = null): void {
    let params = new HttpParams();

    if (queryParams) {
      Object.entries(queryParams).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    if (this.filter) {
      Object.entries(this.filter).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    const body: any = {
      pageSize: this.paginator.pageSize,
      pageNumber: this.paginator.page + 1,
      sortField: this.sorting.column,
      sortOrder: this.sorting.direction,
    };

    if (this.searchTerm) {
      body.search = this.searchTerm;
    }

    const url = `${this.BASE_URL}/${this.GET_ALL_URL}`;
    this._isLoading$.next(true);

    const request = this.http
      .post<any>(url, body, { params })
      .pipe(
        take(1),
        switchMap((res: any) => {
          const items = this.extractMerchants(res);
          if (items && items.length > 0) {
            return of({
              items,
              totalRecords: res?.totalRecords || items.length,
            } as TableResponseModel<Merchant>);
          }
          // Fallback when DataTable items array is empty (e.g. backend 0-based page skip bug)
          return this.getAllMerchantsFallback().pipe(
            map((fallbackMerchants) => {
              let filtered = fallbackMerchants;
              if (this.searchTerm) {
                const term = this.searchTerm.trim().toLowerCase();
                filtered = filtered.filter(
                  (m) =>
                    (m.title && m.title.toLowerCase().includes(term)) ||
                    (m.phone1 && m.phone1.includes(term)) ||
                    (m.address && m.address.toLowerCase().includes(term))
                );
              }
              const total = filtered.length;
              const page = this.paginator.page;
              const size = this.paginator.pageSize || 50;
              const paged = filtered.slice(page * size, (page + 1) * size);
              return {
                items: paged,
                totalRecords: total,
              } as TableResponseModel<Merchant>;
            })
          );
        }),
        tap((res: TableResponseModel<Merchant>) => {
          this.setCustomTableResponse(res);
        }),
        catchError(() => {
          return this.getAllMerchantsFallback().pipe(
            map((fallbackMerchants) => {
              let filtered = fallbackMerchants;
              if (this.searchTerm) {
                const term = this.searchTerm.trim().toLowerCase();
                filtered = filtered.filter(
                  (m) =>
                    (m.title && m.title.toLowerCase().includes(term)) ||
                    (m.phone1 && m.phone1.includes(term)) ||
                    (m.address && m.address.toLowerCase().includes(term))
                );
              }
              const total = filtered.length;
              const page = this.paginator.page;
              const size = this.paginator.pageSize || 50;
              const paged = filtered.slice(page * size, (page + 1) * size);
              return {
                items: paged,
                totalRecords: total,
              } as TableResponseModel<Merchant>;
            }),
            tap((res) => this.setCustomTableResponse(res)),
            catchError(() => {
              this.setCustomTableResponse({ items: [], totalRecords: 0 });
              return of({ items: [], totalRecords: 0 } as TableResponseModel<Merchant>);
            })
          );
        }),
        finalize(() => {
          this._isLoading$.next(false);
        })
      )
      .subscribe();

    this.subscriptions.push(request);
  }

  private setCustomTableResponse(res: TableResponseModel<Merchant>): void {
    const self = this as any;
    if (self._items$) {
      self._items$.next(res?.items || []);
    }
    if (self._totalRecords$) {
      self._totalRecords$.next(res?.totalRecords || 0);
    }
    this.patchStateWithoutFetch({
      paginator: self._tableState$?.value?.paginator?.recalculatePaginator(
        res?.totalRecords || 0
      ),
    });
  }

  getAllMerchants(): Observable<Merchant[]> {
    return this.http
      .post<any>(
        `${this.BASE_URL}/${this.GET_ALL_URL}`,
        { pageNumber: 1, pageSize: 500, sortField: 'id', sortOrder: 'DESC' }
      )
      .pipe(
        map((res: any) => this.extractMerchants(res)),
        switchMap((merchants) => merchants.length ? of(merchants) : this.getAllMerchantsFallback()),
        catchError(() => this.getAllMerchantsFallback())
      );
  }

  private getAllMerchantsFallback(): Observable<Merchant[]> {
    return this.http
      .get<any>(`${this.BASE_URL}/Admin/Merchants`)
      .pipe(
        map((res: any) => this.extractMerchants(res)),
        catchError(() => of([]))
      );
  }

  private extractMerchants(res: any): Merchant[] {
    const candidates = [
      res,
      res?.items,
      res?.Items,
      res?.data,
      res?.Data,
      res?.data?.items,
      res?.Data?.Items,
    ];
    const list = candidates.find((candidate) => Array.isArray(candidate));
    return (list || [])
      .filter((merchant: any) => merchant && Number(merchant.id ?? merchant.Id) > 0)
      .map((merchant: any) => ({
        ...merchant,
        id: Number(merchant.id ?? merchant.Id),
        title: merchant.title || merchant.Title || merchant.name || merchant.Name || merchant.fullName || `متجر #${merchant.id ?? merchant.Id}`,
        active: merchant.active ?? merchant.Active,
      }));
  }

  getSummary(): Observable<{ total: number; active: number; grocery: number; restaurants: number }> {
    return this.http
      .get<{ total: number; active: number; grocery: number; restaurants: number }>(
        `${this.BASE_URL}/Admin/Merchants/Summary`
      )
      .pipe(catchError(() => of(null as any)));
  }

  rememberWorkspaceMerchant(merchant: Merchant): void {
    if (!merchant?.id) return;
    try {
      sessionStorage.setItem(
        `${this.workspaceStoragePrefix}${merchant.id}`,
        JSON.stringify(merchant)
      );
    } catch {
      // Storage may be disabled. Navigation still works with the route id.
    }
  }

  getWorkspaceMerchant(id: number): Merchant | null {
    try {
      const value = sessionStorage.getItem(`${this.workspaceStoragePrefix}${id}`);
      return value ? (JSON.parse(value) as Merchant) : null;
    } catch {
      return null;
    }
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
