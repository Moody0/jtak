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

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
