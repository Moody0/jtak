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

  getDriverPricing(): Observable<any> {
    return this.http.get<any>(environment.apiUrl + '/Admin/Settings/DriverPricing');
  }

  saveDriverPricing(pricing: any): Observable<any> {
    return this.http.put<any>(environment.apiUrl + '/Admin/Settings/DriverPricing', pricing);
  }

  getErrandDriverEarning(): Observable<any> {
    return this.http.get<any>(environment.apiUrl + '/Admin/Settings/ErrandDriverEarning');
  }

  getJtakMarketDeliveryFee(): Observable<{amount: number}> {
    return this.http.get<{amount: number}>(environment.apiUrl + '/Admin/Settings/JtakMarketDeliveryFee');
  }
  getJtakMarketCourierPay(): Observable<{mode: number, rate: number}> {
    return this.http.get<{mode: number, rate: number}>(environment.apiUrl + '/Admin/Settings/JtakMarketCourierPay');
  }
  saveJtakMarketCourierPay(setting: {mode: number, rate: number}): Observable<{mode: number, rate: number}> {
    return this.http.put<{mode: number, rate: number}>(environment.apiUrl + '/Admin/Settings/JtakMarketCourierPay', setting);
  }
  saveJtakMarketDeliveryFee(setting: {amount: number}): Observable<{amount: number}> {
    return this.http.put<{amount: number}>(environment.apiUrl + '/Admin/Settings/JtakMarketDeliveryFee', setting);
  }

  getDeliveryCoverage(): Observable<any> {
    return this.http.get<any>(environment.apiUrl + '/Admin/Settings/DeliveryCoverage');
  }
  saveDeliveryCoverage(setting: {radiusKm: number}): Observable<any> {
    return this.http.put<any>(environment.apiUrl + '/Admin/Settings/DeliveryCoverage', setting);
  }

  saveErrandDriverEarning(setting: any): Observable<any> {
    return this.http.put<any>(environment.apiUrl + '/Admin/Settings/ErrandDriverEarning', setting);
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
