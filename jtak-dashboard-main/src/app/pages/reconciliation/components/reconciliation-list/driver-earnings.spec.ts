import { of } from 'rxjs';
import { ReconciliationListComponent } from './reconciliation-list.component';
import { ReconciliationService } from '../../services/reconciliation.service';
import { SettlementPartyType, SettlementRequestItem, SettlementRequestStatus } from '../../models/reconciliation.model';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

const request = (partyType: SettlementPartyType, status = SettlementRequestStatus.Pending): SettlementRequestItem => ({
  id: 'qa-earnings', requestNumber: 'QA', partyType, status, requestedByUserId: 'qa-driver',
  requestedByName: 'QA Driver', amount: 25.5, currency: 'SYP', createdDate: '2026-09-30', merchantAllocations: [],
});

describe('Driver earnings admin workflow', () => {
  let component: ReconciliationListComponent;
  let service: jasmine.SpyObj<ReconciliationService>;
  beforeEach(() => {
    service = jasmine.createSpyObj('ReconciliationService', ['acceptRequest', 'rejectRequest', 'completeDriverEarningsRequest', 'completeMerchantRequest']);
    service.acceptRequest.and.returnValue(of(request(SettlementPartyType.CaptainEarnings, SettlementRequestStatus.Approved)));
    service.completeDriverEarningsRequest.and.returnValue(of(request(SettlementPartyType.CaptainEarnings, SettlementRequestStatus.Completed)));
    component = new ReconciliationListComponent(service, {} as any, { detectChanges: () => {} } as any, {} as any);
    spyOn<any>(component, 'finishRequestAction').and.stub();
    spyOn(window, 'confirm').and.returnValue(true);
  });

  it('keeps cash custody, merchant payouts and driver earnings in separate queues', () => {
    component.settlementRequests = [request(SettlementPartyType.Captain), request(SettlementPartyType.Merchant), request(SettlementPartyType.CaptainEarnings)];
    expect(component.courierRequests.length).toBe(1);
    expect(component.driverEarningsRequests.length).toBe(1);
    expect(component.merchantRequests.length).toBe(1);
    expect(component.pendingCourierRequestsCount).toBe(2);
  });

  it('approval explicitly reserves earnings without calling the payout endpoint', () => {
    component.acceptSettlementRequest(request(SettlementPartyType.CaptainEarnings));
    expect(window.confirm).toHaveBeenCalledWith(jasmine.stringMatching('لن يُخصم إلا بعد تأكيد دفعه فعلياً'));
    expect(service.acceptRequest).toHaveBeenCalledWith('qa-earnings');
    expect(service.completeDriverEarningsRequest).not.toHaveBeenCalled();
    expect(service.completeMerchantRequest).not.toHaveBeenCalled();
  });

  it('actual earnings payment uses the driver endpoint and cannot be double-clicked', () => {
    component.completeDriverEarnings(request(SettlementPartyType.CaptainEarnings, SettlementRequestStatus.Approved));
    component.completeDriverEarnings(request(SettlementPartyType.CaptainEarnings, SettlementRequestStatus.Approved));
    expect(service.completeDriverEarningsRequest).toHaveBeenCalledTimes(1);
    expect(service.completeMerchantRequest).not.toHaveBeenCalled();
    expect(window.confirm).toHaveBeenCalledWith(jasmine.stringMatching('دون تغيير عهدته النقدية'));
  });

  it('canceling the physical-payment confirmation does not move money', () => {
    (window.confirm as jasmine.Spy).and.returnValue(false);
    component.completeDriverEarnings(request(SettlementPartyType.CaptainEarnings, SettlementRequestStatus.Approved));
    expect(service.completeDriverEarningsRequest).not.toHaveBeenCalled();
  });
});

describe('Driver earnings API routing', () => {
  let http: HttpTestingController;
  let service: ReconciliationService;
  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule], providers: [ReconciliationService] });
    http = TestBed.inject(HttpTestingController); service = TestBed.inject(ReconciliationService);
  });
  afterEach(() => http.verify());
  it('posts actual driver payout only to CompleteDriverEarnings, not merchant/custody routes', () => {
    service.completeDriverEarningsRequest('qa-id').subscribe();
    const call = http.expectOne(r => r.url.endsWith('/Admin/SettlementRequests/qa-id/CompleteDriverEarnings'));
    expect(call.request.method).toBe('POST'); call.flush({});
  });
});
