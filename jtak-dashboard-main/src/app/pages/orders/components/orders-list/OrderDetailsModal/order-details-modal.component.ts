import { Component, Input } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Order } from '../../../models/orders.model';
import { OrderDetailStatus } from '../../../models/order-status.enum';
import { printDocument } from 'src/app/shared/printing/print-document';

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
    printDocument('#orderReceiptPrintArea');
  }
}
