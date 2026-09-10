import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { finalize } from 'rxjs';
import { Deliver } from '../models/deliver.model';


@Injectable({
  providedIn: 'root',
})
export class DeliveriesService extends TableService<Deliver> implements OnDestroy {
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Users/Deliveries';
  GET_ONE_URL = '';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getDeliveries() {
    this._isLoading$.next(true)
    return this.http.get(`${this.BASE_URL}/${this.GET_ALL_URL}`).pipe(
      finalize(() => {
        this._isLoading$.next(false)
      })
    )
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
