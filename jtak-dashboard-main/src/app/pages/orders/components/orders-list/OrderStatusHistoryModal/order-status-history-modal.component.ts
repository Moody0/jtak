import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { OrdersService } from '../../../services/orders.service';
import { Order, OrderStatusHistoryItem } from '../../../models/orders.model';
import { finalize } from 'rxjs/operators';

@Component({
  selector: 'app-order-status-history-modal',
  templateUrl: './order-status-history-modal.component.html',
  styleUrls: ['./order-status-history-modal.component.scss']
})
export class OrderStatusHistoryModalComponent implements OnInit {
  @Input() order: Order;

  history: OrderStatusHistoryItem[] = [];
  isLoading: boolean = true;
  errorMessage: string = '';

  constructor(
    public modal: NgbActiveModal,
    private ordersService: OrdersService
  ) {}

  ngOnInit(): void {
    if (!this.order?.id) {
      this.isLoading = false;
      return;
    }
    this.ordersService.getHistory(this.order.id)
      .pipe(finalize(() => this.isLoading = false))
      .subscribe({
        next: (items) => {
          this.history = items || [];
        },
        error: () => {
          this.errorMessage = 'تعذر تحميل سجل تدقيق الحالات لهذا الطلب.';
        }
      });
  }

  getStatusBadgeClass(status: number): string {
    switch (status) {
      case 0: return 'badge-light-warning text-warning border border-warning';
      case 1: return 'badge-light-primary text-primary border border-primary';
      case 2: return 'badge-light-info text-info border border-info';
      case 3: return 'badge-light-success text-success border border-success';
      case 4: return 'badge-light-danger text-danger border border-danger';
      case 5: return 'badge-light-warning text-warning border border-warning';
      case 6:
      case 7: return 'badge-light-danger text-danger border border-danger';
      case 8: return 'badge-light-primary text-primary border border-primary';
      default: return 'badge-light-secondary text-muted';
    }
  }

  getStatusIcon(status: number): string {
    switch (status) {
      case 0: return 'fa-hourglass-half';
      case 1: return 'fa-utensils';
      case 2: return 'fa-motorcycle';
      case 3: return 'fa-check-double';
      case 4: return 'fa-ban';
      case 5: return 'fa-clock';
      case 6:
      case 7: return 'fa-times-circle';
      case 8: return 'fa-box-open';
      default: return 'fa-info-circle';
    }
  }
}
