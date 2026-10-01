import { of, Subject, throwError } from 'rxjs';
import { JtakDeliveryFeeComponent } from './jtak-delivery-fee.component';
import { DashboardService } from './services/dashboard.service';
import { TestBed } from '@angular/core/testing';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

describe('JtakDeliveryFeeComponent', () => {
  let service: jasmine.SpyObj<DashboardService>;
  let component: JtakDeliveryFeeComponent;
  beforeEach(() => {
    service = jasmine.createSpyObj('DashboardService', ['getJtakMarketDeliveryFee', 'saveJtakMarketDeliveryFee']);
    service.getJtakMarketDeliveryFee.and.returnValue(of({amount: 100}));
    service.saveJtakMarketDeliveryFee.and.returnValue(of({amount: 125}));
    component = new JtakDeliveryFeeComponent(service);
  });
  afterEach(() => component.ngOnDestroy());
  it('loads the existing market fee rather than defaulting to restaurant pricing', () => {
    component.ngOnInit(); expect(component.amount).toBe(100); expect(component.loaded).toBeTrue();
  });
  it('saves only the fixed amount and displays the server response', () => {
    component.ngOnInit(); component.amount = 125; component.save();
    expect(service.saveJtakMarketDeliveryFee).toHaveBeenCalledWith({amount: 125});
    expect(component.success).toBeTrue(); expect(component.amount).toBe(125);
  });
  it('rejects missing, negative, invalid and overprecision fees, but permits explicit zero', () => {
    component.ngOnInit();
    for (const amount of [null, -1, NaN, Infinity, 0.123, 100000001]) { component.amount = amount; component.save(); }
    expect(service.saveJtakMarketDeliveryFee).not.toHaveBeenCalled();
    component.amount = 0; component.save();
    expect(service.saveJtakMarketDeliveryFee).toHaveBeenCalledWith({amount: 0});
  });
  it('blocks saving when loading fails and allows retry', () => {
    service.getJtakMarketDeliveryFee.and.returnValue(throwError(() => new Error('offline')));
    component.ngOnInit(); component.amount = 100; component.save();
    expect(service.saveJtakMarketDeliveryFee).not.toHaveBeenCalled();
    service.getJtakMarketDeliveryFee.and.returnValue(of({amount: 100})); component.load();
    expect(component.loaded).toBeTrue(); expect(component.error).toBe('');
  });
  it('prevents repeated writes and reports failed persistence', () => {
    component.ngOnInit(); const pending = new Subject<{amount: number}>();
    service.saveJtakMarketDeliveryFee.and.returnValue(pending); component.save(); component.save();
    expect(service.saveJtakMarketDeliveryFee).toHaveBeenCalledTimes(1);
    pending.error(new Error('offline')); expect(component.success).toBeFalse(); expect(component.saving).toBeFalse();
  });
  it('renders the independent editable amount and virtual-market explanation', async () => {
    await TestBed.configureTestingModule({declarations: [JtakDeliveryFeeComponent], imports: [CommonModule, FormsModule],
      providers: [{provide: DashboardService, useValue: service}]}).compileComponents();
    const fixture = TestBed.createComponent(JtakDeliveryFeeComponent); fixture.detectChanges(); await fixture.whenStable(); fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('متجر افتراضي');
    expect(fixture.nativeElement.querySelector('input').value).toBe('100');
    fixture.destroy();
  });
});
