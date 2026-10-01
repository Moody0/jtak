import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { DashboardService } from './services/dashboard.service';

@Component({
  selector: 'app-delivery-coverage',
  template: `
    <section class="card ops-coverage-card my-4" dir="rtl">
      <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2 py-3 px-4">
        <div class="d-flex align-items-center gap-3">
          <div class="ops-header-icon">
            <i class="fas fa-map-marked-alt"></i>
          </div>
          <div>
            <h2 class="card-title h5 mb-0 fw-bold">منطقة التوصيل في حمص</h2>
            <span class="text-muted small">النطاق الجغرافي لخدمة الطلبات والعناوين</span>
          </div>
        </div>
        <div class="d-flex align-items-center gap-2">
          <span class="badge bg-light text-dark border px-3 py-2 fs-7 fw-semibold">
            <i class="fas fa-crosshairs text-primary me-1"></i>
            34.7333، 36.7167
          </span>
          <a href="https://www.google.com/maps?q=34.7333,36.7167" target="_blank" rel="noopener"
             class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1 px-3 py-2">
            <i class="fas fa-map-pin text-danger"></i>
            <span>فتح نقطة المركز على الخريطة</span>
          </a>
        </div>
      </div>

      <div class="card-body p-4">
        <div class="row g-4 align-items-stretch">
          <!-- Right Column: Settings & Configuration (col-12 col-lg-5 col-xl-4) -->
          <div class="col-12 col-lg-5 col-xl-4 d-flex flex-column justify-content-between">
            <div>
              <!-- Center notice -->
              <div class="ops-info-box mb-3 p-3 rounded-3">
                <div class="d-flex align-items-start gap-2">
                  <i class="fas fa-info-circle text-primary mt-1"></i>
                  <p class="small text-secondary mb-0">
                    المركز الثابت: 34.7333، 36.7167. يجب أن يكون موقع العميل الحالي وعنوان التوصيل داخل هذه المنطقة.
                  </p>
                </div>
              </div>

              <!-- Radius Input Group -->
              <div class="mb-3">
                <label for="coverage-radius" class="form-label fw-bold small text-dark d-flex justify-content-between align-items-center mb-1">
                  <span>نصف قطر التغطية (كم)</span>
                  <span *ngIf="validRadius" class="badge bg-primary-subtle text-primary border border-primary-subtle px-2 py-1">
                    القطر: {{ (radiusKm || 0) * 2 }} كم
                  </span>
                </label>
                <div class="input-group mb-2">
                  <span class="input-group-text bg-light text-muted border-end-0">
                    <i class="fas fa-ruler-combined"></i>
                  </span>
                  <input id="coverage-radius" class="form-control text-center fw-bold fs-5" type="number"
                    min="0.1" max="100" step="0.01" [(ngModel)]="radiusKm" (ngModelChange)="updateMap(); success = false"
                    [disabled]="loading || saving" placeholder="25" />
                  <span class="input-group-text bg-light fw-bold text-muted border-start-0">كم</span>
                </div>

                <!-- Quick Presets -->
                <div class="d-flex flex-wrap align-items-center gap-1 mb-3">
                  <span class="small text-muted me-1">تحديد سريع:</span>
                  <a role="button" *ngFor="let p of [10, 15, 20, 25, 30]"
                    class="btn btn-sm btn-preset py-1 px-2"
                    [class.active]="radiusKm === p"
                    (click)="setRadius(p)">
                    {{ p }} كم
                  </a>
                </div>

                <!-- Action Button -->
                <button class="btn btn-primary w-100 py-2 fw-bold d-flex align-items-center justify-content-center gap-2"
                  type="button" (click)="save()" [disabled]="loading || saving || !validRadius">
                  <i *ngIf="saving" class="fas fa-spinner fa-spin"></i>
                  <i *ngIf="!saving" class="fas fa-save"></i>
                  <span>{{ saving ? 'جارٍ الحفظ...' : 'حفظ منطقة التوصيل' }}</span>
                </button>
              </div>

              <!-- Alerts -->
              <p *ngIf="!loading && !validRadius" class="text-danger small mb-2">
                <i class="fas fa-exclamation-circle me-1"></i>
                أدخل نصف قطر بين 0.1 و100 كم، حتى منزلتين عشريتين.
              </p>
              <div *ngIf="loading" class="alert alert-info py-2 px-3 small mb-2">
                <i class="fas fa-spinner fa-spin me-1"></i>
                جارٍ تحميل منطقة التوصيل...
              </div>
              <div *ngIf="error" class="alert alert-danger py-2 px-3 small mb-2" role="alert">
                <i class="fas fa-times-circle me-1"></i>
                {{ error }}
                <button type="button" class="btn btn-link btn-sm p-0 ms-1 text-danger fw-bold" (click)="load()">إعادة التحميل</button>
              </div>
              <div *ngIf="success" class="alert alert-success py-2 px-3 small mb-2" role="status">
                <i class="fas fa-check-circle me-1"></i>
                تم حفظ منطقة التوصيل. تنطبق على الطلبات الجديدة دون تغيير الطلبات السابقة.
              </div>
            </div>

            <!-- Hint footer -->
            <p class="text-muted small mb-0 mt-3 pt-2 border-top">
              <i class="fas fa-route me-1 opacity-75"></i>
              مثال: 10 كم تعني نصف القطر، أي قطر 20 كم. القياس مسافة مباشرة من المركز، وليس مسافة الطريق.
            </p>
          </div>

          <!-- Left Column: Live Interactive Map (col-12 col-lg-7 col-xl-8) -->
          <div class="col-12 col-lg-7 col-xl-8">
            <div class="ops-map-container position-relative rounded-3 overflow-hidden border">
              <!-- Live Overlay Badge -->
              <div *ngIf="validRadius" class="ops-map-badge position-absolute top-0 start-0 m-3 px-3 py-1 rounded-pill bg-white border d-flex align-items-center gap-2 shadow-sm">
                <span class="ops-pulse-dot"></span>
                <span class="small fw-bold text-dark">
                  نصف القطر: <strong class="text-primary">{{ radiusKm }} كم</strong>
                </span>
              </div>

              <!-- SVG Interactive Map -->
              <svg *ngIf="validRadius" viewBox="0 0 512 320" role="img" aria-label="معاينة دائرة التغطية حول مركز حمص"
                class="ops-coverage-svg w-100 d-block">
                <image *ngFor="let tile of tiles" [attr.href]="tile.url" [attr.x]="tile.x" [attr.y]="tile.y" width="256" height="256" />
                <polygon [attr.points]="circle" fill="#ff660033" stroke="#ff6600" stroke-width="3" />
                <circle cx="256" cy="160" r="5" fill="#ff6600" stroke="white" stroke-width="2" />
              </svg>

              <!-- Empty / Invalid State -->
              <div *ngIf="!validRadius" class="d-flex flex-column align-items-center justify-content-center p-5 text-muted bg-light" style="min-height: 280px;">
                <i class="fas fa-map-marked fa-3x mb-2 text-secondary opacity-50"></i>
                <span>أدخل نصف قطر صالح لمعاينة الخريطة</span>
              </div>
            </div>

            <!-- Map Footer with Attribution -->
            <div class="d-flex justify-content-between align-items-center mt-2 px-1 flex-wrap gap-2">
              <span class="small text-muted">
                معاينة نصف القطر المحدد؛ يصبح نافذاً بعد الحفظ.
              </span>
              <span class="small text-muted">
                <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener" class="text-muted text-decoration-none">
                  © OpenStreetMap contributors
                </a>
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>`,
  styles: [`
    .ops-coverage-card {
      border: 1px solid #e2e8f0;
      border-radius: 14px;
      overflow: hidden;
      background: #ffffff;
    }
    .ops-header-icon {
      width: 40px;
      height: 40px;
      border-radius: 10px;
      background: rgba(255, 102, 0, 0.1);
      color: #ff6600;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.15rem;
    }
    .ops-info-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
    }
    .btn-preset {
      border: 1px solid #cbd5e1;
      background: #ffffff;
      color: #475569;
      font-size: 0.75rem;
      border-radius: 20px;
      transition: all 0.15s ease;
    }
    .btn-preset:hover {
      background: #f1f5f9;
      color: #0f172a;
      border-color: #94a3b8;
    }
    .btn-preset.active {
      background: #ff6600;
      color: #ffffff;
      border-color: #ff6600;
      font-weight: 600;
    }
    .ops-map-container {
      background: #edf1ed;
      border-color: #e2e8f0 !important;
    }
    .ops-coverage-svg {
      min-height: 280px;
      max-height: 420px;
      background: #edf1ed;
      object-fit: cover;
    }
    .ops-map-badge {
      z-index: 5;
      backdrop-filter: blur(4px);
      background: rgba(255, 255, 255, 0.95) !important;
    }
    .ops-pulse-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #ff6600;
      display: inline-block;
      animation: pulse-ring 1.8s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;
    }
    @keyframes pulse-ring {
      0% { transform: scale(0.9); opacity: 0.8; }
      50% { transform: scale(1.3); opacity: 1; }
      100% { transform: scale(0.9); opacity: 0.8; }
    }
    .bg-primary-subtle {
      background-color: rgba(255, 102, 0, 0.1) !important;
    }
    .border-primary-subtle {
      border-color: rgba(255, 102, 0, 0.25) !important;
    }
  `]
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

  setRadius(val: number): void {
    this.radiusKm = val;
    this.updateMap();
    this.success = false;
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
