import { CommonModule } from '@angular/common';
import { NO_ERRORS_SCHEMA } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ReactiveFormsModule } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { of } from 'rxjs';
import { MerchantsService } from '../../../merchant/services/merchants.service';
import { NotificationsService } from '../../services/notifications.service';
import { NotificationsCreateComponent } from './notifications-create.component';

describe('Notification destination selection', () => {
  let fixture: ComponentFixture<NotificationsCreateComponent>;
  let component: NotificationsCreateComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [NotificationsCreateComponent],
      imports: [CommonModule, ReactiveFormsModule],
      schemas: [NO_ERRORS_SCHEMA],
      providers: [
        { provide: NotificationsService, useValue: { getCampaignAudiences: () => of({ pushConfigured: true }) } },
        { provide: MerchantsService, useValue: { getAllMerchants: () => of([]) } },
        { provide: NgbActiveModal, useValue: {} },
        { provide: ToastrService, useValue: {} },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(NotificationsCreateComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('preserves native options and the selected destination across preview refreshes', () => {
    const select: HTMLSelectElement = fixture.nativeElement.querySelector('#campaign-destination');
    const originalOptions = Array.from(select.options);
    fixture.detectChanges();
    originalOptions.forEach((option, index) => expect(select.options[index]).toBe(option));
    for (const value of ['orders', 'grocery', 'restaurants', 'favorites', 'errands', 'home']) {
      select.value = value;
      select.dispatchEvent(new Event('change'));
      fixture.detectChanges();
      component.formGroup.get('textAr')!.setValue('Updated notification preview');
      fixture.detectChanges();
      expect(component.formGroup.value.destination).toBe(value);
      expect(select.value).toBe(value);
      expect(fixture.nativeElement.querySelector('.campaign-preview-note strong').textContent.trim()).toBe(component.destinationLabel);
    }
  });

  it('updates available destinations when the target app changes', () => {
    for (const target of ['delivery', 'warehouse', 'customers'] as const) {
      component.selectTarget(target);
      fixture.detectChanges();
      const select: HTMLSelectElement = fixture.nativeElement.querySelector('#campaign-destination');
      expect(select.value).toBe('home');
      const value = target === 'customers' ? 'grocery' : 'finance';
      select.value = value;
      select.dispatchEvent(new Event('change'));
      fixture.detectChanges();
      expect(component.formGroup.value.destination).toBe(value);
      expect(select.value).toBe(value);
    }
  });
});
