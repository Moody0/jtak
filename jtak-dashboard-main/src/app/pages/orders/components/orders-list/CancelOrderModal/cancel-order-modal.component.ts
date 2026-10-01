import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { OrdersService } from '../../../services/orders.service';
import { Order } from '../../../models/orders.model';
import { forkJoin } from 'rxjs';
import { finalize } from 'rxjs/operators';

@Component({
  selector: 'app-cancel-order-modal',
  templateUrl: './cancel-order-modal.component.html',
  styleUrls: ['./cancel-order-modal.component.scss']
})
export class CancelOrderModalComponent implements OnInit {
  @Input() order?: Order;
  @Input() orders?: Order[];

  reason: string = '';
  isLoading: boolean = false;
  errorMessage: string = '';

  readonly quickReasons: string[] = [
    'طلب العميل الإلغاء',
    'عدم توفر المنتجات في المتجر',
    'تعذر التواصل مع العميل',
    'تأخر غير مقبول في التجهيز',
    'طلب مكرر / خطأ في العنوان',
    'إلغاء بناءً على طلب المتجر'
  ];

  constructor(
    public modal: NgbActiveModal,
    private ordersService: OrdersService
  ) {}

  ngOnInit(): void {}

  isBulk(): boolean {
    return Array.isArray(this.orders) && this.orders.length > 0;
  }

  getOrdersCount(): number {
    if (this.isBulk()) return this.orders!.length;
    return this.order ? 1 : 0;
  }

  selectReason(r: string): void {
    this.reason = r;
    this.errorMessage = '';
  }

  canSubmit(): boolean {
    return !!this.reason && this.reason.trim().length > 0 && !this.isLoading;
  }

  private extractErrorMessage(error: any): string {
    const body = error?.error;
    if (typeof body === 'string' && body.trim()) return body;
    if (body && typeof body === 'object') {
      const messages = [body.title, body.detail, body.message, body.errorDescription]
        .filter((val): val is string => typeof val === 'string' && !!val.trim());
      if (messages.length) return messages[0];
      if (Array.isArray(body.errors)) {
        const errs = body.errors.filter((val: unknown): val is string => typeof val === 'string' && !!val.trim());
        if (errs.length) return errs.join(' ');
      }
    }
    return typeof error?.message === 'string' && error.message.trim()
      ? error.message
      : 'حدث خطأ أثناء معالجة إلغاء الطلب، يرجى المحاولة لاحقاً.';
  }

  confirm(): void {
    if (!this.canSubmit()) return;

    const trimmedReason = this.reason.trim();
    this.isLoading = true;
    this.errorMessage = '';

    if (this.isBulk()) {
      const requests = this.orders!.map(o => this.ordersService.cancel(o.id, trimmedReason));
      forkJoin(requests)
        .pipe(finalize(() => { this.isLoading = false; }))
        .subscribe({
          next: () => {
            this.modal.close(true);
          },
          error: (err) => {
            this.errorMessage = this.extractErrorMessage(err);
          }
        });
    } else if (this.order) {
      this.ordersService.cancel(this.order.id, trimmedReason)
        .pipe(finalize(() => { this.isLoading = false; }))
        .subscribe({
          next: () => {
            this.modal.close(true);
          },
          error: (err) => {
            this.errorMessage = this.extractErrorMessage(err);
          }
        });
    }
  }
}
