import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { SupportMessage, SupportMessageStats, SupportMessageStatus } from '../models/support-message.model';

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

  deleteMessage(id: number): Observable<boolean> {
    return this.http.delete<boolean>(`${this.BASE_URL}/Admin/SupportMessages/${id}`);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
