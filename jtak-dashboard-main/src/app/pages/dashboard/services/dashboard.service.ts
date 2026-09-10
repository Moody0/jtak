import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { Dashboard, TopProduct } from '../models/dashboard.model';
import { Observable } from 'rxjs';
import { Balance } from '../models/balance.model';
import { TableService } from 'src/app/_metronic/shared/crud-table';

@Injectable({
  providedIn: 'root',
})
export class DashboardService
extends TableService<Balance> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Balances/DataTable';
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

  getDashboard(): Observable<Dashboard> {    
    return this.http.get<Dashboard>(environment.apiUrl + '/Admin/Dashboard');
  }


  getTopProducts(): Observable<TopProduct[]> {    
    return this.http.get<TopProduct[]>(environment.apiUrl + '/Admin/Dashboard/TopProducts');
  }

  getSettings(): Observable<any> {
    return this.http.get<any>(environment.apiUrl + '/Admin/Settings');
  }

  saveSettings(settings: any): Observable<any> {
    return this.http.put<any>(environment.apiUrl + '/Admin/Settings', settings);
  }

  /*
  getDashboard(): Observable<Dashboard> {    
    return this.http.get<Dashboard>(environment.apiUrl + '/Admin/Dashboard/');
  }
*/
  ngOnDestroy() {
    //this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
