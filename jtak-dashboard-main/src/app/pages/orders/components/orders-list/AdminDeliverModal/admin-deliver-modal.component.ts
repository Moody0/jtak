import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { OrdersService } from '../../../services/orders.service';
import { Order } from '../../../models/orders.model';
import { finalize } from 'rxjs/operators';

@Component({
  selector: 'app-admin-deliver-modal',
  templateUrl: './admin-deliver-modal.component.html',
  styleUrls: ['./admin-deliver-modal.component.scss']
})
export class AdminDeliverModalComponent implements OnInit {
  @Input() order: Order;

  otp: string = '';
  notes: string = '';
  cashResolutionMode: string = 'DriverCashFloat';
  isLoading: boolean = false;
  errorMessage: string = '';

  constructor(
    public modal: NgbActiveModal,
    private ordersService: OrdersService
  ) {}

  ngOnInit(): void {
    if (!this.hasAssignedDriver()) {
      this.cashResolutionMode = 'CompanyCash';
    }
  }

  isCod(): boolean {
    return this.order?.paymentMethod === 0;
  }

  hasAssignedDriver(): boolean {
    return !!this.order?.deliveryId && this.order.deliveryId !== '00000000-0000-0000-0000-000000000000';
  }

  getGrandTotal(): number {
    const grandTotal = Number(this.order?.grandTotal);
    if (this.order?.grandTotal != null && Number.isFinite(grandTotal)) {
      return grandTotal;
    }
    return Number(this.order?.price || 0) + Number(this.order?.deliveryFee || 0);
  }

  private getErrorMessage(error: any): string {
    const body = error?.error;
    if (typeof body === 'string' && body.trim()) return body;
    if (body && typeof body === 'object') {
      const messages = [body.title, body.detail, body.message, body.errorDescription]
        .filter((value): value is string => typeof value === 'string' && !!value.trim());
      if (messages.length) return messages[0];
      if (Array.isArray(body.errors)) {
        const errors = body.errors.filter((value: unknown): value is string => typeof value === 'string' && !!value.trim());
        if (errors.length) return errors.join(' ');
      }
    }
    return typeof error?.message === 'string' && error.message.trim()
      ? error.message
      : 'حدث خطأ أثناء إتمام عملية التسليم.';
  }

  submit(): void {
    if (this.isLoading || !this.order?.id) return;
    this.errorMessage = '';
    const cleanOtp = (this.otp || '').trim();
    const cleanNotes = (this.notes || '').trim();
    if (cleanOtp && !/^\d{4}$/.test(cleanOtp)) {
      this.errorMessage = 'رمز استلام الطلب يجب أن يكون 4 أرقام.';
      return;
    }

    if (!cleanOtp && !cleanNotes) {
      this.errorMessage = 'يجب إدخال رمز التحقق (PIN) للعميل، أو تدوين سبب/ملاحظات التسليم الإداري.';
      return;
    }

    this.isLoading = true;
    this.ordersService.deliver(this.order.id, {
      otp: cleanOtp || undefined,
      notes: cleanNotes || undefined,
      cashResolutionMode: this.isCod() ? this.cashResolutionMode : undefined
    }).pipe(
      finalize(() => this.isLoading = false)
    ).subscribe({
      next: () => this.modal.close(true),
      error: (err) => {
        this.errorMessage = this.getErrorMessage(err);
      }
    });
  }
}
