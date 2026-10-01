import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { SupportMessage, SupportMessageStats, SupportMessageStatus, ErrandDriver, ErrandQueuePage, ErrandQueueStats } from '../models/support-message.model';

@Injectable({
  providedIn: 'root',
})
export class SupportMessagesService extends TableService<SupportMessage> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/SupportMessages/DataTable';
  GET_ONE_URL = 'Admin/SupportMessages';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getStats(): Observable<SupportMessageStats> {
    return this.http.get<SupportMessageStats>(`${this.BASE_URL}/Admin/SupportMessages/stats`);
  }

  getMessage(id: number): Observable<SupportMessage> {
    return this.http.get<SupportMessage>(`${this.BASE_URL}/Admin/SupportMessages/${id}`);
  }

  updateStatus(id: number, status: SupportMessageStatus, adminNotes?: string): Observable<boolean> {
    return this.http.put<boolean>(`${this.BASE_URL}/Admin/SupportMessages/${id}/status`, {
      status,
      adminNotes,
    });
  }

  getErrandDrivers(): Observable<ErrandDriver[]> {
    return this.http.get<ErrandDriver[]>(`${this.BASE_URL}/Admin/ErrandRequests/drivers`);
  }

  getErrandDriverEarning(): Observable<{ amount: number }> {
    return this.http.get<{ amount: number }>(`${this.BASE_URL}/Admin/Settings/ErrandDriverEarning`);
  }

  getErrandQueue(bucket: string, page: number, search: string): Observable<ErrandQueuePage> {
    let params = new HttpParams().set('bucket', bucket).set('page', page.toString()).set('pageSize', '25');
    if (search.trim()) params = params.set('search', search.trim());
    return this.http.get<ErrandQueuePage>(`${this.BASE_URL}/Admin/ErrandRequests`, { params });
  }

  getErrandStats(): Observable<ErrandQueueStats> {
    return this.http.get<ErrandQueueStats>(`${this.BASE_URL}/Admin/ErrandRequests/stats`);
  }

  quoteErrand(id: number, itemPrice: number, deliveryFee: number, acceptDriverSubsidy = false): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/quote`, { itemPrice, deliveryFee, acceptDriverSubsidy });
  }

  assignErrand(id: number, driverUserId: string): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/assign`, { driverUserId });
  }

  purchaseErrand(id: number, purchaseCost: number, receiptReference: string): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/purchase`, { purchaseCost, receiptReference });
  }

  deliverErrand(id: number, collectedAmount: number, deliveryCode: string, recoveryReason: string): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/deliver`, {
      collectedAmount, deliveryCode, recoveryReason, customerReceived: true, cashCollected: true,
    });
  }

  cancelErrand(id: number, reason: string): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/cancel`, { reason });
  }

  returnErrand(id: number, refundAmount: number, reason: string): Observable<unknown> {
    return this.http.put(`${this.BASE_URL}/Admin/ErrandRequests/${id}/return`, { refundAmount, reason });
  }

  deleteMessage(id: number): Observable<boolean> {
    return this.http.delete<boolean>(`${this.BASE_URL}/Admin/SupportMessages/${id}`);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
