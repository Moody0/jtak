import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { SystemContactSettings } from '../models/contact-settings.model';

@Injectable({
  providedIn: 'root',
})
export class ContactSettingsService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/Settings/Contact`;

  constructor(private http: HttpClient) {}

  getSettings(): Observable<SystemContactSettings> {
    return this.http.get<SystemContactSettings>(this.baseUrl);
  }

  saveSettings(settings: SystemContactSettings): Observable<boolean> {
    return this.http.put<boolean>(this.baseUrl, settings);
  }
}
