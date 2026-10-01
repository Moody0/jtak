import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { CampaignAudiences, CampaignRequest, CampaignResult, Notification } from '../models/notification.model';

@Injectable({
  providedIn: 'root',
})

export class NotificationsService extends TableService<Notification> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Notifications/DataTable';
  CREATE_URL = 'Admin/Notifications';


  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getCampaignAudiences(): Observable<CampaignAudiences> {
    return this.http.get<CampaignAudiences>(`${this.BASE_URL}/Admin/Notifications/CampaignAudiences`);
  }

  sendCampaign(request: CampaignRequest): Observable<CampaignResult> {
    return this.http.post<CampaignResult>(`${this.BASE_URL}/Admin/Notifications`, request);
  }

  deleteCampaigns(ids: number[]): Observable<{ deletedCount: number }> {
    return this.http.delete<{ deletedCount: number }>(`${this.BASE_URL}/Admin/Notifications`, { body: ids });
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
