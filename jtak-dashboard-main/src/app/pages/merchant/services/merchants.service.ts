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
    super.fetchPost(queryParams);
  }

  getAllMerchants(): Observable<Merchant[]> {
    return this.http.get<any>(
      `${this.BASE_URL}/Admin/Merchants`
    ).pipe(map((res: any) => this.extractMerchants(res)));
  }

  private extractMerchants(res: any): Merchant[] {
    const list = Array.isArray(res) ? res : res?.items;
    if (!Array.isArray(list)) throw new Error('Invalid merchant lookup response');
    return list.map((m: any) => ({ ...m, id: Number(m.id) }));
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

  clearWorkspaceMerchant(id?: number): void {
    try {
      if (id) {
        sessionStorage.removeItem(`${this.workspaceStoragePrefix}${id}`);
      } else {
        Object.keys(sessionStorage)
          .filter((k) => k.startsWith(this.workspaceStoragePrefix))
          .forEach((k) => sessionStorage.removeItem(k));
      }
    } catch {
      // Storage may be disabled.
    }
  }



  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
