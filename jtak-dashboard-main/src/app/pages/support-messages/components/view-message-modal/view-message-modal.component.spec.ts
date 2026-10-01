import { fakeAsync, tick } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';
import { ErrandStatus, SupportMessage, SupportMessageStatus } from '../../models/support-message.model';
import { ViewMessageModalComponent } from './view-message-modal.component';

describe('Purchase-request admin handoffs', () => {
  let service: any;
  let toast: any;
  let component: ViewMessageModalComponent;
  let files: any;

  beforeEach(() => {
    service = jasmine.createSpyObj('SupportMessagesService', [
      'getMessage', 'getErrandDrivers', 'getErrandDriverEarning', 'assignErrand', 'quoteErrand',
    ]);
    service.getErrandDrivers.and.returnValue(of([]));
    service.getErrandDriverEarning.and.returnValue(of({ amount: 75 }));
    toast = jasmine.createSpyObj('ToastrService', ['success', 'error']);
    files = jasmine.createSpyObj('FilesService', ['getErrandReceipt']);
    component = new ViewMessageModalComponent({} as any, service, toast, files);
    component.message = {
      id: 16, status: SupportMessageStatus.New, errandStatus: ErrandStatus.Quoted,
      errandItemPrice: 50, errandDeliveryFee: 10,
    } as SupportMessage;
  });

  afterEach(() => component.ngOnDestroy());

  it('requires explicit company subsidy approval and sends that approval with the quote', () => {
    component.ngOnInit();
    component.itemPrice = 50;
    component.deliveryFee = 10;
    expect(component.proposedDriverSubsidy).toBe(65);
    component.runErrandAction('quote');
    expect(service.quoteErrand).not.toHaveBeenCalled();
    component.acceptDriverSubsidy = true;
    service.quoteErrand.and.returnValue(of({}));
    service.getMessage.and.returnValue(of({ ...component.message }));
    component.runErrandAction('quote');
    expect(service.quoteErrand).toHaveBeenCalledOnceWith(16, 50, 10, true);
  });

  it('reports the company loss without adding courier pay to the customer total', () => {
    component.message.errandStatus = ErrandStatus.Delivered;
    component.message.errandPurchaseCost = 30;
    component.message.errandDriverEarning = 75;
    expect(component.errandTotal).toBe(60);
    expect(component.recordedOrderProfit).toBe(-45);
    component.message.errandStatus = ErrandStatus.Assigned;
    expect(component.recordedOrderProfit).toBeNull();
  });

  it('loads the receipt through authenticated HTTP and revokes the local image on close', () => {
    const blob = new Blob(['receipt'], { type: 'image/jpeg' });
    files.getErrandReceipt.and.returnValue(of(blob));
    const create = spyOn(URL, 'createObjectURL').and.returnValue('blob:private-receipt');
    const revoke = spyOn(URL, 'revokeObjectURL');
    component.message.errandReceiptPhotoToken = 'private-token.jpg';
    component.ngOnInit();
    expect(files.getErrandReceipt).toHaveBeenCalledOnceWith(16);
    expect(create).toHaveBeenCalledWith(blob);
    expect(component.receiptPhotoUrl).toBe('blob:private-receipt');
    service.getMessage.and.returnValue(of({ ...component.message }));
    component.refreshErrand();
    expect(files.getErrandReceipt).toHaveBeenCalledTimes(1);
    component.ngOnDestroy();
    expect(revoke).toHaveBeenCalledWith('blob:private-receipt');
  });

  it('shows a protected receipt failure without falling back to a public link', () => {
    files.getErrandReceipt.and.returnValue(throwError(() => ({ status: 403 })));
    component.message.errandReceiptPhotoToken = 'private-token.jpg';
    component.ngOnInit();
    expect(component.receiptPhotoUrl).toBeNull();
    expect(component.receiptPhotoError).toBeTrue();
  });

  it('cancels a stale image request when the receipt changes', () => {
    const oldPhoto = new Subject<Blob>();
    files.getErrandReceipt.and.returnValue(oldPhoto);
    component.message.errandReceiptPhotoToken = 'old.jpg';
    component.ngOnInit();
    files.getErrandReceipt.and.returnValue(of(new Blob(['new receipt'])));
    const create = spyOn(URL, 'createObjectURL').and.returnValue('blob:new-receipt');
    service.getMessage.and.returnValue(of({ ...component.message, errandReceiptPhotoToken: 'new.jpg' }));
    component.refreshErrand();
    oldPhoto.next(new Blob(['old receipt']));
    expect(create).toHaveBeenCalledTimes(1);
    expect(component.receiptPhotoUrl).toBe('blob:new-receipt');
  });

  it('shows customer approval while the admin keeps the dialog open', fakeAsync(() => {
    service.getMessage.and.returnValue(of({ ...component.message, errandStatus: ErrandStatus.Approved }));
    component.ngOnInit();
    tick(10000);
    expect(component.message.errandStatus).toBe(ErrandStatus.Approved);
    expect(component.errandTotal).toBe(60);
    component.ngOnDestroy();
    tick(10000);
    expect(service.getMessage).toHaveBeenCalledTimes(1);
  }));

  it('preserves receipt drafts during polling', fakeAsync(() => {
    component.message.errandStatus = ErrandStatus.Assigned;
    service.getMessage.and.returnValue(of({ ...component.message }));
    component.ngOnInit();
    component.purchaseCost = 45;
    component.receiptReference = 'R-16';
    tick(10000);
    expect(component.purchaseCost).toBe(45);
    expect(component.receiptReference).toBe('R-16');
    component.ngOnDestroy();
  }));

  it('explains an assignment rejection from the server', () => {
    component.driverUserId = 'driver';
    service.assignErrand.and.returnValue(throwError(() => ({
      error: { errors: ['رصيد عهدة المندوب المتاح لا يكفي لشراء الغرض.'] },
    })));
    component.runErrandAction('assign');
    expect(toast.error).toHaveBeenCalledWith('رصيد عهدة المندوب المتاح لا يكفي لشراء الغرض.');
    expect(component.isSaving).toBeFalse();
  });

  it('does not let an older poll overwrite a completed assignment', fakeAsync(() => {
    const previous = { ...component.message, errandStatus: ErrandStatus.Approved };
    const pending = new Subject<SupportMessage>();
    service.getMessage.and.returnValue(pending);
    component.ngOnInit();
    tick(10000);
    service.getMessage.and.returnValue(of({ ...previous, errandStatus: ErrandStatus.Assigned }));
    service.assignErrand.and.returnValue(of({}));
    component.driverUserId = 'driver';
    component.runErrandAction('assign');
    pending.next(previous);
    expect(component.message.errandStatus).toBe(ErrandStatus.Assigned);
    expect(component.isRefreshingErrand).toBeFalse();
    component.ngOnDestroy();
  }));
});
