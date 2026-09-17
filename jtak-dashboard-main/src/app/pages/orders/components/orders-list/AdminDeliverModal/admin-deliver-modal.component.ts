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
    if (this.order && !this.order.deliveryId) {
      this.cashResolutionMode = 'CompanyCash';
    }
  }

  isCod(): boolean {
    return this.order?.paymentMethod === 0;
  }

  hasAssignedDriver(): boolean {
    return !!this.order?.deliveryId;
  }

  submit(): void {
    this.errorMessage = '';
    const cleanOtp = (this.otp || '').trim();
    const cleanNotes = (this.notes || '').trim();

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
        this.errorMessage = err?.error?.title || err?.error?.detail || err?.error || err?.message || 'حدث خطأ أثناء إتمام عملية التسليم.';
      }
    });
  }
}
