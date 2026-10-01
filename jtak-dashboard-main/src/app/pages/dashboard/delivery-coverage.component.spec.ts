import { of, Subject, throwError } from 'rxjs';
import { DeliveryCoverageComponent } from './delivery-coverage.component';
import { DashboardService } from './services/dashboard.service';
import { TestBed } from '@angular/core/testing';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

describe('DeliveryCoverageComponent', () => {
  let service: jasmine.SpyObj<DashboardService>;
  let component: DeliveryCoverageComponent;
  beforeEach(() => {
    service = jasmine.createSpyObj('DashboardService', ['getDeliveryCoverage', 'saveDeliveryCoverage']);
    service.getDeliveryCoverage.and.returnValue(of({radiusKm: 25}));
    service.saveDeliveryCoverage.and.returnValue(of({radiusKm: 12.5}));
    component = new DeliveryCoverageComponent(service);
  });
  afterEach(() => component.ngOnDestroy());
  it('loads existing radius and bounds the circle and map preview', () => {
    component.ngOnInit();
    expect(component.radiusKm).toBe(25);
    expect(component.circle.split(' ').length).toBe(73);
    const points = component.circle.split(' ').map(p => p.split(',').map(Number));
    expect(points.every(([x,y]) => x > 0 && x < 512 && y > 0 && y < 320)).toBeTrue();
    expect(component.tiles.length).toBeLessThanOrEqual(9);
  });
  it('rejects invalid, empty, or excessive precision radii without saving', () => {
    component.ngOnInit();
    for (const value of [null, 0, -1, 101, 0.123, NaN]) {
      component.radiusKm = value; component.save();
    }
    expect(service.saveDeliveryCoverage).not.toHaveBeenCalled();
  });
  it('saves only radius and confirms server response', () => {
    component.ngOnInit(); component.radiusKm = 12.5; component.save();
    expect(service.saveDeliveryCoverage).toHaveBeenCalledWith({radiusKm: 12.5});
    expect(component.success).toBeTrue(); expect(component.radiusKm).toBe(12.5);
  });
  it('blocks repeated saves while a request is pending', () => {
    component.ngOnInit();
    const pending = new Subject<any>(); service.saveDeliveryCoverage.and.returnValue(pending);
    component.save(); component.save();
    expect(service.saveDeliveryCoverage).toHaveBeenCalledTimes(1);
    pending.next({radiusKm: 25}); pending.complete();
  });
  it('shows save failure without claiming persistence', () => {
    component.ngOnInit(); service.saveDeliveryCoverage.and.returnValue(throwError(() => new Error('offline')));
    component.save();
    expect(component.success).toBeFalse(); expect(component.error).toContain('تعذر حفظ');
    expect(component.saving).toBeFalse();
  });
  it('blocks saving before radius has loaded', () => {
    service.getDeliveryCoverage.and.returnValue(throwError(() => new Error('offline')));
    component.ngOnInit(); component.save();
    expect(service.saveDeliveryCoverage).not.toHaveBeenCalled();
    expect(component.error).toContain('تعذر تحميل');
  });
  it('renders editable radius, fixed centre, attribution and preview', async () => {
    await TestBed.configureTestingModule({declarations: [DeliveryCoverageComponent],
      imports: [CommonModule, FormsModule], providers: [{provide: DashboardService, useValue: service}]}).compileComponents();
    const fixture = TestBed.createComponent(DeliveryCoverageComponent);
    fixture.detectChanges(); await fixture.whenStable(); fixture.detectChanges();
    const root: HTMLElement = fixture.nativeElement;
    const input = root.querySelector('input')!;
    expect(input.value).toBe('25'); expect(input.disabled).toBeFalse();
    expect(root.textContent).toContain('34.7333'); expect(root.textContent).toContain('36.7167');
    expect(root.querySelector('svg polygon')).not.toBeNull();
    expect(root.querySelector('a[href="https://www.openstreetmap.org/copyright"]')).not.toBeNull();
    input.value = '0'; input.dispatchEvent(new Event('input')); fixture.detectChanges();
    expect(root.querySelector('button')!.disabled).toBeTrue();
    expect(root.textContent).toContain('بين 0.1 و100');
    fixture.destroy();
  });
});
