import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { Page } from '../models/pages.model';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class PagesService {
  BASE_URL = environment.apiUrl;
  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {}

  getPage(pageName: string, app?: string): Observable<Page> {
    const params = this.isTermsPage(pageName) && app
      ? new HttpParams().set('app', app)
      : undefined;
    return this.http.get<Page>(environment.apiUrl + '/Admin/Pages/' + pageName, { params });
  }
  setPage(pageName: string, page: any, app?: string): Observable<Page> {
    const params = this.isTermsPage(pageName) && app
      ? new HttpParams().set('app', app)
      : undefined;
    return this.http.put<Page>(
      environment.apiUrl + '/Admin/Pages/' + pageName,
      page,
      { params }
    );
  }

  private isTermsPage(pageName: string): boolean {
    return pageName.toLowerCase() === 'termsandconditions';
  }
}
