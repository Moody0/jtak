import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { productReview } from '../models/product-reviews.model';
import { BehaviorSubject } from 'rxjs';


@Injectable({
  providedIn: 'root',
})
export class productReviewsService extends TableService<productReview> implements OnDestroy {
  readonly summary$ = new BehaviorSubject<any>(null);
  protected override onListResponse(response: any): void { this.summary$.next(response?.summary ?? null); }
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/MerchantReviews/DataTable';
  GET_ONE_URL = '';

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
}
