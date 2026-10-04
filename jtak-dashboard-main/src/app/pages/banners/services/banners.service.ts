import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Banner } from '../models/banner.model';

@Injectable({
  providedIn: 'root',
})
export class BannersService extends TableService<Banner> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Banner/DataTable';
  GET_ONE_URL = '';
  CREATE_URL = 'Admin/Banner';
  UPDATE_URL = 'Admin/Banner';
  DELETE_URL = 'Admin/Banner';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  summary() { return this.http.get<{total: number; active: number; daily: number; dontMiss: number}>(this.BASE_URL + '/Admin/Banner/Summary'); }
  setStatus(ids: number[], active: boolean) { return this.http.post<boolean>(this.BASE_URL + '/Admin/Banner/BulkStatus', {ids, active}); }
  deleteMany(ids: number[]) { return this.http.post<boolean>(this.BASE_URL + '/Admin/Banner/BulkDelete', {ids}); }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
