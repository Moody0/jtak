import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { Order, OrderLiveTrack } from '../models/orders.model';
import { finalize, Observable } from 'rxjs';

export interface AdminOrdersSummaryDto {
  total: number;
  pendingApproval: number;
  withoutDriver: number;
  readyForDelivery: number;
  inDelivery: number;
  completed: number;
  cancelledRejected: number;
}

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

  getSummary(): Observable<AdminOrdersSummaryDto> {
    return this.http.get<AdminOrdersSummaryDto>(`${this.BASE_URL}/Admin/Orders/Summary`);
  }

  cancel(orderId: number, reason?: string): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Cancel/${orderId}`, { reason: reason || '' });
  }

  accept(orderId: number, merchantId?: number, reason?: string): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Accept/${orderId}`, { merchantId, reason });
  }

  approve(orderId: number): Observable<boolean> {
    return this.accept(orderId);
  }

  reject(orderId: number, reason: string, merchantId?: number): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Reject/${orderId}`, { reason, merchantId });
  }

  preparing(orderId: number): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Preparing/${orderId}`, {});
  }

  ready(orderId: number, merchantId?: number): Observable<boolean> {
    const url = merchantId ? `${this.BASE_URL}/Admin/Orders/Ready/${orderId}?merchantId=${merchantId}` : `${this.BASE_URL}/Admin/Orders/Ready/${orderId}`;
    return this.http.post<boolean>(url, {});
  }

  confirmPickup(orderId: number, merchantId?: number): Observable<boolean> {
    const url = merchantId ? `${this.BASE_URL}/Admin/Orders/ConfirmPickup/${orderId}?merchantId=${merchantId}` : `${this.BASE_URL}/Admin/Orders/ConfirmPickup/${orderId}`;
    return this.http.post<boolean>(url, {});
  }

  deliver(orderId: number, data: { otp?: string; notes?: string; cashResolutionMode?: string; cashCollectedByUserId?: string }): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Deliver/${orderId}`, data);
  }

  getHistory(orderId: number): Observable<import('../models/orders.model').OrderStatusHistoryItem[]> {
    return this.http.get<import('../models/orders.model').OrderStatusHistoryItem[]>(`${this.BASE_URL}/Admin/Orders/History/${orderId}`);
  }

  setDelievry(id:number,uid :string):Observable<boolean>
  {
    return this.http.put<boolean>(`${this.BASE_URL}/Admin/Orders/SetDelivery/${id}/${uid}`,{});
  }

  getLiveTrack(id: number): Observable<OrderLiveTrack> {
    return this.http.get<OrderLiveTrack>(`${this.BASE_URL}/Admin/Orders/${id}/LiveTrack`);
  }

  archive(orderId: number, reason: string): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Archive/${orderId}`, { reason });
  }

  restore(orderId: number): Observable<boolean> {
    return this.http.post<boolean>(`${this.BASE_URL}/Admin/Orders/Restore/${orderId}`, {});
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
