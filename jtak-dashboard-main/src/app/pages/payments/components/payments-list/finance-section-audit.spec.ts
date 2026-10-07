import { TestBed } from '@angular/core/testing';
import { TemplateRef } from '@angular/core';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { locale as arLocale } from 'src/app/modules/i18n/vocabs/ar';
import { locale as enLocale } from 'src/app/modules/i18n/vocabs/en';
import { NgbActiveModal, NgbModal, NgbConfig } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';
import { PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { PaymentsModule } from '../../payments.module';
import { BillsModule } from '../../../bills/bills.module';
import { CaptainSettlementsModule } from '../../../captain-settlements/captain-settlements.module';
import { ReconciliationModule } from '../../../reconciliation/reconciliation.module';
import { paymentsService } from '../../services/payments.service';
import { BillsService } from '../../../bills/services/bills.service';
import { DeliveriesService } from '../../services/deliveries.service';
import { DriverCashAdvancesService } from '../../services/driver-cash-advances.service';
import { MerchantsService } from '../../../merchant/services/merchants.service';
import { CaptainSettlementService } from '../../../captain-settlements/services/captain-settlement.service';
import { ReconciliationService } from '../../../reconciliation/services/reconciliation.service';
import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';
import { PaymentsListComponent } from './payments-list.component';
import { BillsListComponent } from '../../../bills/components/bills-list/bills-list.component';
import { CaptainSettlementsListComponent } from '../../../captain-settlements/components/captain-settlements-list/captain-settlements-list.component';
import { ReconciliationListComponent } from '../../../reconciliation/components/reconciliation-list/reconciliation-list.component';
import { CreatePaymentModalComponent } from '../create-payment-modal/create-payment-modal.component';
import { DriverCashAdvanceModalComponent } from '../driver-cash-advance-modal/driver-cash-advance-modal.component';

describe('Finance sections, rendered pages and every modal',()=>{
  let pay:any,bills:any,advance:any,captain:any,reconciliation:any,modal:any;
  const table=()=>Object.assign(jasmine.createSpyObj('table',['setDefaults','fetchPost','patchState','create','availableBalances']),{
    summary$:new BehaviorSubject(null),items$:of([]),isLoading$:of(false),listError$:of(''),totalRecords$:of(0),paginator:new PaginatorState(),sorting:new SortState()});
  beforeEach(async()=>{
    pay=table();bills=table();pay.availableBalances.and.returnValue(of({driverAvailable:1000,merchantAvailable:900}));pay.create.and.returnValue(new Subject());
    advance=jasmine.createSpyObj('advance',['getOverview','create']);advance.getOverview.and.returnValue(of({companyVaultBalance:1000,drivers:[{id:'driver',fullName:'Driver',remainingCapacity:1000}],recentAdvances:[]}));advance.create.and.returnValue(new Subject());
    captain=jasmine.createSpyObj('captain',['getCaptains','getSummary','getCaptainOrders','getBatchReceipt','confirmSettlement']);
    captain.getCaptains.and.returnValue(of([]));captain.getSummary.and.returnValue(of({items:[],totalCashCollected:0,totalCaptainEarnings:0,netDueToCompany:0}));
    captain.getCaptainOrders.and.returnValue(new Subject());captain.getBatchReceipt.and.returnValue(new Subject());captain.confirmSettlement.and.returnValue(new Subject());
    reconciliation=jasmine.createSpyObj('reconciliation',['getMerchantSummary','getMerchantReconciliationDataTable','getCaptains','getSettlementHistoryDataTable','getSettlementRequests','getCaptainStatement','getMerchantStatement','getSettlementReceipt','settleShift']);
    reconciliation.getMerchantSummary.and.returnValue(of({}));reconciliation.getMerchantReconciliationDataTable.and.returnValue(of({items:[],totalRecords:0}));reconciliation.getCaptains.and.returnValue(of([]));reconciliation.getSettlementHistoryDataTable.and.returnValue(of({items:[],totalRecords:0,summary:{}}));reconciliation.getSettlementRequests.and.returnValue(of([]));reconciliation.settleShift.and.returnValue(new Subject());
    modal=jasmine.createSpyObj('activeModal',['close','dismiss']);
    await TestBed.configureTestingModule({imports:[HttpClientTestingModule,RouterTestingModule,TranslateModule.forRoot(),PaymentsModule,BillsModule,CaptainSettlementsModule,ReconciliationModule],providers:[
      {provide:paymentsService,useValue:pay},{provide:BillsService,useValue:bills},{provide:DriverCashAdvancesService,useValue:advance},{provide:CaptainSettlementService,useValue:captain},{provide:ReconciliationService,useValue:reconciliation},
      {provide:MerchantsService,useValue:{getAllMerchants:()=>of([{id:30,ownerId:'owner',title:'First'},{id:31,ownerId:'owner',title:'Second'}])}},
      {provide:DeliveriesService,useValue:{getDeliveries:()=>of([{id:'driver',fullName:'Driver'}])}},
      {provide:NgbActiveModal,useValue:modal},{provide:ToastrService,useValue:jasmine.createSpyObj('toast',['success','error','warning'])},{provide:NotificationSummaryService,useValue:{refresh:()=>{}}}
    ]}).compileComponents();TestBed.inject(NgbConfig).animation=false;
  });
  afterEach(()=>{TestBed.inject(NgbModal).dismissAll();});
  for(const state of [
    {name:'pending receipt',status:'Pending',handoverDate:null,received:false},
    {name:'legacy missing status',status:undefined,handoverDate:null,received:false},
    {name:'confirmed receipt',status:'Completed',handoverDate:'2026-10-07T10:00:00Z',received:true},
    {name:'posted completion without a date',status:'Completed',handoverDate:null,received:true},
  ]){
    it(`shows the post-receipt balance only for ${state.name} when confirmed`,()=>{
      const translate=TestBed.inject(TranslateService);translate.setTranslation('ar',arLocale.data);translate.use('ar');
      pay.items$=of([{id:8,amount:470,newBalance:1234,status:state.status,handoverDate:state.handoverDate,isSettlement:false}]);
      const f=TestBed.createComponent(PaymentsListComponent);f.detectChanges();
      const cell=f.nativeElement.querySelector('.ops-table tbody tr').querySelectorAll('td')[5];
      expect(cell.querySelector('.amount-val')!==null).toBe(state.received);
      expect(cell.textContent.includes('بانتظار تأكيد التاجر — لم يُخصم بعد')).toBe(!state.received);
      if(!state.received)expect(cell.textContent).not.toContain('1,234');
      f.destroy();
    });
  }
  it('updates the pending balance cell after confirmation and preserves a zero balance',()=>{
    const items=new BehaviorSubject<any[]>([{id:8,amount:470,newBalance:999,status:'Pending',handoverDate:null}]);pay.items$=items;
    const f=TestBed.createComponent(PaymentsListComponent);f.detectChanges();
    const balanceCell=()=>f.nativeElement.querySelector('.ops-table tbody tr').querySelectorAll('td')[5];
    expect(balanceCell().querySelector('.amount-val')).toBeNull();
    items.next([{id:8,amount:470,newBalance:0,status:'Completed',handoverDate:'2026-10-07T10:00:00Z'}]);f.detectChanges();
    expect(balanceCell().querySelector('.amount-val').textContent.trim()).toBe('0');
    expect(balanceCell().querySelector('.badge')).toBeNull();f.destroy();
  });
  it('does not invent a balance for a settlement request',()=>{
    pay.items$=of([{id:8,amount:470,newBalance:1234,status:'Completed',handoverDate:'2026-10-07T10:00:00Z',isSettlement:true}]);
    const f=TestBed.createComponent(PaymentsListComponent);f.detectChanges();
    expect(f.nativeElement.querySelector('.ops-table tbody tr').querySelectorAll('td')[5].textContent.trim()).toBe('—');f.destroy();
  });
  for(const locale of [arLocale,enLocale]){
    it(`explains merchant confirmation and available balances in the ${locale.lang} creation modal`,()=>{
      const translate=TestBed.inject(TranslateService);translate.setTranslation(locale.lang,locale.data);translate.use(locale.lang);
      const f=TestBed.createComponent(CreatePaymentModalComponent);f.detectChanges();
      expect(f.nativeElement.textContent).toContain(locale.data.PAYMENTS_PAGE.CREATE_HELP);
      const help=locale.data.PAYMENTS_PAGE.CREATE_HELP;
      expect(help).toContain(locale.lang==='ar' ? 'بعد أن يضغط التاجر' : 'only after the merchant');
      expect(locale.data.PAYMENTS_PAGE.MERCHANT_BALANCE).toContain(locale.lang==='ar' ? 'المتاحة' : 'Available');
      f.destroy();
    });
  }
  for(const component of [PaymentsListComponent,BillsListComponent,CaptainSettlementsListComponent,ReconciliationListComponent,CreatePaymentModalComponent,DriverCashAdvanceModalComponent]){
    it(`renders ${component.name} and every embedded modal`,()=>{
      const fixture=TestBed.createComponent(component as any);fixture.detectChanges();
      expect(fixture.nativeElement.textContent.trim().length).toBeGreaterThan(0);
      const templates=new Set<TemplateRef<any>>();
      fixture.debugElement.queryAllNodes(()=>true).forEach(node=>Object.values(node.references).forEach(ref=>{if(ref instanceof TemplateRef)templates.add(ref);}));
      const c:any=fixture.componentInstance;
      if(component===CaptainSettlementsListComponent){c.selectedCaptainForOrders={captainName:'Driver',captainId:'driver'};c.captainOrdersDetail={orders:[{orderId:15,cashCollected:1308,captainEarning:40,customerDeliveryFee:100}],totalCashCollected:1308};c.selectedReceipt={batchId:'QA',totalCashCollected:1308,totalCaptainEarnings:40,wagesOffset:40,netDueToCompany:1268};}
      if(component===ReconciliationListComponent){c.selectedCaptain={captainName:'Driver',captainUserId:'driver',cashFloatBalance:1683.5,wagesEarnedBalance:40,expectedNetCashDue:1643.5};c.selectedMerchantForStatement={merchantId:30,merchantTitle:'Store'};c.merchantStatementData={items:[],settlementHistory:[]};c.statementDetails={captainName:'Driver',floatStatement:[],earningsStatement:[],expectedNetCashDue:1683.5};c.selectedReceipt={amount:1683.5,currency:'SYP',receiptNumber:'QA'};}
      for(const ref of templates){const opened=TestBed.inject(NgbModal).open(ref);opened.result.catch(()=>{});fixture.detectChanges();expect(document.querySelector('ngb-modal-window')).not.toBeNull();opened.close();}
      if(component===CaptainSettlementsListComponent)expect(templates.size).toBeGreaterThanOrEqual(2);
      if(component===ReconciliationListComponent)expect(templates.size).toBeGreaterThanOrEqual(4);
      fixture.destroy();
    });
  }
  it('payment global totals come from server even on an empty page',()=>{
    const f=TestBed.createComponent(PaymentsListComponent);f.detectChanges();pay.summary$.next({recordsCount:25,totalPaid:1683.5,averagePayment:67.34,uniqueRecipients:3});
    expect(f.componentInstance.kpiTotalPaid).toBe(1683.5);expect(f.componentInstance.kpiTransactions).toBe(25);f.destroy();
  });
  it('bills filter and search return to first page',()=>{
    const f=TestBed.createComponent(BillsListComponent);f.detectChanges();bills.paginator.page=4;f.componentInstance.search('First');expect(bills.patchState.calls.mostRecent().args[0].paginator.page).toBe(0);
    f.componentInstance.filterByDues('pending');expect(bills.patchState.calls.mostRecent().args[0].filter.duesStatus).toBe('pending');f.destroy();
  });
  function payment(){const f=TestBed.createComponent(CreatePaymentModalComponent);f.detectChanges();const c=f.componentInstance;c.formGroup.patchValue({toUser:c.merchants[1],byUser:{id:'driver'},amount:400});c.merchantBalance=900;c.deliveryBalance=1000;return f;}
  it('payment chooses the exact store when two stores share an owner',()=>{const f=payment();f.componentInstance.save();expect(pay.create.calls.mostRecent().args[0].merchantId).toBe(31);f.destroy();});
  it('double clicking payment posts once',()=>{const f=payment();f.componentInstance.save();f.componentInstance.save();expect(pay.create).toHaveBeenCalledTimes(1);f.destroy();});
  it('network retry preserves payment operation key',()=>{pay.create.and.returnValue(throwError(()=>new Error('network')));const f=payment();f.componentInstance.save();const key=pay.create.calls.mostRecent().args[0].requestKey;f.componentInstance.save();expect(pay.create.calls.mostRecent().args[0].requestKey).toBe(key);f.destroy();});
  for(const amount of [-1,0,1.005,1001])it(`rejects invalid or excessive payment ${amount}`,()=>{const f=payment();f.componentInstance.formGroup.patchValue({amount});expect(f.componentInstance.canSave).toBeFalse();f.destroy();});
  it('cash advance network retry uses same idempotency key',()=>{advance.create.and.returnValue(throwError(()=>new Error('network')));const f=TestBed.createComponent(DriverCashAdvanceModalComponent);f.detectChanges();f.componentInstance.form.patchValue({driverUserId:'driver',amount:50,reason:'شراء'});f.componentInstance.submit();const key=advance.create.calls.mostRecent().args[0].idempotencyKey;f.componentInstance.submit();expect(advance.create.calls.mostRecent().args[0].idempotencyKey).toBe(key);f.destroy();});
  it('captain summary cancels older responses',()=>{const a=new Subject(),b=new Subject();captain.getSummary.and.returnValues(a,b);const f=TestBed.createComponent(CaptainSettlementsListComponent);f.detectChanges();f.componentInstance.loadSummary();b.next({items:[],totalCashCollected:222});a.next({items:[],totalCashCollected:999});expect(f.componentInstance.overview?.totalCashCollected).toBe(222);f.destroy();});
  it('reconciliation preserves fractions and blocks duplicate confirmation',()=>{const f=TestBed.createComponent(ReconciliationListComponent);f.detectChanges();const c=f.componentInstance;c.selectedCaptain={captainUserId:'driver',expectedNetCashDue:1683.5,currency:'SYP'} as any;c.settleCashReceived=1683.5;c.confirmSettlement(modal);c.confirmSettlement(modal);expect(reconciliation.settleShift).toHaveBeenCalledTimes(1);expect(reconciliation.settleShift.calls.mostRecent().args[0].physicalCashReceived).toBe(1683.5);f.destroy();});
  for(const amount of [-1,1.005])it(`reconciliation rejects invalid amount ${amount}`,()=>{const f=TestBed.createComponent(ReconciliationListComponent);f.detectChanges();f.componentInstance.selectedCaptain={captainUserId:'driver'} as any;f.componentInstance.settleCashReceived=amount;f.componentInstance.confirmSettlement(modal);expect(reconciliation.settleShift).not.toHaveBeenCalled();f.destroy();});
  it('leaving payments cancels overview reads',()=>{const read=new Subject();advance.getOverview.and.returnValue(read);const f=TestBed.createComponent(PaymentsListComponent);f.detectChanges();f.destroy();expect(read.observed).toBeFalse();});
});

describe('Finance HTTP response metadata',()=>{
  let http:HttpTestingController;
  beforeEach(()=>{TestBed.configureTestingModule({imports:[HttpClientTestingModule]});http=TestBed.inject(HttpTestingController);});afterEach(()=>http.verify());
  it('bills send server dues filter and retain global summary',()=>{const service=TestBed.inject(BillsService);service.patchState({filter:{duesStatus:'pending'}});const request=http.expectOne(r=>r.url.endsWith('/Admin/Bills/DataTable'));expect(request.request.params.get('duesStatus')).toBe('pending');request.flush({items:[],totalRecords:20,totalRecordsFiltered:20,summary:{totalBilled:1683.5}});expect(service.summary$.value.totalBilled).toBe(1683.5);});
  it('failed payment list clears outdated totals',()=>{const service=TestBed.inject(paymentsService);service.summary$.next({totalPaid:99});service.fetchPost();http.expectOne(r=>r.url.endsWith('/Admin/Payments/DataTable')).flush({}, {status:500,statusText:'Error'});expect(service.summary$.value).toBeNull();});
});
