import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { TedallalSettingsService } from './services/tedallal-settings.service';
import { TedallalCardSetting } from './models/tedallal-settings.model';
import { HttpEventType, HttpResponse } from '@angular/common/http';
import { finalize } from 'rxjs/operators';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { wasHttpErrorNotified } from 'src/app/interceptors/http-error-notifications';

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
  failedLogoUrl = '';
  isUploading = false;
  uploadProgress = 0;
  private subs = new SubSink();

  readonly defaultValues: TedallalCardSetting = {
    enabled: true,
    sectionTitle: 'خدمة تدلل',
    cardTitle: 'طلبات خاصة وعروض الأسعار',
    subtitle: 'اطلب ما تحتاجه، نراجع طلبك ونرسل لك السعر للموافقة',
    logoUrl: '',
  };

  constructor(
    private fb: UntypedFormBuilder,
    private tedallalService: TedallalSettingsService,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef,
    private filesService: FilesService
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
    if (this.isLoading || this.isSaving || this.isUploading) return;
    this.failedLogoUrl = '';
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
          subtitle: !data?.subtitle || data.subtitle.trim() === 'اطلب أي شيء غير متوفر في التطبيق مع عروض أسعار فورية'
            ? this.defaultValues.subtitle : data.subtitle,
          logoUrl: data?.logoUrl || '',
        });
        this.cdr.markForCheck();
      },
      error: (error) => {
        this.isLoading = false;
        this.loadError = true;
        if (!wasHttpErrorNotified(error)) this.toastr.error('تعذر تحميل إعدادات خدمة تدلل', 'خطأ');
        this.cdr.markForCheck();
      },
    });
  }

  resetDefaults(): void {
    if (this.isLoading || this.isSaving || this.isUploading || !this.hasLoaded || this.loadError) return;
    this.failedLogoUrl = '';
    this.form.patchValue(this.defaultValues);
    this.form.markAsDirty();
    this.cdr.markForCheck();
  }

  onLogoPreviewError(event: Event): void {
    this.failedLogoUrl = (event.target as HTMLImageElement).getAttribute('src') || '';
    this.cdr.markForCheck();
  }

  uploadLogo(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file || this.isUploading || this.isSaving || this.isLoading || !this.hasLoaded || this.loadError) return;
    if (!/\.(png|jpe?g|webp)$/i.test(file.name) ||
        (file.type && !['image/png', 'image/jpeg', 'image/webp'].includes(file.type))) {
      this.toastr.error('اختر صورة بصيغة PNG أو JPG أو WebP.');
      return;
    }
    if (file.size === 0 || file.size > 5 * 1024 * 1024) {
      this.toastr.error('اختر صورة غير فارغة بحجم لا يتجاوز 5 ميجابايت.');
      return;
    }
    const data = new FormData();
    data.append('file[]', file);
    this.isUploading = true;
    this.uploadProgress = 0;
    this.subs.sink = this.filesService.uploadFile(data, false).pipe(
      finalize(() => {
        this.isUploading = false;
        this.cdr.markForCheck();
      })
    ).subscribe({
      next: (uploadEvent) => {
        if (uploadEvent.type === HttpEventType.UploadProgress) {
          this.uploadProgress = uploadEvent.total
            ? Math.round(100 * uploadEvent.loaded / uploadEvent.total) : 0;
        } else if (uploadEvent instanceof HttpResponse) {
          const token = typeof uploadEvent.body === 'string' ? uploadEvent.body.split(',')[0].trim() : '';
          if (!token) {
            this.toastr.error('تعذر الحصول على الصورة المرفوعة. أعد المحاولة.');
            return;
          }
          this.failedLogoUrl = '';
          // Store a public download URL, which the customer app already supports.
          this.form.patchValue({ logoUrl: this.filesService.downloadFile(token) });
          this.form.markAsDirty();
          this.toastr.success('تم رفع الصورة. اضغط حفظ لتظهر في التطبيق.');
        }
        this.cdr.markForCheck();
      },
      error: (error) => {
        if (!wasHttpErrorNotified(error)) this.toastr.error('تعذر رفع الصورة. أعد المحاولة.');
      },
    });
  }

  removeLogo(): void {
    if (this.isUploading || this.isSaving || this.isLoading || !this.hasLoaded || this.loadError) return;
    this.failedLogoUrl = '';
    this.form.patchValue({ logoUrl: '' });
    this.form.markAsDirty();
    this.cdr.markForCheck();
  }

  save(): void {
    if (this.form.invalid || this.isSaving || this.isUploading || this.isLoading || !this.hasLoaded || this.loadError) return;

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
        if (!wasHttpErrorNotified(err)) this.toastr.error(msg, 'خطأ');
        this.cdr.markForCheck();
      },
    });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
