import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { ContactSettingsService } from './services/contact-settings.service';
import { SystemContactSettings } from './models/contact-settings.model';

@Component({
  selector: 'app-contact-settings',
  templateUrl: './contact-settings.component.html',
  styleUrls: ['./contact-settings.component.scss'],
})
export class ContactSettingsComponent implements OnInit, OnDestroy {
  form: UntypedFormGroup;
  isLoading = false;
  isSaving = false;
  private subs = new SubSink();

  constructor(
    private fb: UntypedFormBuilder,
    private contactService: ContactSettingsService,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.initForm();
    this.loadSettings();
  }

  private initForm(): void {
    this.form = this.fb.group({
      phoneNumber: ['0985615705', [Validators.required, Validators.pattern(/^[0-9+\s-]{7,16}$/)]],
      phoneInternational: ['+963985615705'],
      phoneFormatted: ['0985 615 705'],
      whatsAppNumber: ['963985615705', [Validators.required, Validators.pattern(/^[0-9]{9,16}$/)]],
      supportEmail: ['contact@jtak.app', [Validators.required, Validators.email]],
      facebookUrl: ['https://www.facebook.com/app.jtak/'],
      instagramUrl: ['https://www.instagram.com/JTAKcompany/'],
      youtubeUrl: ['https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ'],
      telegramUrl: [''],
      workingHoursAr: ['يومياً 9:00 ص - 12:00 منتصف الليل'],
      workingHoursEn: ['Daily 9:00 AM - 12:00 Midnight'],
      addressAr: ['سوريا - حمص'],
      addressEn: ['Syria - Homs'],
    });
  }

  loadSettings(): void {
    this.isLoading = true;
    this.subs.sink = this.contactService.getSettings().subscribe({
      next: (settings: SystemContactSettings) => {
        if (settings) {
          this.form.patchValue(settings);
        }
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.toastr.error('تعذر تحميل إعدادات التواصل الحالية.');
        this.isLoading = false;
        this.cdr.detectChanges();
      },
    });
  }

  onPhoneNumberChange(): void {
    const raw = (this.form.get('phoneNumber')?.value || '').toString().trim();
    const digits = raw.replace(/[^\d]/g, '');

    // Auto-compute formatted and international if using standard Syrian mobile
    if (digits.startsWith('09') && digits.length === 10) {
      this.form.patchValue({
        phoneInternational: `+963${digits.substring(1)}`,
        phoneFormatted: `${digits.substring(0, 4)} ${digits.substring(4, 3)} ${digits.substring(7)}`,
        whatsAppNumber: `963${digits.substring(1)}`,
      });
    }
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.toastr.warning('يرجى التحقق من صحة الحقول المدخلة.');
      return;
    }

    this.isSaving = true;
    const values: SystemContactSettings = this.form.value;

    this.subs.sink = this.contactService.saveSettings(values).subscribe({
      next: () => {
        this.isSaving = false;
        this.toastr.success('تم حفظ إعدادات التواصل وتحديثها لجميع التطبيقات بنجاح.');
        this.form.markAsPristine();
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.toastr.error('حدث خطأ أثناء حفظ الإعدادات.');
        this.cdr.detectChanges();
      },
    });
  }

  resetDefaults(): void {
    this.form.patchValue({
      phoneNumber: '0985615705',
      phoneInternational: '+963985615705',
      phoneFormatted: '0985 615 705',
      whatsAppNumber: '963985615705',
      supportEmail: 'contact@jtak.app',
      facebookUrl: 'https://www.facebook.com/app.jtak/',
      instagramUrl: 'https://www.instagram.com/JTAKcompany/',
      youtubeUrl: 'https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ',
      telegramUrl: '',
      workingHoursAr: 'يومياً 9:00 ص - 12:00 منتصف الليل',
      workingHoursEn: 'Daily 9:00 AM - 12:00 Midnight',
      addressAr: 'سوريا - حمص',
      addressEn: 'Syria - Homs',
    });
    this.form.markAsDirty();
    this.toastr.info('تم استعادة الإعدادات الموصى بها افتراضياً.');
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
