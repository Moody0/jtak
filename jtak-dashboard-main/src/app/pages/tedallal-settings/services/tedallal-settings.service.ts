import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { TedallalCardSetting } from '../models/tedallal-settings.model';

@Injectable({
  providedIn: 'root',
})
export class TedallalSettingsService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/Settings/TedallalCard`;

  constructor(private http: HttpClient) {}

  getSettings(): Observable<TedallalCardSetting> {
    return this.http.get<TedallalCardSetting>(this.baseUrl);
  }

  saveSettings(settings: TedallalCardSetting): Observable<boolean> {
    return this.http.put<boolean>(this.baseUrl, settings);
  }
}
