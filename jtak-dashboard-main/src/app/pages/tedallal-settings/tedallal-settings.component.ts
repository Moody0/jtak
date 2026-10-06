import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { TedallalSettingsService } from './services/tedallal-settings.service';
import { TedallalCardSetting } from './models/tedallal-settings.model';

@Component({
  selector: 'app-tedallal-settings',
  templateUrl: './tedallal-settings.component.html',
  styleUrls: ['./tedallal-settings.component.scss'],
})
export class TedallalSettingsComponent implements OnInit, OnDestroy {
  form: UntypedFormGroup;
  isLoading = false;
  isSaving = false;
  hasLoaded = false;
  loadError = false;
  private subs = new SubSink();

  readonly defaultValues: TedallalCardSetting = {
    enabled: true,
    sectionTitle: 'خدمة تدلل',
    cardTitle: 'طلبات خاصة وعروض الأسعار',
    subtitle: 'اطلب أي شيء غير متوفر في التطبيق مع عروض أسعار فورية',
    logoUrl: '',
  };

  constructor(
    private fb: UntypedFormBuilder,
    private tedallalService: TedallalSettingsService,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.initForm();
    this.loadSettings();
  }

  private initForm(): void {
    this.form = this.fb.group({
      enabled: [this.defaultValues.enabled],
      sectionTitle: [this.defaultValues.sectionTitle, [Validators.required, Validators.maxLength(100)]],
      cardTitle: [this.defaultValues.cardTitle, [Validators.required, Validators.maxLength(120)]],
      subtitle: [this.defaultValues.subtitle, [Validators.required, Validators.maxLength(250)]],
      logoUrl: ['', [Validators.maxLength(2048)]],
    });
  }

  loadSettings(): void {
    this.isLoading = true;
    this.loadError = false;
    this.subs.sink = this.tedallalService.getSettings().subscribe({
      next: (data) => {
        this.isLoading = false;
        this.hasLoaded = true;
        this.form.patchValue({
          enabled: data?.enabled ?? this.defaultValues.enabled,
          sectionTitle: data?.sectionTitle || this.defaultValues.sectionTitle,
          cardTitle: data?.cardTitle || this.defaultValues.cardTitle,
          subtitle: data?.subtitle || this.defaultValues.subtitle,
          logoUrl: data?.logoUrl || '',
        });
        this.cdr.markForCheck();
      },
      error: () => {
        this.isLoading = false;
        this.loadError = true;
        this.toastr.error('تعذر تحميل إعدادات خدمة تدلل', 'خطأ');
        this.cdr.markForCheck();
      },
    });
  }

  resetDefaults(): void {
    this.form.patchValue(this.defaultValues);
    this.form.markAsDirty();
    this.cdr.markForCheck();
  }

  save(): void {
    if (this.form.invalid || this.isSaving) return;

    this.isSaving = true;
    const value: TedallalCardSetting = {
      enabled: !!this.form.value.enabled,
      sectionTitle: String(this.form.value.sectionTitle || '').trim() || this.defaultValues.sectionTitle,
      cardTitle: String(this.form.value.cardTitle || '').trim() || this.defaultValues.cardTitle,
      subtitle: String(this.form.value.subtitle || '').trim() || this.defaultValues.subtitle,
      logoUrl: String(this.form.value.logoUrl || '').trim(),
    };

    this.subs.sink = this.tedallalService.saveSettings(value).subscribe({
      next: () => {
        this.isSaving = false;
        this.toastr.success('تم حفظ إعدادات خدمة تدلل بنجاح', 'تم الحفظ');
        this.form.markAsPristine();
        this.cdr.markForCheck();
      },
      error: (err) => {
        this.isSaving = false;
        const msg = err?.error?.message || 'تعذر حفظ إعدادات خدمة تدلل';
        this.toastr.error(msg, 'خطأ');
        this.cdr.markForCheck();
      },
    });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
