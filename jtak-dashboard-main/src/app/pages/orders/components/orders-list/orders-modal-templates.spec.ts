import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { TranslateModule } from '@ngx-translate/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { of, Subject, throwError } from 'rxjs';
import { OrdersModule } from '../../orders.module';
import { OrdersService } from '../../services/orders.service';
import { UsersService } from 'src/app/pages/users/services/users.service';
import { SignalrTrackingService } from '../../services/signalr-tracking.service';
import { EditDilevry } from './EditDilevry/edit-dilevry.component';
import { AdminDeliverModalComponent } from './AdminDeliverModal/admin-deliver-modal.component';
import { CancelOrderModalComponent } from './CancelOrderModal/cancel-order-modal.component';
import { OrderDetailsModalComponent } from './OrderDetailsModal/order-details-modal.component';
import { OrderStatusHistoryModalComponent } from './OrderStatusHistoryModal/order-status-history-modal.component';
import { LiveTrackModalComponent } from './LiveTrackModal/live-track-modal.component';
import { SupportMessagesModule } from 'src/app/pages/support-messages/support-messages.module';
import { SupportMessagesService } from 'src/app/pages/support-messages/services/support-messages.service';
import { ViewMessageModalComponent } from 'src/app/pages/support-messages/components/view-message-modal/view-message-modal.component';
import { OrdersListComponent } from './orders-list.component';
import { SupportMessagesListComponent } from 'src/app/pages/support-messages/components/support-messages-list/support-messages-list.component';
import { ErrandRequestsListComponent } from 'src/app/pages/support-messages/components/errand-requests-list/errand-requests-list.component';
import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';
import { PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { DeleteModalComponent } from 'src/app/modules/shared/components/delete-modal/delete-modal.component';

describe('Orders and customer service actual modal templates', () => {
  const item: any = { id: 16, user: 'Client', paymentMethod: 0, price: 1870, deliveryFee: 84, grandTotal: 1954,
    orderDetails: [{ id: 1, productTitle: 'Product', quantity: 2, singleFinalPrice: 935, orderDetailStatus: 1 }] };
  let orders: any; let users: any; let support: any;
  beforeEach(async () => {
    orders = jasmine.createSpyObj('orders', ['getHistory', 'getLiveTrack', 'adminCancel', 'adminDeliver', 'setDelievry', 'setDefaults', 'fetchPost', 'patchState', 'getSummary']);
    Object.assign(orders, { items$: of([item]), listError$: of(''), isLoading$: of(false), paginator: new PaginatorState(), sorting: new SortState('id') });
    orders.getSummary.and.returnValue(of({ total: 1 }));
    orders.getHistory.and.returnValue(of([])); orders.getLiveTrack.and.returnValue(throwError(() => new Error('offline')));
    users = { isLoading$: of(false), getDeliveries: () => of([]) };
    support = jasmine.createSpyObj('support', ['getMessage', 'updateStatus', 'getErrandDrivers', 'getErrandDriverEarning', 'setDefaults', 'fetchPost', 'patchState', 'getStats', 'getErrandQueue', 'getErrandStats']);
    Object.assign(support, { items$: of([]), listError$: of(''), isLoading$: of(false), paginator: new PaginatorState(), sorting: new SortState('id') });
    support.getStats.and.returnValue(of({ totalCount: 0 })); support.getErrandStats.and.returnValue(of({ active: 0 }));
    support.getErrandQueue.and.returnValue(of({ items: [], totalCount: 0 }));
    support.getMessage.and.returnValue(of({ id: 1, status: 1, message: 'Help', subject: 'Subject', createdDate: '2026-10-03' }));
    support.getErrandDrivers.and.returnValue(of([])); support.getErrandDriverEarning.and.returnValue(of({ amount: 75 }));
    await TestBed.configureTestingModule({
      imports: [OrdersModule, SupportMessagesModule, HttpClientTestingModule, RouterTestingModule, TranslateModule.forRoot()],
      providers: [
        { provide: OrdersService, useValue: orders }, { provide: UsersService, useValue: users },
        { provide: SupportMessagesService, useValue: support },
        { provide: NotificationSummaryService, useValue: { refresh: () => {} } },
        { provide: NgbActiveModal, useValue: jasmine.createSpyObj('modal', ['close', 'dismiss']) },
        { provide: ToastrService, useValue: jasmine.createSpyObj('toast', ['success', 'error']) },
        { provide: SignalrTrackingService, useValue: { trackOrder: () => {}, untrackOrder: () => {}, locationUpdated$: new Subject(), connectionState$: of('disconnected') } }
      ]
    }).compileComponents();
  });
  it('orders page renders rows and updates the selected server filter', () => {
    const f = TestBed.createComponent(OrdersListComponent); f.detectChanges();
    expect(f.nativeElement.textContent).toContain('Client');
    f.componentInstance.setActiveTab('UNASSIGNED');
    expect(orders.patchState.calls.mostRecent().args[0].filter.status).toBe('UNASSIGNED');
    expect(orders.paginator.page).toBe(0); f.destroy();
  });
  it('support page renders an empty list and applies status filtering', () => {
    const f = TestBed.createComponent(SupportMessagesListComponent); f.detectChanges();
    expect(support.fetchPost).toHaveBeenCalled(); f.componentInstance.filterByStatus(1);
    expect(support.patchState).toHaveBeenCalled(); f.destroy();
  });
  it('purchase queue renders empty and request failure states', fakeAsync(() => {
    const f = TestBed.createComponent(ErrandRequestsListComponent); f.detectChanges(); tick(0); f.detectChanges();
    expect(f.componentInstance.items.length).toBe(0); expect(f.componentInstance.loading).toBeFalse();
    support.getErrandQueue.and.returnValue(throwError(() => new Error('offline'))); f.componentInstance.load(); f.detectChanges();
    expect(f.componentInstance.error).toBeTrue(); f.destroy();
  }));
  it('shared confirmation modal prevents repeated submits and permits retry after error', () => {
    const pending = new Subject(); const f = TestBed.createComponent(BulkConfirmModalComponent);
    const action = jasmine.createSpy().and.returnValue(pending); f.componentInstance.action = action; f.detectChanges();
    f.componentInstance.confirm(); f.componentInstance.confirm(); expect(action).toHaveBeenCalledTimes(1);
    pending.error(new Error('offline')); f.detectChanges(); expect(f.componentInstance.hasError).toBeTrue();
    expect(f.componentInstance.isLoading).toBeFalse(); f.destroy();
  });
  it('shared delete modal blocks a second delete while busy', () => {
    const f = TestBed.createComponent(DeleteModalComponent); f.componentInstance.moduleName = 'order'; f.detectChanges();
    const deleted = jasmine.createSpy(); f.componentInstance.deleteClicked.subscribe(deleted);
    f.componentInstance.isLoading = true; f.componentInstance.onDeleteClicked(); expect(deleted).not.toHaveBeenCalled(); f.destroy();
  });
  it('assignment form renders and requires a driver before save', () => {
    const f = TestBed.createComponent(EditDilevry); f.componentInstance.item = item; f.detectChanges();
    expect(f.nativeElement.querySelector('ng-select')).not.toBeNull();
    expect(f.componentInstance.formGroup.invalid).toBeTrue(); f.destroy();
  });
  it('delivery modal renders fractional authoritative amount and busy state', () => {
    const f = TestBed.createComponent(AdminDeliverModalComponent); f.componentInstance.order = { ...item, grandTotal: 1954.5 };
    f.detectChanges(); expect(f.nativeElement.textContent).toContain('1,954.5');
    f.componentInstance.isLoading = true; f.detectChanges();
    expect(f.nativeElement.querySelector('button.btn-success').disabled).toBeTrue(); f.destroy();
  });
  it('cancellation modal requires a reason and displays failures', () => {
    const f = TestBed.createComponent(CancelOrderModalComponent); f.componentInstance.order = item; f.detectChanges();
    expect(f.componentInstance.canSubmit()).toBeFalse();
    f.componentInstance.errorMessage = 'تعذر الإلغاء'; f.detectChanges();
    expect(f.nativeElement.textContent).toContain('تعذر الإلغاء'); f.destroy();
  });
  it('details modal renders line items and total without making a mutation', () => {
    const f = TestBed.createComponent(OrderDetailsModalComponent); f.componentInstance.order = item; f.detectChanges();
    expect(f.nativeElement.textContent).toContain('Product'); expect(f.nativeElement.textContent).toContain('1,954'); f.destroy();
  });
  it('history modal renders empty and failed requests', () => {
    const f = TestBed.createComponent(OrderStatusHistoryModalComponent); f.componentInstance.order = item; f.detectChanges();
    expect(f.componentInstance.isLoading).toBeFalse(); f.destroy();
    orders.getHistory.and.returnValue(throwError(() => new Error('offline')));
    const failed = TestBed.createComponent(OrderStatusHistoryModalComponent); failed.componentInstance.order = item; failed.detectChanges();
    expect(failed.nativeElement.textContent).toContain('ORDERS_PAGE.HISTORY_ERROR'); failed.destroy();
  });
  it('tracking modal renders a retry action when telemetry fails', () => {
    const f = TestBed.createComponent(LiveTrackModalComponent); f.componentInstance.order = item; f.detectChanges();
    expect(f.nativeElement.textContent).toContain('تعذر تحديث');
    expect(f.nativeElement.textContent).toContain('إعادة المحاولة'); f.destroy();
  });
  it('support message loads fresh read status and locks save while loading', () => {
    const pending = new Subject<any>(); support.getMessage.and.returnValue(pending);
    const f = TestBed.createComponent(ViewMessageModalComponent); f.componentInstance.message = { id: 1, status: 0 } as any; f.detectChanges();
    expect(f.nativeElement.querySelector('.modal-btn-primary').disabled).toBeTrue();
    pending.next({ id: 1, status: 1, adminNotes: 'Fresh notes' }); pending.complete(); f.detectChanges();
    expect(f.componentInstance.selectedStatus).toBe(1); expect(f.componentInstance.adminNotes).toBe('Fresh notes');
    expect(f.nativeElement.querySelector('.modal-btn-primary').disabled).toBeFalse(); f.destroy();
  });
  it('errand modal renders each stage without support-status editing', () => {
    for (const status of [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]) {
      const f = TestBed.createComponent(ViewMessageModalComponent);
      f.componentInstance.message = { id: 1, status: 0, errandStatus: status, errandItemPrice: 1000, errandDeliveryFee: 200 } as any;
      f.detectChanges(); expect(f.nativeElement.querySelector('.modal-status-selector')).toBeNull(); f.destroy();
    }
  });
});
