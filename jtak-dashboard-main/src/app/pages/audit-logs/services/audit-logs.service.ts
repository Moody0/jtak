import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { AdminAuditLog, AdminAuditLogSummary } from '../models/audit-log.model';

@Injectable({
  providedIn: 'root',
})
export class AuditLogsService extends TableService<AdminAuditLog> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/AuditLogs/DataTable';
  GET_ONE_URL = 'Admin/AuditLogs';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getSummary(): Observable<AdminAuditLogSummary> {
    return this.http.get<AdminAuditLogSummary>(`${this.BASE_URL}/Admin/AuditLogs/Summary`);
  }

  getAuditLog(id: string): Observable<AdminAuditLog> {
    return this.http.get<AdminAuditLog>(`${this.BASE_URL}/Admin/AuditLogs/${id}`);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
