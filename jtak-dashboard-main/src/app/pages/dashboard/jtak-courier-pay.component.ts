import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { DashboardService } from './services/dashboard.service';

@Component({
  selector: 'app-jtak-courier-pay',
  styleUrls: ['./dashboard.component.scss'],
  template: `
    <section class="ops-config-card" aria-label="نظام أجر مندوب جيتك ماركت">
      <div class="ops-config-header">
        <div class="ops-config-icon"><i class="fas fa-motorcycle"></i></div>
        <div><h3 class="ops-config-title">نظام أجر مندوب جيتك ماركت</h3>
          <p class="ops-config-desc">إعداد مستقل لجيتك ماركت. لا يضاف أجر المندوب إلى المبلغ المطلوب من العميل.</p></div>
      </div>
      <div class="ops-config-body">
        <label for="jtak-courier-mode" class="ops-input-label">طريقة احتساب أجر المندوب</label>
        <select id="jtak-courier-mode" [(ngModel)]="mode" [disabled]="!loaded || saving" class="form-select mb-3">
          <option [ngValue]="0">راتب شهري</option>
          <option [ngValue]="3">مبلغ ثابت لكل طلب مكتمل</option>
          <option [ngValue]="2">نسبة من أجرة التوصيل الأصلية</option>
        </select>
        <p *ngIf="mode === 0">النظام الحالي: راتب شهري. لا يُسجل أجر إضافي لكل طلب. يتم الاتفاق على الراتب وصرفه بصورة منفصلة؛ هذا الإعداد لا يحدد مبلغ الراتب أو يصرفه تلقائياً.</p>
        <div *ngIf="mode !== 0">
          <label for="jtak-courier-rate" class="ops-input-label">{{ mode === 3 ? 'أجر المندوب لكل طلب مكتمل' : 'نسبة المندوب من أجرة التوصيل الأصلية' }}</label>
          <div class="ops-input-group">
            <input id="jtak-courier-rate" type="number" [(ngModel)]="rate" min="0.01" [max]="mode === 2 ? 100 : 100000000" step="0.01" [disabled]="!loaded || saving" />
            <span class="ops-input-addon">{{ mode === 3 ? 'ل.س' : '%' }}</span>
          </div>
          <p class="ops-config-desc">يستحق الأجر عند إتمام الطلب. التوصيل المجاني للعميل لا يلغي أجر المندوب.</p>
        </div>
        <p class="ops-config-desc">تسري التغييرات على الطلبات الجديدة فقط. جيتك ماركت ليس له نقطة استلام لحساب الأجر حسب الكيلومتر.</p>
        <p *ngIf="loading" role="status">جارٍ تحميل الإعدادات…</p>
        <p *ngIf="error" class="ops-alert alert-danger" role="alert">{{ error }}</p>
        <p *ngIf="success" class="ops-alert alert-success" role="status">تم حفظ نظام أجر مندوب جيتك ماركت.</p>
      </div>
      <div class="ops-config-footer">
        <button *ngIf="!loaded && !loading" type="button" (click)="load()" class="ops-btn-action">إعادة المحاولة</button>
        <button appDashboardWrite="settings" type="button" (click)="save()" [disabled]="!loaded || saving || !valid" class="ops-btn-action ops-btn-primary">
          {{ saving ? 'جارٍ الحفظ…' : 'حفظ نظام أجر المندوب' }}
        </button>
      </div>
    </section>`
})
export class JtakCourierPayComponent implements OnInit, OnDestroy {
  mode = 0;
  rate: number | null = 0;
  loaded = false; loading = false; saving = false; success = false; error = '';
  private subscriptions = new Subscription();
  constructor(private service: DashboardService) {}
  ngOnInit(): void { this.load(); }
  get valid(): boolean {
    if (this.mode === 0) return true;
    return (this.mode === 2 || this.mode === 3) && this.rate !== null && Number.isFinite(this.rate) &&
      this.rate > 0 && this.rate <= (this.mode === 2 ? 100 : 100000000) &&
      Math.abs(this.rate * 100 - Math.round(this.rate * 100)) < 0.000001;
  }
  load(): void {
    if (this.loading || this.saving) return;
    this.loaded = false; this.loading = true; this.success = false; this.error = '';
    this.subscriptions.add(this.service.getJtakMarketCourierPay().subscribe({
      next: setting => {
        this.mode = setting.mode; this.rate = setting.rate; this.loading = false;
        this.loaded = [0, 2, 3].includes(this.mode);
        if (!this.loaded) this.error = 'تعذر قراءة نظام أجر المندوب. تحقق من الإعدادات.';
      },
      error: () => { this.loading = false; this.error = 'تعذر تحميل نظام أجر مندوب جيتك ماركت.'; }
    }));
  }
  save(): void {
    if (!this.loaded || this.saving || !this.valid) return;
    this.saving = true; this.success = false; this.error = '';
    this.subscriptions.add(this.service.saveJtakMarketCourierPay({mode: this.mode, rate: this.mode === 0 ? 0 : this.rate!}).subscribe({
      next: setting => {
        this.mode = setting.mode; this.rate = setting.rate; this.saving = false; this.success = this.valid;
        if (!this.success) this.error = 'تعذر تأكيد الإعدادات المحفوظة. أعد تحميلها.';
      },
      error: () => { this.saving = false; this.error = 'تعذر حفظ نظام أجر مندوب جيتك ماركت.'; }
    }));
  }
  ngOnDestroy(): void { this.subscriptions.unsubscribe(); }
}
