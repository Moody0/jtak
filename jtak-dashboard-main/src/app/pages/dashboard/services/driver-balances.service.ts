import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { Balance } from '../models/balance.model';
import { TableService } from 'src/app/_metronic/shared/crud-table';

@Injectable({
  providedIn: 'root',
})
export class DriverBalancesService extends TableService<Balance> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Balances/Drivers/DataTable';
  GET_ONE_URL = 'Admin/Balances';
  CREATE_URL = 'Admin/Balances';
  UPDATE_URL = 'Admin/Balances';
  DELETE_URL = 'Admin/Balances';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  ngOnDestroy() {}
}
