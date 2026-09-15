import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import {
  AdminPopularSectionResponse,
  PopularSectionConfig,
  PopularProductItemConfig,
  SearchProductCandidate,
} from '../models/popular-product.model';

@Injectable({
  providedIn: 'root',
})
export class PopularProductsService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/PopularProducts`;

  private isLoadingSubject = new BehaviorSubject<boolean>(false);
  public isLoading$ = this.isLoadingSubject.asObservable();
  private activeRequests = 0;

  constructor(private http: HttpClient) {}

  getConfig(): Observable<AdminPopularSectionResponse> {
    return this.track(this.http.get<AdminPopularSectionResponse>(this.baseUrl));
  }

  saveConfig(config: PopularSectionConfig): Observable<boolean> {
    return this.track(this.http.put<boolean>(this.baseUrl, config));
  }

  addItem(item: PopularProductItemConfig): Observable<boolean> {
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

  setLoading(loading: boolean): void {
    this.isLoadingSubject.next(loading);
  }

  private track<T>(request: Observable<T>): Observable<T> {
    this.activeRequests += 1;
    this.isLoadingSubject.next(true);
    return request.pipe(
      finalize(() => {
        this.activeRequests = Math.max(0, this.activeRequests - 1);
        this.isLoadingSubject.next(this.activeRequests > 0);
      })
    );
  }
}
