import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Merchant } from '../models/merchant.model';
import { finalize } from 'rxjs';


@Injectable({
  providedIn: 'root',
})
export class MerchantsService extends TableService<Merchant> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Users/Merchants';
  GET_ONE_URL = '';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getMerchants() {
    this._isLoading$.next(true)
    return this.http.get(`${this.BASE_URL}/${this.GET_ALL_URL}`).pipe(
      finalize(() => {
        this._isLoading$.next(false)
      })
    )
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
