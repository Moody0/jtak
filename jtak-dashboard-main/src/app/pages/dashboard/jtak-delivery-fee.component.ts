import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { DashboardService } from './services/dashboard.service';

@Component({
  selector: 'app-jtak-delivery-fee',
  styleUrls: ['./dashboard.component.scss'],
  template: `
    <section class="ops-config-card" aria-label="أجرة توصيل جيتك ماركت">
      <div class="ops-config-header">
        <div class="ops-config-icon"><i class="fas fa-shopping-bag"></i></div>
        <div>
          <h3 class="ops-config-title">أجرة توصيل جيتك ماركت</h3>
          <p class="ops-config-desc">مبلغ ثابت لكل طلب، مستقل عن سعر الكيلومتر والحد الأدنى للمتاجر ذات الموقع الفعلي.</p>
        </div>
      </div>
      <div class="ops-config-body">
        <p>جيتك ماركت متجر افتراضي ولا يحتاج إلى موقع لحساب الأجرة. هذه الأجرة يدفعها الزبون، وأجر المندوب يُحسب بصورة مستقلة.</p>
        <label class="ops-input-label" for="jtak-delivery-fee">أجرة التوصيل الثابتة للزبون</label>
        <div class="ops-input-group">
          <input id="jtak-delivery-fee" type="number" [(ngModel)]="amount" min="0" max="100000000" step="0.01"
            [disabled]="!loaded || saving" />
          <span class="ops-input-addon">ل.س</span>
        </div>
        <p class="ops-config-desc">تُطبق على الطلبات الجديدة. عند تفعيل التوصيل المجاني لجميع المتاجر يدفع الزبون صفرًا.</p>
        <p *ngIf="loading" role="status">جارٍ تحميل الأجرة الحالية…</p>
        <p *ngIf="error" class="ops-alert alert-danger" role="alert">{{ error }}</p>
        <p *ngIf="success" class="ops-alert alert-success" role="status">تم حفظ أجرة توصيل جيتك ماركت.</p>
      </div>
      <div class="ops-config-footer">
        <button *ngIf="!loaded && !loading" type="button" class="ops-btn-action" (click)="load()">إعادة المحاولة</button>
        <button type="button" class="ops-btn-action ops-btn-primary" (click)="save()" [disabled]="!loaded || saving || !valid">
          {{ saving ? 'جارٍ الحفظ…' : 'حفظ أجرة جيتك ماركت' }}
        </button>
      </div>
    </section>`
})
export class JtakDeliveryFeeComponent implements OnInit, OnDestroy {
  amount: number | null = null;
  loaded = false;
  loading = false;
  saving = false;
  success = false;
  error = '';
  private subscriptions = new Subscription();
  constructor(private service: DashboardService) {}
  ngOnInit(): void { this.load(); }
  get valid(): boolean {
    return this.amount !== null && Number.isFinite(this.amount) && this.amount >= 0 &&
      this.amount <= 100000000 && Math.abs(this.amount * 100 - Math.round(this.amount * 100)) < 0.000001;
  }
  load(): void {
    if (this.loading || this.saving) return;
    this.loading = true; this.loaded = false; this.error = ''; this.success = false;
    this.subscriptions.add(this.service.getJtakMarketDeliveryFee().subscribe({
      next: setting => {
        this.amount = setting.amount; this.loading = false; this.loaded = this.valid;
        if (!this.loaded) this.error = 'أجرة جيتك ماركت الحالية غير صالحة. تحقق من إعدادات المتجر.';
      },
      error: () => { this.loading = false; this.error = 'تعذر تحميل أجرة جيتك ماركت. أعد المحاولة.'; }
    }));
  }
  save(): void {
    if (!this.loaded || this.saving || !this.valid) return;
    this.saving = true; this.success = false; this.error = '';
    this.subscriptions.add(this.service.saveJtakMarketDeliveryFee({amount: this.amount!}).subscribe({
      next: setting => {
        this.amount = setting.amount; this.saving = false; this.success = this.valid;
        if (!this.success) this.error = 'تعذر تأكيد الأجرة المحفوظة. أعد تحميل الإعدادات.';
      },
      error: () => { this.saving = false; this.error = 'تعذر حفظ أجرة جيتك ماركت. أعد المحاولة.'; }
    }));
  }
  ngOnDestroy(): void { this.subscriptions.unsubscribe(); }
}
