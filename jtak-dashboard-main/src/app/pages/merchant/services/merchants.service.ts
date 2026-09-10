import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Merchant } from '../models/merchant.model';

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
      return value ? JSON.parse(value) as Merchant : null;
    } catch {
      return null;
    }
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
