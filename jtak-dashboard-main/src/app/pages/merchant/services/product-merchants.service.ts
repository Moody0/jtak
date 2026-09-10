import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { ProductMerchant } from '../models/product-merchant.model';
import { finalize, Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class ProductMerchantsService
  extends TableService<ProductMerchant>
  implements OnDestroy
{
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Merchants/Products';
  UPDATE_URL = 'Admin/Merchants/Products';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getProducts(mid: number | null) {
    this._isLoading$.next(true);
    return this.http.get(`${this.BASE_URL}/${this.GET_ALL_URL}/${mid}`).pipe(
      finalize(() => {
        this._isLoading$.next(false);
      })
    );
  }

  saveProducts(mid: number, data: any) {
    this._isLoading$.next(true);
    return this.http
      .put(`${this.BASE_URL}/${this.UPDATE_URL}/${mid}`, data)
      .pipe(
        finalize(() => {
          this._isLoading$.next(false);
        })
      );
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
