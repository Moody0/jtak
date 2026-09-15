import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Order, OrderLiveTrack } from '../models/orders.model';
import { finalize, Observable } from 'rxjs';


@Injectable({
  providedIn: 'root',
})
export class OrdersService extends TableService<Order> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Orders/DataTable';
  GET_ONE_URL = '';
  ACCEPT_CHANGE = 'Admin/Orders/AcceptChange';
  CANCEL = 'Admin/Orders/Cancel';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  cancel(orderId: number, reason?: string): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Cancel/${orderId}`, { reason: reason || '' });
  }
  approve(orderId: number): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Approve/${orderId}`, {});
  }
  ready(orderId: number): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Ready/${orderId}`, {});
  }
  setDelievry(id:number,uid :string):Observable<boolean>
  {
    return this.http.put<boolean>(`${this.BASE_URL}/Admin/Orders/SetDelivery/${id}/${uid}`,{});
  }

  getLiveTrack(id: number): Observable<OrderLiveTrack> {
    return this.http.get<OrderLiveTrack>(`${this.BASE_URL}/Admin/Orders/${id}/LiveTrack`);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
