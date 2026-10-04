import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Payment } from '../models/payments.model';
import { BehaviorSubject } from 'rxjs';


@Injectable({
  providedIn: 'root',
})
export class paymentsService extends TableService<Payment> implements OnDestroy {
  readonly summary$=new BehaviorSubject<any>(null);
  protected onListResponse(response:any):void {this.summary$.next(response?.summary ?? null);}
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Payments/DataTable';
  GET_ONE_URL = '';
  CREATE_URL = 'Admin/Payments/Create';

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
  availableBalances(driverId?:string,merchantId?:number) {
    let params=new HttpParams(); if(driverId)params=params.set('driverId',driverId);if(merchantId)params=params.set('merchantId',merchantId);
    return this.http.get<{deliveryBalance:number|null;merchantBalance:number|null}>(`${this.BASE_URL}/Admin/Payments/AvailableBalances`,{params});
  }
}
