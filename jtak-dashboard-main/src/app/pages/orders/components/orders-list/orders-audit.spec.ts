import { UntypedFormBuilder } from '@angular/forms';
import { of, Subject, throwError } from 'rxjs';
import { OrdersListComponent } from './orders-list.component';
import { EditDilevry } from './EditDilevry/edit-dilevry.component';
import { AdminDeliverModalComponent } from './AdminDeliverModal/admin-deliver-modal.component';
import { CancelOrderModalComponent } from './CancelOrderModal/cancel-order-modal.component';
import { LiveTrackModalComponent } from './LiveTrackModal/live-track-modal.component';
import { OrderDetailsModalComponent } from './OrderDetailsModal/order-details-modal.component';
import { OrderStatusHistoryModalComponent } from './OrderStatusHistoryModal/order-status-history-modal.component';
import { Order } from '../../models/orders.model';
import { OrderDetailStatus } from '../../models/order-status.enum';

const order = (status = OrderDetailStatus.Pending, fields: Partial<Order> = {}): Order => ({
  id: 16, price: 150.5, deliveryFee: 100, paymentMethod: 0,
  orderDetails: [{ id: 1, quantity: 1, orderDetailStatus: status }], ...fields
} as Order);

describe('All order modals and available actions', () => {
  const modal = () => jasmine.createSpyObj('modal', ['close', 'dismiss']);
  it('respects false API permission flags for merchant decision and ready buttons', () => {
    const list = new OrdersListComponent(new UntypedFormBuilder(), {} as any, {} as any, {} as any, {} as any, {} as any);
    expect(list.canApprove(order(OrderDetailStatus.Pending, { canAdminApprove: false }))).toBeFalse();
    expect(list.canPrepare(order(OrderDetailStatus.Pending, { requiresMerchantDecision: true }))).toBeFalse();
    expect(list.canMarkReady(order(OrderDetailStatus.MerchantAccepted, { canAdminMarkReady: false }))).toBeFalse();
    expect(list.canApprove(order(OrderDetailStatus.Pending, { canAdminApprove: true }))).toBeTrue();
  });
  it('hides state changes for archived and completed orders', () => {
    const list = new OrdersListComponent(new UntypedFormBuilder(), {} as any, {} as any, {} as any, {} as any, {} as any);
    for (const item of [order(OrderDetailStatus.MerchantAccepted, { isArchived: true }), order(OrderDetailStatus.ReadyForPickup, { deliveredAt: '2026-10-03' })]) {
      expect(list.canCancel(item)).toBeFalse(); expect(list.canMarkReady(item)).toBeFalse();
      expect(list.canDeliver(item)).toBeFalse(); expect(list.canConfirmPickup(item)).toBeFalse();
      expect(list.isDeliveryEditable(item)).toBeFalse(); expect(list.canLiveTrack(item)).toBeFalse();
    }
  });
  it('does not offer whole-order cancellation after any line has been delivered', () => {
    const list = new OrdersListComponent(new UntypedFormBuilder(), {} as any, {} as any, {} as any, {} as any, {} as any);
    const item = order(); item.orderDetails.push({ orderDetailStatus: OrderDetailStatus.Delivered } as any);
    expect(list.canCancel(item)).toBeFalse();
    expect(list.canConfirmPickup(order(OrderDetailStatus.ReadyForPickup))).toBeFalse();
    expect(list.canConfirmPickup(order(OrderDetailStatus.ReadyForPickup, { deliveryId: 'driver' }))).toBeTrue();
  });
  it('allows assignment only before pickup and archive only for terminal orders', () => {
    const list = new OrdersListComponent(new UntypedFormBuilder(), {} as any, {} as any, {} as any, {} as any, {} as any);
    expect(list.canAssignDriver(order(OrderDetailStatus.ShippingStarted))).toBeFalse();
    expect(list.canAssignDriver(order(OrderDetailStatus.MerchantAccepted))).toBeTrue();
    expect(list.canArchive(order(OrderDetailStatus.Pending))).toBeFalse();
    expect(list.canArchive(order(OrderDetailStatus.Delivered))).toBeTrue();
  });
  it('assignment saves once, keeps errors visible and permits retry', () => {
    const response = new Subject<boolean>();
    const api = jasmine.createSpyObj('orders', ['setDelievry']); api.setDelievry.and.returnValue(response);
    const toast = jasmine.createSpyObj('toast', ['success', 'error']);
    const edit = new EditDilevry({} as any, new UntypedFormBuilder(), modal(), toast, api, {} as any);
    edit.item = order(OrderDetailStatus.MerchantAccepted, { deliveryId: 'driver' }); edit.loadForm();
    edit.saved(); edit.saved(); expect(api.setDelievry).toHaveBeenCalledTimes(1);
    response.error({ error: { errors: ['المندوب غير متصل'] } });
    expect(toast.error).toHaveBeenCalledWith('المندوب غير متصل'); expect(edit.isSaving).toBeFalse();
    edit.ngOnDestroy();
  });
  it('never interprets an empty driver ID as a cash-custody account', () => {
    const component = new AdminDeliverModalComponent(modal(), {} as any);
    component.order = order(OrderDetailStatus.ReadyForPickup, { deliveryId: '00000000-0000-0000-0000-000000000000' });
    component.ngOnInit(); expect(component.hasAssignedDriver()).toBeFalse();
    expect(component.cashResolutionMode).toBe('CompanyCash');
  });
  it('requires a four-digit PIN or an administrative reason and prevents double delivery', () => {
    const pending = new Subject<boolean>(); const api = jasmine.createSpyObj('orders', ['deliver']); api.deliver.and.returnValue(pending);
    const component = new AdminDeliverModalComponent(modal(), api); component.order = order();
    component.submit(); expect(api.deliver).not.toHaveBeenCalled();
    component.otp = '123'; component.submit(); expect(api.deliver).not.toHaveBeenCalled();
    component.otp = '1234'; component.submit(); component.submit(); expect(api.deliver).toHaveBeenCalledTimes(1);
    pending.next(true); pending.complete(); expect(component.modal.close).toHaveBeenCalledWith(true);
  });
  it('reports partial bulk cancellation and retries only failed orders', () => {
    const api = jasmine.createSpyObj('orders', ['cancel']);
    api.cancel.and.callFake((id: number) => id === 1 ? of(true) : throwError(() => ({ error: { errors: ['تم التسليم مسبقاً'] } })));
    const component = new CancelOrderModalComponent(modal(), api);
    component.orders = [order(undefined, { id: 1 }), order(undefined, { id: 2 })]; component.reason = 'طلب العميل';
    const updated = jasmine.createSpy('updated'); component.updated.subscribe(updated);
    component.confirm(); expect(updated).toHaveBeenCalledTimes(1); expect(component.orders.map(x => x.id)).toEqual([2]);
    expect(component.errorMessage).toContain('#2'); expect(component.errorMessage).toContain('تم التسليم مسبقاً');
    api.cancel.calls.reset(); api.cancel.and.returnValue(of(true)); component.confirm();
    expect(api.cancel).toHaveBeenCalledOnceWith(2, 'طلب العميل'); expect(component.modal.close).toHaveBeenCalledWith(true);
  });
  it('preserves fractional authoritative totals in details and delivery modals', () => {
    const item = order(undefined, { grandTotal: 1683.5 });
    const details = new OrderDetailsModalComponent(modal()); details.order = item;
    expect(details.getGrandTotal()).toBe(1683.5); expect(details.getCashToCollect()).toBe(1683.5);
    item.paymentMethod = 1; expect(details.getCashToCollect()).toBe(0);
  });
  it('history handles plain-text and JSON details without crashing', () => {
    const history = new OrderStatusHistoryModalComponent(modal(), {} as any, { instant: (key: string) => key } as any);
    expect(history.getDetailsView({ id: 1, details: 'سبب الإلغاء' } as any)?.note).toBe('سبب الإلغاء');
    const view = history.getDetailsView({ id: 2, details: '[{"ProductTitle":"منتج","Quantity":2,"TotalPrice":30.5}]' } as any);
    expect(view?.total).toBe(30.5); expect(view?.items[0].quantity).toBe(2);
  });
  it('cancels live HTTP work when the tracking dialog is closed', () => {
    const response = new Subject<any>(); const api = { getLiveTrack: () => response };
    const track = new LiveTrackModalComponent(modal(), api as any, { untrackOrder: jasmine.createSpy() } as any, { detectChanges: jasmine.createSpy() } as any);
    track.order = order(); track.fetchTelemetry(); expect(response.observed).toBeTrue();
    track.ngOnDestroy(); expect(response.observed).toBeFalse();
  });
});
