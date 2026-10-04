import { DashboardComponent } from '../dashboard/dashboard.component';
import { SubSink } from 'subsink';
import { ApplicationRef } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { NgbModal, NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { of, Subject, BehaviorSubject, throwError } from 'rxjs';
import { PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { ContactSettingsModule } from './contact-settings.module';
import { ContactSettingsComponent } from './contact-settings.component';
import { ContactSettingsService } from './services/contact-settings.service';
import { PagesModule } from '../pages/pages.module';
import { PageComponent } from '../pages/components/page/page.component';
import { PagesService } from '../pages/services/pages.service';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { AuditLogsListComponent } from '../audit-logs/components/audit-logs-list/audit-logs-list.component';
import { AuditLogDetailsModalComponent } from '../audit-logs/components/audit-log-details-modal/audit-log-details-modal.component';
import { AuditLogsService } from '../audit-logs/services/audit-logs.service';

describe('System settings actual page and modal templates', () => {
 let contacts: any, pages: any, audit: any, toast: any, route: BehaviorSubject<any>;
 beforeEach(async () => {
  contacts = { getSettings: jasmine.createSpy().and.returnValue(of({phoneNumber:'0985615705',whatsAppNumber:'963985615705'})), saveSettings: jasmine.createSpy().and.callFake(() => new Subject()) };
  pages = { getPage: jasmine.createSpy().and.returnValue(of({body:'<p>شروط التطبيق</p>'})), setPage: jasmine.createSpy().and.callFake(() => new Subject()) };
  toast = jasmine.createSpyObj('toast',['success','error','warning','info']);
  route = new BehaviorSubject({id:'TermsAndConditions'});
  audit = { paginator: new PaginatorState(), sorting: new SortState(), items$: of([]), isLoading$:of(false), listError$:of(null),
   setDefaults:jasmine.createSpy(), patchState:jasmine.createSpy(), fetchPost:jasmine.createSpy(), getCachedSummary:()=>null,
   getSummary:jasmine.createSpy().and.returnValue(of({totalOperations:0,todayOperations:0,thisWeekOperations:0,successCount:0,failureCount:0,topAdmin:'',topModule:''})), cacheSummary:jasmine.createSpy() };
  await TestBed.configureTestingModule({imports:[ContactSettingsModule, PagesModule, AuditLogsModule, HttpClientTestingModule, RouterTestingModule, TranslateModule.forRoot()],
   providers:[{provide:ContactSettingsService,useValue:contacts},{provide:PagesService,useValue:pages},{provide:AuditLogsService,useValue:audit},
    {provide:ToastrService,useValue:toast},{provide:ActivatedRoute,useValue:{params:route}},{provide:NgbActiveModal,useValue:{dismiss:jasmine.createSpy()}}]}).compileComponents();
 });
 it('contact loading failure cannot overwrite actual server configuration with defaults',()=>{
  contacts.getSettings.and.returnValue(throwError(()=>new Error('offline')));
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.save();f.componentInstance.resetDefaults();
  expect(contacts.saveSettings).not.toHaveBeenCalled();expect(f.componentInstance.form.disabled).toBeTrue();expect(f.nativeElement.querySelector('[role=alert]').textContent).toContain('تعذر');f.destroy();
 });
 it('retry unlocks contacts only after a successful read',()=>{
  contacts.getSettings.and.returnValue(throwError(()=>new Error()));const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();
  contacts.getSettings.and.returnValue(of({phoneNumber:'0912345678'}));f.componentInstance.loadSettings();
  expect(f.componentInstance.hasLoaded).toBeTrue();expect(f.componentInstance.form.enabled).toBeTrue();f.destroy();
 });
 it('contact save locks editing and ignores repeated submit',()=>{
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.save();f.componentInstance.save();
  expect(contacts.saveSettings).toHaveBeenCalledTimes(1);expect(f.componentInstance.form.disabled).toBeTrue();contacts.saveSettings.calls.mostRecent().returnValue.next(true);
  expect(f.componentInstance.form.enabled).toBeTrue();expect(f.componentInstance.form.pristine).toBeTrue();f.destroy();
 });
 it('contact failed save unlocks fields for retry',()=>{
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.save();contacts.saveSettings.calls.mostRecent().returnValue.error(new Error());
  expect(f.componentInstance.isSaving).toBeFalse();expect(f.componentInstance.form.enabled).toBeTrue();expect(toast.error).toHaveBeenCalled();f.destroy();
 });
 it('primary number formatting uses all digits and leaves separate WhatsApp unchanged',()=>{
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.form.patchValue({phoneNumber:'0912345678',whatsAppNumber:'963999111222'});f.componentInstance.onPhoneNumberChange();
  expect(f.componentInstance.form.value.phoneFormatted).toBe('0912 345 678');expect(f.componentInstance.form.value.phoneInternational).toBe('+963912345678');expect(f.componentInstance.form.value.whatsAppNumber).toBe('963999111222');f.destroy();
 });
 it('international phone refreshes dialer value too',()=>{
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.form.patchValue({phoneNumber:'+201234567890'});f.componentInstance.onPhoneNumberChange();expect(f.componentInstance.form.value.phoneInternational).toBe('+201234567890');f.destroy();
 });
 it('unsafe social links and oversized WhatsApp fail validation',()=>{
  const f=TestBed.createComponent(ContactSettingsComponent);f.detectChanges();f.componentInstance.form.patchValue({facebookUrl:'javascript:alert(1)'});f.componentInstance.save();expect(contacts.saveSettings).not.toHaveBeenCalled();
  f.componentInstance.form.patchValue({facebookUrl:'',whatsAppNumber:'1234567890123456'});expect(f.componentInstance.form.invalid).toBeTrue();f.destroy();
 });
 it('legal editor cannot save after a failed load even if body is filled',()=>{
  pages.getPage.and.returnValue(throwError(()=>new Error()));const f=TestBed.createComponent(PageComponent);f.detectChanges();f.componentInstance.formGroup.patchValue({body:'filled'});f.componentInstance.save();
  expect(pages.setPage).not.toHaveBeenCalled();expect(f.nativeElement.querySelector('[role=alert]')).not.toBeNull();f.destroy();
 });
 it('blank rich text never erases legal page',()=>{
  const f=TestBed.createComponent(PageComponent);f.detectChanges();f.componentInstance.formGroup.patchValue({body:'<p>&nbsp;</p>'});f.componentInstance.save();expect(pages.setPage).not.toHaveBeenCalled();f.destroy();
 });
 it('legal save includes selected application and prevents duplicate submission',()=>{
  const f=TestBed.createComponent(PageComponent);f.detectChanges();f.componentInstance.selectTermsApp('delivery');f.componentInstance.save();f.componentInstance.save();
  expect(pages.setPage).toHaveBeenCalledOnceWith('TermsAndConditions',{title:'TermsAndConditions',body:'<p>شروط التطبيق</p>'},'delivery');expect(f.componentInstance.formGroup.disabled).toBeTrue();f.destroy();
 });
 it('copying customer terms prevents switching into another app mid-response',()=>{
  const f=TestBed.createComponent(PageComponent);f.detectChanges();f.componentInstance.selectTermsApp('warehouse');const pending=new Subject();pages.getPage.and.returnValue(pending);
  f.componentInstance.copyCustomerTerms();f.componentInstance.copyCustomerTerms();f.componentInstance.selectTermsApp('delivery');expect(f.componentInstance.selectedTermsApp).toBe('warehouse');
  pending.next({body:'copied'});expect(f.componentInstance.formGroup.value.body).toContain('copied');expect(f.componentInstance.isCopying).toBeFalse();f.destroy();
 });
 it('route changes cancel old customer copy so it cannot overwrite a privacy page',()=>{
  const f=TestBed.createComponent(PageComponent);f.detectChanges();f.componentInstance.selectTermsApp('warehouse');const pending=new Subject();pages.getPage.and.returnValue(pending);f.componentInstance.copyCustomerTerms();
  pages.getPage.and.returnValue(of({body:'privacy'}));route.next({id:'PrivacyPolicy'});pending.next({body:'late terms'});expect(f.componentInstance.formGroup.value.body).toContain('privacy');f.destroy();
 });
 it('a stale legal load cannot overwrite the current app selection',()=>{
  const f=TestBed.createComponent(PageComponent);f.detectChanges();const old=new Subject();pages.getPage.and.returnValue(old);f.componentInstance.selectTermsApp('delivery');
  pages.getPage.and.returnValue(of({body:'merchant'}));f.componentInstance.selectTermsApp('warehouse');old.next({body:'driver'});expect(f.componentInstance.formGroup.value.body).toContain('merchant');f.destroy();
 });
 it('audit page resets hidden stale filters on entry',()=>{const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();expect(audit.setDefaults).toHaveBeenCalled();f.destroy();});
 it('audit dropdown filtering starts from the first page',()=>{const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();audit.paginator.page=7;f.componentInstance.selectedModule='Settings';f.componentInstance.applyFilters();expect(audit.patchState.calls.mostRecent().args[0].paginator.page).toBe(0);f.destroy();});
 it('audit KPI and reset both return to first page',()=>{const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();f.componentInstance.filterByResult('Failed');expect(audit.patchState.calls.mostRecent().args[0].paginator.page).toBe(0);f.componentInstance.resetFilters();expect(audit.patchState.calls.mostRecent().args[0].paginator.page).toBe(0);f.destroy();});
 it('invalid audit date ranges show message instead of an empty query',()=>{const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();f.componentInstance.fromDate='2026-10-04';f.componentInstance.toDate='2026-10-03';f.componentInstance.applyFilters();expect(audit.patchState).not.toHaveBeenCalled();expect(toast.warning).toHaveBeenCalled();f.destroy();});
 it('failed statistics load warns that cached totals may be old',()=>{audit.getSummary.and.returnValue(throwError(()=>new Error()));const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();expect(f.nativeElement.querySelector('[role=alert]').textContent).toContain('قديمة');f.destroy();});
 it('clipboard denial is caught on the audit list',async()=>{const f=TestBed.createComponent(AuditLogsListComponent);f.detectChanges();spyOn(navigator.clipboard,'writeText').and.returnValue(Promise.reject(new Error()));await f.componentInstance.copyText('entry','id');expect(toast.error).toHaveBeenCalled();expect(f.componentInstance.copiedId).toBeNull();f.destroy();});
 it('audit details modal renders changed fields and catches clipboard errors',async()=>{
  const modal=TestBed.inject(NgbModal).open(AuditLogDetailsModalComponent);modal.componentInstance.log={id:'id',module:'Settings',action:'UpdateContactSettings',createdDate:'2026-10-04',result:'Success',beforeStateJson:'{"PhoneNumber":"old"}',afterStateJson:'{"PhoneNumber":"new"}'};
  TestBed.inject(ApplicationRef).tick();expect(document.body.textContent).toContain('old');expect(document.body.textContent).toContain('new');
  spyOn(navigator.clipboard,'writeText').and.returnValue(Promise.reject(new Error()));await modal.componentInstance.copyJson('{}','تغيير');expect(toast.error).toHaveBeenCalled();modal.dismiss();
 });
});

describe('System settings shared HTTP contracts',()=>{
 it('audit filters are retained and widget page zero requests API page one',()=>{
  TestBed.configureTestingModule({imports:[HttpClientTestingModule]});const service=TestBed.inject(AuditLogsService),http=TestBed.inject(HttpTestingController);service.setDefaults();service.patchState({filter:{module:'Settings',result:'Failed'}});
  const request=http.expectOne(r=>r.url.includes('/Admin/AuditLogs/DataTable'));expect(request.request.params.get('module')).toBe('Settings');expect(request.request.body.pageNumber).toBe(1);request.flush({items:[],totalRecords:0});http.verify();service.ngOnDestroy();
 });
});

 describe('System financial settings save lifecycle',()=>{
  function component(): any {
    const c:any=Object.create(DashboardComponent.prototype);
    c.subs=new SubSink();c.settingsSaveTimers=[];c.cdr={detectChanges:()=>{}};
    c.service={getDriverPricing:jasmine.createSpy().and.returnValue(throwError(()=>new Error())),saveDriverPricing:jasmine.createSpy().and.callFake(()=>new Subject()),
      getSettings:jasmine.createSpy().and.callFake(()=>new Subject()),saveSettings:jasmine.createSpy().and.callFake(()=>new Subject())};
    c.driverPricing={mode:0,fixedAmount:100,customerRatePerKm:45,minDeliveryFee:50};c.exchangeRate=100;
    return c;
  }
  it('failed driver pricing load cannot overwrite stored settings with defaults',()=>{const c=component();c.loadDriverPricing();c.saveDriverPricing();expect(c.driverPricingLoadError).toBeTrue();expect(c.service.saveDriverPricing).not.toHaveBeenCalled();c.ngOnDestroy();});
  it('driver pricing prevents repeated submits',()=>{const c=component();c.driverPricingLoaded=true;c.saveDriverPricing();c.saveDriverPricing();expect(c.service.saveDriverPricing).toHaveBeenCalledTimes(1);c.ngOnDestroy();});
  it('exchange rate save retains the submitted value while fetching current settings',()=>{const c=component();c.saveExchangeRate();c.exchangeRate=999;c.saveExchangeRate();expect(c.service.getSettings).toHaveBeenCalledTimes(1);c.service.getSettings.calls.mostRecent().returnValue.next({homeFeaturedProductIds:[7]});expect(c.service.saveSettings).toHaveBeenCalledWith({homeFeaturedProductIds:[7],usdToSypExchangeRate:100});c.ngOnDestroy();});
  it('destroying dashboard cancels pending exchange reads and writes',()=>{const c=component();c.saveExchangeRate();const pending=c.service.getSettings.calls.mostRecent().returnValue;c.ngOnDestroy();pending.next({});expect(c.service.saveSettings).not.toHaveBeenCalled();});
 });
