import { Component, Input } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Order } from '../../../models/orders.model';
import { OrderDetailStatus } from '../../../models/order-status.enum';

@Component({
  selector: 'app-order-details-modal',
  templateUrl: './order-details-modal.component.html',
  styleUrls: ['./order-details-modal.component.scss']
})
export class OrderDetailsModalComponent {
  @Input() order: Order;
  @Input() statusLabel: string;
  readonly OrderDetailStatus = OrderDetailStatus;

  constructor(public modal: NgbActiveModal) {}

  getItemsCount(): number {
    return (this.order?.orderDetails || []).reduce((total, detail) => total + (Number(detail.quantity) || 0), 0);
  }

  getDeliveryFee(): number {
    return Number(this.order?.deliveryFee || 0);
  }

  getGrandTotal(): number {
    return Number(this.order?.grandTotal ?? ((this.order?.price || 0) + this.getDeliveryFee()));
  }

  getCashToCollect(): number {
    if (this.order?.paymentMethod !== 0) return 0;
    return this.getGrandTotal();
  }

  printReceipt(): void {
    document.body.classList.add('print-individual-receipt');
    setTimeout(() => {
      window.print();
      setTimeout(() => {
        document.body.classList.remove('print-individual-receipt');
      }, 500);
    }, 100);
  }
}
