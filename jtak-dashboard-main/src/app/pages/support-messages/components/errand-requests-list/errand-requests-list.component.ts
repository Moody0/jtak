import { Component, OnDestroy, OnInit } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Subscription, timer } from 'rxjs';
import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';
import { ErrandQueueStats, ErrandStatus, SupportMessage } from '../../models/support-message.model';
import { SupportMessagesService } from '../../services/support-messages.service';
import { ViewMessageModalComponent } from '../view-message-modal/view-message-modal.component';

@Component({
  selector: 'app-errand-requests-list',
  templateUrl: './errand-requests-list.component.html',
  styleUrls: ['./errand-requests-list.component.scss'],
})
export class ErrandRequestsListComponent implements OnInit, OnDestroy {
  readonly buckets = [
    { value: 'active', label: 'النشطة' },
    { value: 'new', label: 'جديدة / تحتاج تسعيراً' },
    { value: 'approved', label: 'وافق العميل' },
    { value: 'quoted', label: 'بانتظار العميل' },
    { value: 'in-progress', label: 'قيد التنفيذ' },
    { value: 'exceptions', label: 'الاستثناءات' },
    { value: 'closed', label: 'مكتملة / ملغاة' },
    { value: 'all', label: 'الكل' },
  ];
  bucket = 'active';
  searchInput = '';
  search = '';
  page = 1;
  readonly pageSize = 25;
  totalCount = 0;
  items: SupportMessage[] = [];
  stats: ErrandQueueStats = { new: 0, approved: 0, quoted: 0, inProgress: 0, closed: 0 };
  loading = false;
  error = false;
  private reloadRequested = false;
  private pollSubscription?: Subscription;
  private queueSubscription?: Subscription;
  private statsSubscription?: Subscription;

  constructor(
    private supportService: SupportMessagesService,
    private modalService: NgbModal,
    private notificationSummary: NotificationSummaryService
  ) {}

  ngOnInit(): void {
    this.pollSubscription = timer(0, 10000).subscribe(() => this.load());
  }

  ngOnDestroy(): void {
    this.pollSubscription?.unsubscribe();
    this.queueSubscription?.unsubscribe();
    this.statsSubscription?.unsubscribe();
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalCount / this.pageSize));
  }

  load(): void {
    if (this.loading) { this.reloadRequested = true; return; }
    this.loading = true;
    const requestedBucket = this.bucket;
    const requestedPage = this.page;
    const requestedSearch = this.search;
    this.queueSubscription = this.supportService.getErrandQueue(requestedBucket, requestedPage, requestedSearch).subscribe({
      next: (result) => {
        if (requestedBucket === this.bucket && requestedPage === this.page && requestedSearch === this.search) {
          this.items = result.items || [];
          this.totalCount = result.totalCount || 0;
          this.error = false;
        }
        this.loading = false;
        this.runQueuedReload();
      },
      error: () => { this.error = true; this.loading = false; this.runQueuedReload(); },
    });
    this.statsSubscription?.unsubscribe();
    this.statsSubscription = this.supportService.getErrandStats().subscribe({
      next: (stats) => { this.stats = stats; this.notificationSummary.refresh(); },
      error: () => {},
    });
  }

  private runQueuedReload(): void {
    if (this.reloadRequested) {
      this.reloadRequested = false;
      this.load();
    }
  }

  selectBucket(bucket: string): void {
    if (bucket === this.bucket) return;
    this.bucket = bucket;
    this.page = 1;
    this.load();
  }

  applySearch(): void {
    this.search = this.searchInput.trim();
    this.page = 1;
    this.load();
  }

  clearSearch(): void {
    this.searchInput = '';
    this.applySearch();
  }

  bucketCount(bucketValue: string): number | null {
    switch (bucketValue) {
      case 'new': return this.stats.new;
      case 'approved': return this.stats.approved;
      case 'quoted': return this.stats.quoted;
      case 'in-progress': return this.stats.inProgress;
      case 'closed': return this.stats.closed;
      default: return null;
    }
  }

  changePage(delta: number): void {
    const next = this.page + delta;
    if (next < 1 || next > this.totalPages) return;
    this.page = next;
    this.load();
  }

  open(request: SupportMessage): void {
    const modal = this.modalService.open(ViewMessageModalComponent, {
      size: 'lg', centered: true, backdrop: 'static',
    });
    modal.componentInstance.message = request;
    modal.componentInstance.updated.subscribe(() => this.load());
    modal.result.then(() => this.load(), () => this.load());
  }

  statusLabel(status?: ErrandStatus, request?: SupportMessage): string {
    switch (status) {
      case ErrandStatus.Submitted: return 'جديد – يحتاج عرض سعر';
      case ErrandStatus.Quoted: return 'بانتظار موافقة العميل';
      case ErrandStatus.Approved: return 'وافق العميل – يحتاج مندوباً';
      case ErrandStatus.Assigned:
        return request?.errandPurchaseCost != null || request?.errandReceiptReference || request?.errandReceiptPhotoToken
          ? 'وصلت الفاتورة – بانتظار المراجعة' : 'بانتظار الشراء';
      case ErrandStatus.Purchased: return 'بانتظار التسليم';
      case ErrandStatus.Delivered: return 'تم التسليم';
      case ErrandStatus.Declined: return 'رفض العرض – يحتاج متابعة';
      case ErrandStatus.Cancelled: return 'ملغى';
      case ErrandStatus.PurchasePending: return 'قيد تسجيل الشراء';
      case ErrandStatus.DeliveryPending: return 'قيد تسجيل التسليم';
      case ErrandStatus.ReturnPending: return 'قيد تسجيل الإرجاع';
      case ErrandStatus.Returned: return 'مرتجع';
      case ErrandStatus.Unavailable: return 'الغرض غير متوفر – يحتاج معالجة';
      default: return 'غير معروف';
    }
  }

  total(request: SupportMessage): number | null {
    return request.errandItemPrice != null && request.errandDeliveryFee != null
      ? Number(request.errandItemPrice) + Number(request.errandDeliveryFee) : null;
  }

  summary(message: string): string {
    return (message || '').split('\n')[0];
  }
}
