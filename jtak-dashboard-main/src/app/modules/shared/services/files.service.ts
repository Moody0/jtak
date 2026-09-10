import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { Platform } from '@angular/cdk/platform';

@Injectable({
  providedIn: 'root',
})
export class FilesService {
  constructor(private http: HttpClient, private platform: Platform) {}

  uploadFile(file: any, isMultiple: boolean): Observable<any> {
    return this.http.post(`${environment.apiUrl}/Services/SaveUploaded`,
    file, {
      reportProgress: true,
      observe: 'events',
    });
  }

  getFile(id: string | undefined, width: number, height: number): string {
    const fileId = (id || '').split(',').map((value) => value.trim()).find(Boolean);
    if (!fileId) return './assets/media/svg/files/blank-image.svg';
    if (fileId.startsWith('http://') || fileId.startsWith('https://') || fileId.startsWith('assets/') || fileId.startsWith('./assets/')) {
      return fileId;
    }
    const lower = fileId.toLowerCase();
    if (lower.includes('.webp') || lower.includes('.svg') || lower.includes('.gif') || lower.includes('.avif')) {
      return `${environment.apiUrl}/Services/Download/${fileId}`;
    }
    return `${environment.apiUrl}/Services/PreviewImage/${fileId}?w=${width}&h=${height}&crop=true`;
  }

  downloadFile(id: string): string {
    return `${environment.apiUrl}/Services/Download/${id}`;
  }

  ///api/v1/Services/Play/{id}/{fileName}
  getVideoUrl(id?: string) {
    return `${environment.apiUrl}/Services/Play/${id}/master.${
      this.platform.SAFARI ? 'm3u8' : 'mpd'
    }`;
  }
}
