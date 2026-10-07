import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { OrdersService } from '../../../services/orders.service';
import { Order, OrderStatusHistoryItem } from '../../../models/orders.model';
import { finalize } from 'rxjs/operators';
import { TranslateService } from '@ngx-translate/core';

interface HistoryItemView {
  title: string;
  quantity: number;
  totalPrice?: number;
}

interface HistoryDetailsView {
  items: HistoryItemView[];
  subtotal?: number;
  deliveryFee?: number;
  total?: number;
  note?: string;
}

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
  private detailsCache = new Map<number, HistoryDetailsView | null>();

  constructor(
    public modal: NgbActiveModal,
    private ordersService: OrdersService,
    private translate: TranslateService
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
          this.errorMessage = this.translate.instant('ORDERS_PAGE.HISTORY_ERROR');
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

  getStatusLabel(status: number): string {
    const keyByStatus: Record<number, string> = {
      0: 'STATUS_PENDING',
      1: 'STATUS_ACCEPTED',
      2: 'STATUS_IN_TRANSIT',
      3: 'STATUS_DELIVERED',
      4: 'STATUS_REJECTED',
      5: 'STATUS_REVIEW',
      6: 'STATUS_CANCELED',
      7: 'STATUS_CANCELED_DRIVER',
      8: 'STATUS_READY'
    };
    return this.translate.instant(`ORDERS_PAGE.${keyByStatus[status] || 'STATUS_PROCESSING'}`);
  }

  getHistoryStatusLabel(item: OrderStatusHistoryItem): string {
    if (item?.status === 7 && item.driverId) {
      return this.translate.instant('ORDERS_PAGE.STATUS_CANCELED_DRIVER');
    }
    return this.getStatusLabel(item?.status);
  }

  getDetailsView(historyItem: OrderStatusHistoryItem): HistoryDetailsView | null {
    if (this.detailsCache.has(historyItem.id)) {
      return this.detailsCache.get(historyItem.id) || null;
    }

    const raw = historyItem.details?.trim();
    if (!raw) {
      this.detailsCache.set(historyItem.id, null);
      return null;
    }

    let parsed: any;
    try {
      parsed = JSON.parse(raw);
    } catch {
      const view = { items: [], note: raw };
      this.detailsCache.set(historyItem.id, view);
      return view;
    }

    const records = Array.isArray(parsed) ? parsed : [parsed];
    const items = records
      .map((record: any): HistoryItemView | null => {
        if (!record || typeof record !== 'object') return null;
        const title = record.ProductTitle || record.productTitle || record.Name || record.name;
        if (!title) return null;
        const quantity = Number(record.Quantity ?? record.quantity ?? 1) || 1;
        const price = record.TotalPrice ?? record.totalPrice ?? record.TotalFinalPrice ?? record.totalFinalPrice;
        const totalPrice = price != null && Number.isFinite(Number(price)) ? Number(price) : undefined;
        return { title, quantity, totalPrice };
      })
      .filter((item: HistoryItemView | null): item is HistoryItemView => !!item);

    if (!items.length) {
      const view = { items: [], note: this.translate.instant('ORDERS_PAGE.HISTORY_CHANGE_RECORDED') };
      this.detailsCache.set(historyItem.id, view);
      return view;
    }

    const subtotal = items.some(item => item.totalPrice != null)
      ? items.reduce((sum, item) => sum + (item.totalPrice ?? 0), 0)
      : undefined;
    // Use the saved customer fee, including zero for free delivery; do not reprice historical orders.
    const fee = Number(historyItem.deliveryFee ?? this.order?.deliveryFee ?? 0);
    const deliveryFee = Number.isFinite(fee) && fee >= 0 ? fee : 0;
    const total = subtotal != null ? subtotal + deliveryFee : undefined;
    const view = { items, subtotal, deliveryFee, total };
    this.detailsCache.set(historyItem.id, view);
    return view;
  }
}
