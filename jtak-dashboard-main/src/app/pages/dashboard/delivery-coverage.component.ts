import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { DashboardService } from './services/dashboard.service';

@Component({
  selector: 'app-delivery-coverage',
  template: `
    <section class="card my-6" dir="rtl">
      <div class="card-header"><h2 class="card-title">منطقة التوصيل في حمص</h2></div>
      <div class="card-body">
        <p>المركز الثابت: 34.7333، 36.7167. يجب أن يكون موقع العميل الحالي وعنوان التوصيل داخل هذه المنطقة.</p>
        <label for="coverage-radius" class="form-label">نصف قطر التغطية (كم)</label>
        <div class="d-flex gap-3 align-items-center mb-3">
          <input id="coverage-radius" class="form-control" style="max-width:200px" type="number"
            min="0.1" max="100" step="0.01" [(ngModel)]="radiusKm" (ngModelChange)="updateMap(); success = false"
            [disabled]="loading || saving" />
          <button class="btn btn-primary" type="button" (click)="save()" [disabled]="loading || saving || !validRadius">
            {{ saving ? 'جارٍ الحفظ...' : 'حفظ منطقة التوصيل' }}
          </button>
        </div>
        <p *ngIf="!loading && !validRadius" class="text-danger">أدخل نصف قطر بين 0.1 و100 كم، حتى منزلتين عشريتين.</p>
        <p class="text-muted">مثال: 10 كم تعني نصف القطر، أي قطر 20 كم. القياس مسافة مباشرة من المركز، وليس مسافة الطريق.</p>
        <div *ngIf="loading" class="alert alert-info">جارٍ تحميل منطقة التوصيل...</div>
        <div *ngIf="error" class="alert alert-danger" role="alert">{{ error }} <button type="button" class="btn btn-link" (click)="load()">إعادة التحميل</button></div>
        <div *ngIf="success" class="alert alert-success" role="status">تم حفظ منطقة التوصيل. تنطبق على الطلبات الجديدة دون تغيير الطلبات السابقة.</div>
        <svg *ngIf="validRadius" viewBox="0 0 512 320" role="img" aria-label="معاينة دائرة التغطية حول مركز حمص"
          style="width:100%;max-width:800px;border:1px solid #ddd;border-radius:12px;background:#edf1ed">
          <image *ngFor="let tile of tiles" [attr.href]="tile.url" [attr.x]="tile.x" [attr.y]="tile.y" width="256" height="256" />
          <polygon [attr.points]="circle" fill="#ff660033" stroke="#ff6600" stroke-width="3" />
          <circle cx="256" cy="160" r="5" fill="#ff6600" stroke="white" stroke-width="2" />
        </svg>
        <p class="small text-muted mt-2">معاينة نصف القطر المحدد؛ يصبح نافذاً بعد الحفظ. <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">© OpenStreetMap contributors</a></p>
        <a href="https://www.google.com/maps?q=34.7333,36.7167" target="_blank" rel="noopener">فتح نقطة المركز على الخريطة</a>
      </div>
    </section>`,
})
export class DeliveryCoverageComponent implements OnInit, OnDestroy {
  radiusKm: number | null = null;
  loading = true;
  saving = false;
  success = false;
  error = '';
  circle = '';
  tiles: Array<{url: string; x: number; y: number}> = [];
  private subscriptions = new Subscription();
  constructor(private service: DashboardService) {}
  ngOnInit(): void { this.load(); }
  ngOnDestroy(): void { this.subscriptions.unsubscribe(); }
  get validRadius(): boolean {
    const radius = Number(this.radiusKm);
    return this.radiusKm != null && Number.isFinite(radius) && radius >= 0.1 && radius <= 100 &&
      Math.abs(radius * 100 - Math.round(radius * 100)) < 0.000001;
  }
  load(): void {
    this.loading = true; this.error = '';
    this.subscriptions.add(this.service.getDeliveryCoverage().subscribe({
      next: value => { this.radiusKm = value.radiusKm; this.loading = false; this.updateMap(); },
      error: () => { this.loading = false; this.error = 'تعذر تحميل منطقة التوصيل. تحقق من الاتصال ثم أعد المحاولة.'; },
    }));
  }
  save(): void {
    if (!this.validRadius || this.saving || this.loading) return;
    this.saving = true; this.error = ''; this.success = false;
    this.subscriptions.add(this.service.saveDeliveryCoverage({radiusKm: Number(this.radiusKm)}).subscribe({
      next: value => { this.radiusKm = value.radiusKm; this.saving = false; this.success = true; this.updateMap(); },
      error: () => { this.saving = false; this.error = 'تعذر حفظ منطقة التوصيل. لم يتم تأكيد التغيير؛ أعد التحميل للتحقق.'; },
    }));
  }
  updateMap(): void {
    if (!this.validRadius) { this.tiles = []; this.circle = ''; return; }
    const lat = 34.7333, lng = 36.7167, earth = 6371000;
    const radians = Math.PI / 180;
    const metresPerPixelAtZoom0 = 2 * Math.PI * 6378137 * Math.cos(lat * radians) / 256;
    const zoom = Math.max(4, Math.min(15, Math.floor(Math.log2(metresPerPixelAtZoom0 * 125 / (Number(this.radiusKm) * 1000)))));
    const scale = 256 * Math.pow(2, zoom);
    const project = (latitude: number, longitude: number) => ({
      x: (longitude + 180) / 360 * scale,
      y: (1 - Math.log(Math.tan(latitude * radians) + 1 / Math.cos(latitude * radians)) / Math.PI) / 2 * scale,
    });
    const centre = project(lat, lng), left = centre.x - 256, top = centre.y - 160;
    this.tiles = [];
    for (let x = Math.floor(left / 256); x <= Math.floor((left + 512) / 256); x++) {
      for (let y = Math.floor(top / 256); y <= Math.floor((top + 320) / 256); y++) {
        this.tiles.push({url: 'https://tile.openstreetmap.org/' + zoom + '/' + x + '/' + y + '.png', x: x * 256 - left, y: y * 256 - top});
      }
    }
    const angular = Number(this.radiusKm) * 1000 / earth, phi = lat * radians, lambda = lng * radians;
    const points: string[] = [];
    for (let bearing = 0; bearing <= 360; bearing += 5) {
      const theta = bearing * radians;
      const p = Math.asin(Math.sin(phi) * Math.cos(angular) + Math.cos(phi) * Math.sin(angular) * Math.cos(theta));
      const l = lambda + Math.atan2(Math.sin(theta) * Math.sin(angular) * Math.cos(phi), Math.cos(angular) - Math.sin(phi) * Math.sin(p));
      const point = project(p / radians, l / radians);
      points.push((point.x - left).toFixed(2) + ',' + (point.y - top).toFixed(2));
    }
    this.circle = points.join(' ');
  }
}
