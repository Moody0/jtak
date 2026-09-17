import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { OrdersService } from '../../services/orders.service';
import { Order } from '../../models/orders.model';
import { OrderDetailStatus } from '../../models/order-status.enum';
import { EditDilevry } from './EditDilevry/edit-dilevry.component';
import { LiveTrackModalComponent } from './LiveTrackModal/live-track-modal.component';
import { AdminDeliverModalComponent } from './AdminDeliverModal/admin-deliver-modal.component';
import { OrderStatusHistoryModalComponent } from './OrderStatusHistoryModal/order-status-history-modal.component';
import { forkJoin, interval } from 'rxjs';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { DeleteModalComponent } from 'src/app/modules/shared/components/delete-modal/delete-modal.component';
import { TranslateService } from '@ngx-translate/core';


import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';

@Component({
  selector: 'app-orders-list',
  templateUrl: './orders-list.component.html',
  styleUrls: ['./orders-list.component.scss'],
})
export class OrdersListComponent
  implements
  OnInit,
  OnDestroy,
  ISortView,
  IPaginatorView,
  ISearchView {
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;
  order: Order;
  lastUpdated = new Date();
  activeTab: 'ALL' | 'PENDING' | 'READY' | 'IN_TRANSIT' | 'DELIVERED' | 'CANCELED' | 'UNASSIGNED' = 'ALL';
  expandedOrderIds = new Set<number>();

  constructor(
    private fb: FormBuilder,
    public ordersService: OrdersService,
    private modalService: NgbModal,
    private translate: TranslateService,
    private notificationSummaryService: NotificationSummaryService
  ) { }


  setActiveTab(tab: 'ALL' | 'PENDING' | 'READY' | 'IN_TRANSIT' | 'DELIVERED' | 'CANCELED' | 'UNASSIGNED') {
    this.activeTab = tab;
    this.selection.clear();
  }

  getFilteredOrders(orders: Order[]): Order[] {
    if (!orders || !orders.length) return [];
    if (this.activeTab === 'ALL') return orders;
    return orders.filter(o => {
      const details = o.orderDetails || [];
      const allTerminal = details.length > 0 && details.every(d =>
        d.orderDetailStatus === OrderDetailStatus.CustomerCanceled ||
        d.orderDetailStatus === OrderDetailStatus.DeliveryCanceled ||
        d.orderDetailStatus === OrderDetailStatus.MerchantRejected);

      const active = details.filter(d =>
        d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
        d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
        d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);

      const isDelivered = active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered);
      const isCanceled = allTerminal;
      const isInTransit = active.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted);
      const isReady = active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup);
      const isPending = details.length === 0 || active.some(d => d.orderDetailStatus === OrderDetailStatus.Pending || d.orderDetailStatus === OrderDetailStatus.CustomerPending || d.orderDetailStatus === OrderDetailStatus.MerchantAccepted);

      switch (this.activeTab) {
        case 'PENDING':
          return isPending;
        case 'READY':
          return isReady;
        case 'IN_TRANSIT':
          return isInTransit;
        case 'DELIVERED':
          return isDelivered;
        case 'CANCELED':
          return isCanceled;
        case 'UNASSIGNED':
          return !this.hasAssignedDriver(o) && !isDelivered && !isCanceled;
        default:
          return true;
      }
    });
  }

  getCounts(orders: Order[]) {
    if (!orders || !orders.length) {
      return { total: 0, pending: 0, ready: 0, inTransit: 0, delivered: 0, canceled: 0, unassigned: 0 };
    }
    let pending = 0, ready = 0, inTransit = 0, delivered = 0, canceled = 0, unassigned = 0;
    for (const o of orders) {
      const details = o.orderDetails || [];
      const allTerminal = details.length > 0 && details.every(d =>
        d.orderDetailStatus === OrderDetailStatus.CustomerCanceled ||
        d.orderDetailStatus === OrderDetailStatus.DeliveryCanceled ||
        d.orderDetailStatus === OrderDetailStatus.MerchantRejected);

      const active = details.filter(d =>
        d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
        d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
        d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);

      const isDelivered = active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered);
      const isCanceled = allTerminal;
      const isInTransit = active.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted);
      const isReady = active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup);
      const isPending = details.length === 0 || active.some(d => d.orderDetailStatus === OrderDetailStatus.Pending || d.orderDetailStatus === OrderDetailStatus.CustomerPending || d.orderDetailStatus === OrderDetailStatus.MerchantAccepted);

      if (isDelivered) delivered++;
      else if (isCanceled) canceled++;
      else if (isInTransit) inTransit++;
      else if (isReady) ready++;
      else if (isPending) pending++;

      if (!this.hasAssignedDriver(o) && !isDelivered && !isCanceled) {
        unassigned++;
      }
    }
    return {
      total: orders.length,
      pending,
      ready,
      inTransit,
      delivered,
      canceled,
      unassigned
    };
  }

  toggleExpand(orderId: number) {
    if (this.expandedOrderIds.has(orderId)) {
      this.expandedOrderIds.delete(orderId);
    } else {
      this.expandedOrderIds.add(orderId);
    }
  }

  isExpanded(orderId: number): boolean {
    return this.expandedOrderIds.has(orderId);
  }

  clearSearch() {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  hasActiveFilter(): boolean {
    return this.activeTab !== 'ALL' || !!this.searchGroup.get('searchTerm')?.value;
  }

  resetFilters() {
    this.activeTab = 'ALL';
    this.clearSearch();
  }

  getInitials(name?: string): string {
    if (!name || !name.trim()) return 'U';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return name.charAt(0).toUpperCase();
  }

  refreshOrders() {
    this.lastUpdated = new Date();
    this.ordersService.fetchPost();
    this.notificationSummaryService.refresh();
  }


  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.ordersService.patchState({ paginator });
  }

  sorting: SortState;
  sort(column: string): void {
    this.selection.clear();
    const sorting = this.sorting;
    const isActiveColumn = sorting.column === column;
    if (!isActiveColumn) {
      sorting.column = column;
      sorting.direction = 'ASC';
    } else {
      sorting.direction = sorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }

    this.ordersService.patchState({ sorting });
  }

  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string) {
    this.selection.clear();
    this.ordersService.patchState({ searchTerm });
  }
  confirmCancel(order: Order): void {
    if (!order || !this.canCancel(order)) {
      window.alert('لا يمكن إلغاء طلب مكتمل أو ملغي مسبقاً.');
      return;
    }
    const orderId = order.id;
    const reason = window.prompt('سبب رفض / إلغاء الطلب (سيظهر للعميل):');
    if (reason === null) return;
    if (!reason.trim()) {
      window.alert('يرجى كتابة سبب واضح للرفض أو الإلغاء.');
      return;
    }
    const modalRef = this.modalService.open(DeleteModalComponent);
    modalRef.componentInstance.title = `Cancel order #${orderId}?`;
    modalRef.componentInstance.confirmationText = 'This stops fulfillment for the entire order. This action cannot be undone.';
    modalRef.componentInstance.deletingText = 'Cancelling order…';
    modalRef.componentInstance.confirmLabel = 'Cancel order';
    this.subs.sink = modalRef.componentInstance.cancelClicked.subscribe(() => modalRef.dismiss());
    this.subs.sink = modalRef.componentInstance.deleteClicked.subscribe(() => {
      if (modalRef.componentInstance.isLoading) return;
      modalRef.componentInstance.isLoading = true;
      this.ordersService.cancel(orderId, reason.trim()).subscribe({
        next: (res) => {
          modalRef.close();
          this.ordersService.fetchPost();
        },
        error: () => {
          modalRef.componentInstance.isLoading = false;
        }
      });
    });
  }

  canCancel(order: Order): boolean {
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    const details = order.orderDetails;

    const allTerminal = details.every(d =>
      d.orderDetailStatus === OrderDetailStatus.CustomerCanceled ||
      d.orderDetailStatus === OrderDetailStatus.DeliveryCanceled ||
      d.orderDetailStatus === OrderDetailStatus.MerchantRejected);
    if (allTerminal) return false;

    const active = details.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);
    if (active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered)) {
      return false;
    }

    return true;
  }

  approve(order: Order): void {
    this.acceptOrder(order);
  }

  acceptOrder(order: Order): void {
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'order';
    modalRef.componentInstance.actionLabel = 'قبول وتجهيز الطلب';
    modalRef.componentInstance.description = `قبول الطلب #${order.id} وبدء تجهيزه؟`;
    modalRef.componentInstance.action = () => this.ordersService.accept(order.id);
    modalRef.result.then(() => this.ordersService.fetchPost(), () => {});
  }

  canApprove(order: Order): boolean {
    return order.canAdminApprove === true || this.canAccept(order);
  }

  canAccept(order: Order): boolean {
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    return order.orderDetails.some(d => d.orderDetailStatus === OrderDetailStatus.Pending || d.orderDetailStatus === OrderDetailStatus.CustomerPending);
  }

  rejectOrder(order: Order): void {
    if (!order || !this.canReject(order)) {
      window.alert('لا يمكن رفض هذا الطلب في حالته الحالية.');
      return;
    }
    const reason = window.prompt(`أدخل سبب رفض الطلب #${order.id} (سيظهر للعميل):`);
    if (reason === null) return;
    if (!reason.trim()) {
      window.alert('يجب كتابة سبب واضح لرفض الطلب.');
      return;
    }
    const modalRef = this.modalService.open(DeleteModalComponent);
    modalRef.componentInstance.title = `رفض الطلب #${order.id}؟`;
    modalRef.componentInstance.confirmationText = `سيتم رفض الطلب وإلغاء حجز المواد وإشعار العميل بالسبب: "${reason.trim()}"`;
    modalRef.componentInstance.deletingText = 'جاري رفض الطلب…';
    modalRef.componentInstance.confirmLabel = 'تأكيد الرفض';
    this.subs.sink = modalRef.componentInstance.cancelClicked.subscribe(() => modalRef.dismiss());
    this.subs.sink = modalRef.componentInstance.deleteClicked.subscribe(() => {
      if (modalRef.componentInstance.isLoading) return;
      modalRef.componentInstance.isLoading = true;
      this.ordersService.reject(order.id, reason.trim()).subscribe({
        next: () => {
          modalRef.close();
          this.ordersService.fetchPost();
        },
        error: (err: any) => {
          modalRef.componentInstance.isLoading = false;
          window.alert(err?.error?.title || err?.error?.detail || err?.message || 'تعذر رفض الطلب.');
        }
      });
    });
  }

  canReject(order: Order): boolean {
    return this.canCancel(order);
  }

  startPreparing(order: Order): void {
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'order';
    modalRef.componentInstance.actionLabel = 'بدء التجهيز';
    modalRef.componentInstance.description = `نقل الطلب #${order.id} إلى مرحلة التجهيز؟`;
    modalRef.componentInstance.action = () => this.ordersService.preparing(order.id);
    modalRef.result.then(() => this.ordersService.fetchPost(), () => {});
  }

  canPrepare(order: Order): boolean {
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    return order.orderDetails.some(d => d.orderDetailStatus === OrderDetailStatus.Pending);
  }

  canMarkReady(order: Order): boolean {
    if (order.canAdminMarkReady === true) return true;
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    return order.orderDetails.some(d => d.orderDetailStatus === OrderDetailStatus.MerchantAccepted);
  }

  markReady(order: Order): void {
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'order';
    modalRef.componentInstance.actionLabel = 'جاهز للاستلام';
    modalRef.componentInstance.description = `تأكيد جاهزية الطلب #${order.id} للاستلام من قبل مندوب التوصيل؟`;
    modalRef.componentInstance.action = () => this.ordersService.ready(order.id);
    modalRef.result.then(() => this.ordersService.fetchPost(), () => {});
  }

  confirmPickup(order: Order): void {
    if (!this.hasAssignedDriver(order)) {
      window.alert('يجب تعيين مندوب توصيل أولاً قبل تأكيد الاستلام وبدء التوصيل.');
      return;
    }
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'order';
    modalRef.componentInstance.actionLabel = 'تأكيد استلام المندوب';
    modalRef.componentInstance.description = `تأكيد استلام المندوب (${this.getCleanDriverName(order.deliveryUser)}) للطلب #${order.id} وبدء الشحن إلى العميل؟`;
    modalRef.componentInstance.action = () => this.ordersService.confirmPickup(order.id);
    modalRef.result.then(() => this.ordersService.fetchPost(), () => {});
  }

  canConfirmPickup(order: Order): boolean {
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    const active = order.orderDetails.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);
    return active.length > 0 && active.some(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup);
  }

  openDeliverModal(order: Order): void {
    const modalRef = this.modalService.open(AdminDeliverModalComponent, { size: 'lg' });
    modalRef.componentInstance.order = order;
    modalRef.result.then(
      () => this.ordersService.fetchPost(),
      () => {}
    );
  }

  canDeliver(order: Order): boolean {
    if (!order || !order.orderDetails || !order.orderDetails.length) return false;
    const active = order.orderDetails.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);
    if (active.length === 0) return false;
    if (active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered)) return false;
    return active.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted || d.orderDetailStatus === OrderDetailStatus.ReadyForPickup);
  }

  openHistoryModal(order: Order): void {
    const modalRef = this.modalService.open(OrderStatusHistoryModalComponent, { size: 'lg', scrollable: true });
    modalRef.componentInstance.order = order;
  }

  bulkCancel(items: Order[]): void {
    const selected = this.selection.selectedItems(items);
    const cancelable = selected.filter(o => this.canCancel(o));
    if (!cancelable.length) {
      window.alert('لا توجد طلبات قابلة للإلغاء من بين الطلبات المحددة.');
      return;
    }
    const reason = window.prompt(`أدخل سبب رفض/إلغاء الطلبات المحددة (${cancelable.length}):`);
    if (reason === null) return;
    if (!reason.trim()) {
      window.alert('يرجى كتابة سبب واضح للرفض أو الإلغاء.');
      return;
    }
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = cancelable.length;
    modalRef.componentInstance.itemLabel = cancelable.length === 1 ? 'order' : 'orders';
    modalRef.componentInstance.actionLabel = 'Cancel';
    modalRef.componentInstance.description = 'This stops fulfillment for every selected cancelable order. This action cannot be undone.';
    modalRef.componentInstance.action = () => forkJoin(cancelable.map((item) => this.ordersService.cancel(item.id, reason.trim())));
    modalRef.result.then(() => { this.selection.clear(); this.ordersService.fetchPost(); }, () => {});
  }

  edit(item: Order) {
    const modalRef = this.modalService.open(EditDilevry, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.ordersService.fetchPost(),
      () => { }
    );
  }

  openLiveTrack(item: Order) {
    const modalRef = this.modalService.open(LiveTrackModalComponent, {
      size: 'xl',
      scrollable: true
    });
    modalRef.componentInstance.order = item;
  }
  ngOnInit(): void {
    this.ordersService.setDefaults();
    this.searchForm();
    this.ordersService.fetchPost();
    this.subs.sink = interval(5000).subscribe(() => this.ordersService.fetchPost());
    this.subs.sink = this.ordersService.isLoading$.subscribe(res => this.isLoading = res);
    this.subs.sink = this.ordersService.items$.subscribe(() => this.notificationSummaryService.refresh());
    this.sorting = this.ordersService.sorting;
    this.paginator = this.ordersService.paginator;
  }
  isDeliveryEditable(order: Order): boolean {
    if (!order || !order.orderDetails || order.orderDetails.length === 0) return false;
    const active = order.orderDetails.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected &&
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled);
    return active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup);
  }

  getCleanDriverName(name?: string): string {
    if (!name || name.trim() === '' || name.includes('?')) {
      return 'Unassigned';
    }
    return name;
  }

  hasAssignedDriver(order: Order): boolean {
    const name = order.deliveryUser;
    return !!order.deliveryId && !!name && !name.includes('?');
  }

  canLiveTrack(order: Order): boolean {
    return this.hasAssignedDriver(order) || (order.orderDetails && order.orderDetails.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted || d.orderDetailStatus === OrderDetailStatus.MerchantAccepted));
  }

  formatPhoneNumber(phone?: string): string {
    if (!phone) return '-';
    let clean = phone.trim();
    if (!clean.startsWith('+')) {
      clean = '+' + clean;
    }
    if (clean.startsWith('+963') && clean.length >= 12) {
      return `${clean.slice(0, 4)} ${clean.slice(4, 7)} ${clean.slice(7, 10)} ${clean.slice(10)}`;
    }
    return clean;
  }

  getStatusDotClass(status: number): string {
    switch (status) {
      case OrderDetailStatus.Pending: return 'ops-dot-amber';
      case OrderDetailStatus.MerchantAccepted: return 'ops-dot-blue';
      case OrderDetailStatus.ShippingStarted: return 'ops-dot-indigo';
      case OrderDetailStatus.Delivered: return 'ops-dot-green';
      case OrderDetailStatus.MerchantRejected: return 'ops-dot-rose';
      case OrderDetailStatus.CustomerPending: return 'ops-dot-amber';
      case OrderDetailStatus.CustomerCanceled:
      case OrderDetailStatus.DeliveryCanceled: return 'ops-dot-rose';
      case OrderDetailStatus.ReadyForPickup: return 'ops-dot-blue';
      default: return 'ops-dot-muted';
    }
  }

  getStatusBadgeClass(status: number): string {
    switch (status) {
      case OrderDetailStatus.Pending: return 'badge-light-warning text-warning border border-warning';
      case OrderDetailStatus.MerchantAccepted: return 'badge-light-primary text-primary border border-primary';
      case OrderDetailStatus.ShippingStarted: return 'badge-light-info text-info border border-info';
      case OrderDetailStatus.Delivered: return 'badge-light-success text-success border border-success';
      case OrderDetailStatus.MerchantRejected: return 'badge-light-danger text-danger border border-danger';
      case OrderDetailStatus.CustomerPending: return 'badge-light-warning text-warning border border-warning';
      case OrderDetailStatus.CustomerCanceled:
      case OrderDetailStatus.DeliveryCanceled: return 'badge-light-danger text-danger border border-danger';
      case OrderDetailStatus.ReadyForPickup: return 'badge-light-primary text-primary border border-primary';
      default: return 'badge-light-secondary text-muted';
    }
  }

  getStatusLabel(status: number): string {
    const isAr = (this.translate.currentLang || localStorage.getItem('language') || 'ar') === 'ar';
    switch (status) {
      case OrderDetailStatus.Pending: return isAr ? 'قيد الانتظار' : 'Pending';
      case OrderDetailStatus.MerchantAccepted: return isAr ? 'مقبول / جاهز' : 'Accepted / Ready';
      case OrderDetailStatus.ShippingStarted: return isAr ? 'جاري التوصيل' : 'In Transit';
      case OrderDetailStatus.Delivered: return isAr ? 'تم التسليم' : 'Delivered';
      case OrderDetailStatus.MerchantRejected: return isAr ? 'مرفوض من التاجر' : 'Rejected by Merchant';
      case OrderDetailStatus.CustomerPending: return isAr ? 'بانتظار العميل' : 'Customer Pending';
      case OrderDetailStatus.CustomerCanceled: return isAr ? 'ملغي من العميل' : 'Canceled by Customer';
      case OrderDetailStatus.DeliveryCanceled: return isAr ? 'ملغي من السائق' : 'Canceled by Driver';
      case OrderDetailStatus.ReadyForPickup: return isAr ? 'جاهز للاستلام' : 'Ready for Pickup';
      default: return isAr ? 'غير محدد' : 'Unknown';
    }
  }

  getOrderOverallStatus(order: Order): { label: string; badgeClass: string; icon: string } {
    const isAr = (this.translate.currentLang || localStorage.getItem('language') || 'ar') === 'ar';
    if (!order || !order.orderDetails || order.orderDetails.length === 0) {
      return { label: isAr ? 'طلب جديد' : 'New Order', badgeClass: 'badge-light-warning text-warning', icon: 'fa-clock' };
    }

    const items = order.orderDetails;
    const allTerminal = items.every(d =>
      d.orderDetailStatus === OrderDetailStatus.CustomerCanceled ||
      d.orderDetailStatus === OrderDetailStatus.DeliveryCanceled ||
      d.orderDetailStatus === OrderDetailStatus.MerchantRejected);

    if (allTerminal) {
      if (items.some(d => d.orderDetailStatus === OrderDetailStatus.MerchantRejected)) {
        return { label: isAr ? 'مرفوض من التاجر' : 'Rejected by Merchant', badgeClass: 'badge-light-danger text-danger', icon: 'fa-ban' };
      }
      return { label: isAr ? 'ملغي' : 'Canceled', badgeClass: 'badge-light-danger text-danger', icon: 'fa-ban' };
    }

    const active = items.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);

    if (active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered)) {
      return { label: isAr ? 'مكتمل' : 'Delivered', badgeClass: 'badge-light-success text-success', icon: 'fa-check-double' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted)) {
      return { label: isAr ? 'جاري التوصيل' : 'In Transit', badgeClass: 'badge-light-info text-info', icon: 'fa-motorcycle' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup)) {
      return { label: isAr ? 'جاهز للتوصيل' : 'Ready', badgeClass: 'badge-light-primary text-primary', icon: 'fa-box-open' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.MerchantAccepted)) {
      return { label: isAr ? 'جاري التجهيز' : 'Preparing', badgeClass: 'badge-light-info text-info', icon: 'fa-utensils' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.Pending || d.orderDetailStatus === OrderDetailStatus.CustomerPending)) {
      return { label: isAr ? 'قيد الانتظار' : 'Pending', badgeClass: 'badge-light-warning text-warning', icon: 'fa-hourglass-half' };
    }
    return { label: isAr ? 'قيد المعالجة' : 'Processing', badgeClass: 'badge-light-primary text-primary', icon: 'fa-spinner' };
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
