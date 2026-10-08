import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import {
  HomeCategoriesAdminVm,
  HomeCategoriesConfig,
  ResolvedHomeCategoryTile,
} from '../models/home-category.model';

@Injectable({
  providedIn: 'root',
})
export class HomeCategoriesService {
  private readonly url = `${environment.apiUrl}/Admin/HomeCategories`;

  constructor(@Inject(HttpClient) private http: HttpClient) {}

  /** Current arrangement plus every destination that can be chosen. */
  get(): Observable<HomeCategoriesAdminVm> {
    return this.http.get<HomeCategoriesAdminVm>(this.url);
  }

  /**
   * The grid is always edited as one arrangement, so it is saved wholesale.
   * The response is the saved tiles with their destinations resolved.
   */
  save(config: HomeCategoriesConfig): Observable<ResolvedHomeCategoryTile[]> {
    return this.http.put<ResolvedHomeCategoryTile[]>(this.url, config).pipe(
      switchMap(tiles => this.get().pipe(map(vm => {
        const requested = config.otherStores;
        const saved = vm.config?.otherStores;
        if (requested && (!saved || saved.enabled !== requested.enabled ||
            saved.automatic !== requested.automatic || saved.title !== requested.title ||
            (saved.titleEn ?? '') !== requested.titleEn ||
            JSON.stringify(saved.merchantIds ?? []) !== JSON.stringify(requested.merchantIds))) {
          throw new Error('لم يؤكد الخادم حفظ إعدادات المتاجر الأخرى. حدّث الـBackend ثم أعد الحفظ.');
        }
        return tiles;
      }))),
    );
  }
}
