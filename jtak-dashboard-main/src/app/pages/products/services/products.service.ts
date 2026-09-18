import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Product } from '../models/product.model';
import { finalize } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class ProductsService extends TableService<Product> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Products/DataTable';
  GET_ONE_URL = 'Admin/Products';
  CREATE_URL = 'Admin/Products';
  UPDATE_URL = 'Admin/Products';
  DELETE_URL = 'Admin/Products';
  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  changeStatus(isActive: boolean, id: number){    
    this._isLoading$.next(true);
    return this.http
      .put(
        `${this.BASE_URL}/${this.GET_ONE_URL}/${id}/${
          isActive ? 'Disable' : 'Enable'
        }`,
        {}
      )
      .pipe(
        finalize(() => {
          this._isLoading$.next(false);
        })
      );
  }

  deleteSelected(ids: number[]) {
    this._isLoading$.next(true);
    return this.http
      .post(`${this.BASE_URL}/${this.GET_ONE_URL}/DeleteSelected`, ids)
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
