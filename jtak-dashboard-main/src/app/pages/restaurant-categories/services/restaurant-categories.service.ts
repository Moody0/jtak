import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import {
  AdminRestaurantCategoriesResponse,
  RestaurantCategoriesSectionConfig,
  RestaurantCategoryItem,
} from '../models/restaurant-category.model';

@Injectable({
  providedIn: 'root',
})
export class RestaurantCategoriesService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/RestaurantCategories`;

  private isLoadingSubject = new BehaviorSubject<boolean>(false);
  public isLoading$ = this.isLoadingSubject.asObservable();
  private activeRequests = 0;

  constructor(private http: HttpClient) {}

  getConfig(): Observable<AdminRestaurantCategoriesResponse> {
    return this.track(this.http.get<AdminRestaurantCategoriesResponse>(this.baseUrl));
  }

  saveConfig(config: RestaurantCategoriesSectionConfig): Observable<boolean> {
    return this.track(this.http.put<boolean>(this.baseUrl, config));
  }

  addItem(item: Partial<RestaurantCategoryItem>): Observable<RestaurantCategoryItem> {
    return this.track(this.http.post<RestaurantCategoryItem>(`${this.baseUrl}/AddItem`, item));
  }

  updateItem(item: RestaurantCategoryItem): Observable<boolean> {
    return this.track(this.http.put<boolean>(`${this.baseUrl}/UpdateItem`, item));
  }

  deleteItem(id: number): Observable<boolean> {
    return this.track(this.http.delete<boolean>(`${this.baseUrl}/${id}`));
  }

  toggleItem(id: number, active?: boolean): Observable<boolean> {
    let params = new HttpParams();
    if (active !== undefined && active !== null) {
      params = params.set('active', active.toString());
    }
    return this.track(this.http.post<boolean>(`${this.baseUrl}/Toggle/${id}`, {}, { params }));
  }

  reorder(categoryIds: number[]): Observable<boolean> {
    return this.track(this.http.post<boolean>(`${this.baseUrl}/Reorder`, categoryIds));
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
