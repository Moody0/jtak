import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Category } from '../models/Category.model';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class CategoriesService extends TableService<Category> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/ProductCategories/DataTable';
  GET_ONE_URL = 'Admin/ProductCategories';
  CREATE_URL = 'Admin/ProductCategories';
  UPDATE_URL = 'Admin/ProductCategories';
  DELETE_URL = 'Admin/ProductCategories';
  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }

  getAll(root: boolean = false, includeInactive: boolean = false): Observable<Category[]> {
    const url = `${this.BASE_URL}/Admin/ProductCategories?root=${root}&includeInactive=${includeInactive}`;
    return this.http.get<Category[]>(url);
  }
}
