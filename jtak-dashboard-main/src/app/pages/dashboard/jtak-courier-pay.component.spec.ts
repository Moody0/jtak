import { of, Subject, throwError } from 'rxjs';
import { JtakCourierPayComponent } from './jtak-courier-pay.component';
import { DashboardService } from './services/dashboard.service';
import { TestBed } from '@angular/core/testing';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

describe('JtakCourierPayComponent', () => {
  let service: jasmine.SpyObj<DashboardService>;
  let component: JtakCourierPayComponent;
  beforeEach(() => {
    service = jasmine.createSpyObj('DashboardService', ['getJtakMarketCourierPay', 'saveJtakMarketCourierPay']);
    service.getJtakMarketCourierPay.and.returnValue(of({mode: 0, rate: 0}));
    service.saveJtakMarketCourierPay.and.callFake(setting => of(setting));
    component = new JtakCourierPayComponent(service);
  });
  afterEach(() => component.ngOnDestroy());
  it('defaults to monthly salary and saves zero per-order earnings', () => {
    component.ngOnInit(); expect(component.mode).toBe(0); component.rate = 999; component.save();
    expect(service.saveJtakMarketCourierPay).toHaveBeenCalledWith({mode: 0, rate: 0});
    expect(component.success).toBeTrue();
  });
  it('supports fixed completed-order wages and percentage independently of customer charges', () => {
    component.ngOnInit(); component.mode = 3; component.rate = 75; component.save();
    expect(service.saveJtakMarketCourierPay).toHaveBeenCalledWith({mode: 3, rate: 75});
    component.mode = 2; component.rate = 60; component.save();
    expect(service.saveJtakMarketCourierPay).toHaveBeenCalledWith({mode: 2, rate: 60});
  });
  it('rejects kilometre mode, zero active rates and percentages over 100', () => {
    component.ngOnInit(); component.mode = 1; component.rate = 45; component.save();
    component.mode = 2; component.rate = 101; component.save();
    component.mode = 3; component.rate = 0; component.save();
    component.rate = 0.123; component.save();
    expect(service.saveJtakMarketCourierPay).not.toHaveBeenCalled();
  });
  it('prevents writes before successful load and allows retry', () => {
    service.getJtakMarketCourierPay.and.returnValue(throwError(() => new Error('offline')));
    component.ngOnInit(); component.save(); expect(service.saveJtakMarketCourierPay).not.toHaveBeenCalled();
    service.getJtakMarketCourierPay.and.returnValue(of({mode: 0, rate: 0})); component.load();
    expect(component.loaded).toBeTrue();
  });
  it('prevents duplicate writes and reports save failure', () => {
    component.ngOnInit(); const pending = new Subject<{mode: number, rate: number}>();
    service.saveJtakMarketCourierPay.and.returnValue(pending); component.save(); component.save();
    expect(service.saveJtakMarketCourierPay).toHaveBeenCalledTimes(1);
    pending.error(new Error('offline')); expect(component.success).toBeFalse(); expect(component.saving).toBeFalse();
  });
  it('renders the three policies, monthly default and honest salary limitation', async () => {
    await TestBed.configureTestingModule({declarations: [JtakCourierPayComponent], imports: [CommonModule, FormsModule],
      providers: [{provide: DashboardService, useValue: service}]}).compileComponents();
    const fixture = TestBed.createComponent(JtakCourierPayComponent); fixture.detectChanges(); await fixture.whenStable(); fixture.detectChanges();
    const root: HTMLElement = fixture.nativeElement;
    expect(root.querySelectorAll('option').length).toBe(3);
    expect(root.querySelector('#jtak-courier-rate')).toBeNull();
    expect(root.textContent).toContain('لا يحدد مبلغ الراتب');
    fixture.destroy();
  });
});
