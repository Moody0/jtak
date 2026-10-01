import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import {
  AdminMarketBestSellingSectionResponse,
  MarketBestSellingSectionConfig,
  MarketBestSellingItemConfig,
  SearchProductCandidate,
} from '../models/market-best-selling.model';

@Injectable({
  providedIn: 'root',
})
export class MarketBestSellingService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/MarketBestSelling`;

  private isLoadingSubject = new BehaviorSubject<boolean>(false);
  public isLoading$ = this.isLoadingSubject.asObservable();
  private activeRequests = 0;

  constructor(private http: HttpClient) {}

  getConfig(): Observable<AdminMarketBestSellingSectionResponse> {
    return this.track(this.http.get<AdminMarketBestSellingSectionResponse>(this.baseUrl));
  }

  saveConfig(config: MarketBestSellingSectionConfig): Observable<boolean> {
    return this.track(this.http.put<boolean>(this.baseUrl, config));
  }

  addItem(item: MarketBestSellingItemConfig): Observable<boolean> {
    return this.track(this.http.post<boolean>(`${this.baseUrl}/AddItem`, item));
  }

  removeItem(productId: number): Observable<boolean> {
    return this.track(this.http.delete<boolean>(`${this.baseUrl}/${productId}`));
  }

  toggleItem(productId: number, active?: boolean): Observable<boolean> {
    let params = new HttpParams();
    if (active !== undefined && active !== null) {
      params = params.set('active', active.toString());
    }
    return this.track(this.http.post<boolean>(`${this.baseUrl}/Toggle/${productId}`, {}, { params }));
  }

  reorder(productIds: number[]): Observable<boolean> {
    return this.track(this.http.post<boolean>(`${this.baseUrl}/Reorder`, productIds));
  }

  searchProducts(q?: string, merchantId?: number, take: number = 30): Observable<SearchProductCandidate[]> {
    let params = new HttpParams().set('take', take.toString());
    if (q && q.trim()) {
      params = params.set('q', q.trim());
    }
    if (merchantId) {
      params = params.set('merchantId', merchantId.toString());
    }
    return this.track(this.http.get<SearchProductCandidate[]>(`${this.baseUrl}/SearchProducts`, { params }));
  }

  private track<T>(obs: Observable<T>): Observable<T> {
    this.activeRequests++;
    this.isLoadingSubject.next(true);
    return obs.pipe(
      finalize(() => {
        this.activeRequests = Math.max(0, this.activeRequests - 1);
        if (this.activeRequests === 0) {
          this.isLoadingSubject.next(false);
        }
      })
    );
  }
}
