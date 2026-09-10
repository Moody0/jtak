import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
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

  getPage(pageName: string): Observable<Page> {
    return this.http.get<Page>(environment.apiUrl + '/Admin/Pages/' + pageName);
  }
  setPage(pageName: string, page: any): Observable<boolean> {
    console.log(page);
    return this.http.put<boolean>(
      environment.apiUrl + '/Admin/Pages/' + pageName,
      page
    );
  }
}
