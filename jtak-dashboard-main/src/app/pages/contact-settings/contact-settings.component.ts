import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { AbstractControl, UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
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
  hasLoaded = false;
  loadError = false;
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

  private webLinkValidator(control: AbstractControl) {
    const value = String(control.value || '').trim();
    if (!value) return null;
    try {
      const url = new URL(value);
      return (url.protocol === 'https:' || url.protocol === 'http:') && !!url.hostname && !url.username && !url.password ? null : { url: true };
    } catch { return { url: true }; }
  }

  private initForm(): void {
    this.form = this.fb.group({
      phoneNumber: ['0985615705', [Validators.required, Validators.pattern(/^(09[0-9]{8}|\+?[1-9][0-9]{8,14})$/)]],
      phoneInternational: ['+963985615705'],
      phoneFormatted: ['0985 615 705'],
      whatsAppNumber: ['963985615705', [Validators.required, Validators.pattern(/^[1-9][0-9]{8,14}$/)]],
      supportEmail: ['contact@jtak.app', [Validators.required, Validators.email, Validators.maxLength(254)]],
      facebookUrl: ['https://www.facebook.com/app.jtak/', [this.webLinkValidator, Validators.maxLength(2048)]],
      instagramUrl: ['https://www.instagram.com/JTAKcompany/', [this.webLinkValidator, Validators.maxLength(2048)]],
      youtubeUrl: ['https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ', [this.webLinkValidator, Validators.maxLength(2048)]],
      telegramUrl: ['', [this.webLinkValidator, Validators.maxLength(2048)]],
      workingHoursAr: ['يومياً 9:00 ص - 12:00 منتصف الليل', [Validators.maxLength(1000)]],
      workingHoursEn: ['Daily 9:00 AM - 12:00 Midnight', [Validators.maxLength(1000)]],
      addressAr: ['سوريا - حمص', [Validators.maxLength(1000)]],
      addressEn: ['Syria - Homs', [Validators.maxLength(1000)]],
    });
  }

  loadSettings(): void {
    if (this.isLoading || this.isSaving) return;
    this.hasLoaded = false;
    this.loadError = false;
    this.form.disable();
    this.isLoading = true;
    this.subs.sink = this.contactService.getSettings().subscribe({
      next: (settings: SystemContactSettings) => {
        if (settings) {
          this.form.patchValue(settings);
        }
        this.hasLoaded = !!settings;
        this.loadError = !settings;
        if (settings) this.form.enable();
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.loadError = true;
        this.toastr.error('تعذر تحميل إعدادات التواصل الحالية. أعد التحميل قبل الحفظ.');
        this.isLoading = false;
        this.cdr.detectChanges();
      },
    });
  }

  onPhoneNumberChange(): void {
    const raw = (this.form.get('phoneNumber')?.value || '').toString().trim().replace(/[\s()-]/g, '');
    this.form.get('phoneNumber')?.setValue(raw, { emitEvent: false });
    const digits = raw.replace(/[^\d]/g, '');

    // Auto-compute formatted and international if using standard Syrian mobile
    if (digits.startsWith('09') && digits.length === 10) {
      this.form.patchValue({
        phoneInternational: `+963${digits.substring(1)}`,
        phoneFormatted: `${digits.slice(0, 4)} ${digits.slice(4, 7)} ${digits.slice(7)}`,

      });
    } else if (/^\+?[1-9][0-9]{8,14}$/.test(raw)) {
      this.form.patchValue({ phoneInternational: `+${digits}`, phoneFormatted: raw });
    }
  }

  save(): void {
    if (this.isLoading || this.isSaving || !this.hasLoaded) return;
    this.onPhoneNumberChange();
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.toastr.warning('يرجى التحقق من صحة الحقول المدخلة.');
      return;
    }

    this.isSaving = true;
    const values: SystemContactSettings = this.form.getRawValue();
    this.form.disable();

    this.subs.sink = this.contactService.saveSettings(values).subscribe({
      next: () => {
        this.isSaving = false;
        this.form.enable();
        this.toastr.success('تم حفظ إعدادات التواصل. تستقبل التطبيقات التحديث عند فتحها أو الرجوع إليها.');
        this.form.markAsPristine();
        this.cdr.detectChanges();
      },
      error: (error) => {
        this.isSaving = false;
        this.form.enable();
        this.toastr.error(error?.error?.message || (typeof error?.error === 'string' ? error.error : 'حدث خطأ أثناء حفظ الإعدادات.'));
        this.cdr.detectChanges();
      },
    });
  }

  resetDefaults(): void {
    if (this.isLoading || this.isSaving || !this.hasLoaded) return;
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
