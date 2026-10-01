import { Component, OnDestroy, OnInit } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { ToastrService } from 'ngx-toastr';
import { CampaignAudiences, CampaignRequest } from '../../models/notification.model';
import { NotificationsService } from '../../services/notifications.service';

@Component({
  selector: 'app-notifications-create',
  templateUrl: './notifications-create.component.html',
  styleUrls: ['./notifications-create.component.scss'],
})
export class NotificationsCreateComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  formGroup: UntypedFormGroup;
  audiences: CampaignAudiences | null = null;
  statsLoading = true;
  isSending = false;
  confirming = false;
  sendError = '';

  readonly targets = [
    { value: 'customers', label: 'تطبيق العملاء', icon: 'fa-shopping-bag', color: 'orange' },
    { value: 'delivery', label: 'تطبيق التوصيل', icon: 'fa-motorcycle', color: 'green' },
    { value: 'warehouse', label: 'تطبيق التاجر', icon: 'fa-store', color: 'orange' },
  ];

  constructor(
    private notificationsService: NotificationsService,
    private fb: UntypedFormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.formGroup = this.fb.group({
      target: ['customers', Validators.required],
      titleAr: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(100)]],
      textAr: ['', [Validators.required, Validators.minLength(5), Validators.maxLength(500)]],
      image: [''],
      destination: ['home'],
    });
    this.subs.sink = this.formGroup.valueChanges.subscribe(() => {
      this.confirming = false;
      this.sendError = '';
    });
    this.loadAudiences();
  }

  loadAudiences(): void {
    this.statsLoading = true;
    this.subs.sink = this.notificationsService.getCampaignAudiences().subscribe({
      next: (audiences) => {
        this.audiences = audiences;
        this.statsLoading = false;
      },
      error: () => {
        this.statsLoading = false;
        this.sendError = 'تعذر التحقق من جاهزية خدمة الإشعارات. أعد المحاولة.';
      },
    });
  }

  selectTarget(target: CampaignRequest['target']): void {
    this.formGroup.patchValue({ target, destination: target === 'customers' ? 'home' : 'orders' });
  }

  get selectedTarget(): CampaignRequest['target'] {
    return this.formGroup?.get('target')?.value || 'customers';
  }

  get targetCount(): number {
    return this.audiences?.[this.selectedTarget] ?? 0;
  }

  getAudienceCount(target: string): number {
    if (target === 'customers' || target === 'delivery' || target === 'warehouse') {
      return this.audiences?.[target] ?? 0;
    }
    return 0;
  }

  get targetLabel(): string {
    return this.targets.find((target) => target.value === this.selectedTarget)?.label || '';
  }

  get titlePreview(): string {
    return this.formGroup?.get('titleAr')?.value?.trim() || 'عنوان الإشعار';
  }

  get bodyPreview(): string {
    return this.formGroup?.get('textAr')?.value?.trim() || 'سيظهر نص الإشعار هنا كما سيراه مستخدم التطبيق.';
  }

  applyPreset(preset: 'offer' | 'update' | 'orders'): void {
    const examples = {
      offer: { titleAr: 'عروض جديدة في جيتك ماركت', textAr: 'تصفح أحدث المنتجات والعروض المتاحة الآن في التطبيق.' },
      update: { titleAr: 'تنبيه مهم من جيتك', textAr: 'لدينا تحديث مهم لك. افتح التطبيق للاطلاع على التفاصيل.' },
      orders: { titleAr: 'طلبات جديدة بانتظارك', textAr: 'افتح التطبيق وراجع الطلبات المتاحة الآن.' },
    };
    this.formGroup.patchValue(examples[preset]);
  }

  onFileUploaded(filesIds: string[]): void {
    this.formGroup.patchValue({ image: filesIds[0] || '' });
  }

  onFileDelete(): void {
    this.formGroup.patchValue({ image: '' });
  }

  reviewSend(): void {
    this.formGroup.markAllAsTouched();
    const title = this.formGroup.get('titleAr')?.value?.trim() || '';
    const body = this.formGroup.get('textAr')?.value?.trim() || '';
    if (this.formGroup.invalid || title.length < 3 || body.length < 5) return;
    if (!this.audiences?.pushConfigured) {
      this.sendError = 'إرسال الإشعارات غير مهيأ على الخادم. يرجى إعداد Firebase أولاً.';
      return;
    }
    this.confirming = true;
  }

  send(): void {
    if (!this.confirming || this.isSending || this.formGroup.invalid || !this.audiences?.pushConfigured) return;
    const request: CampaignRequest = {
      ...this.formGroup.value,
      titleAr: this.formGroup.get('titleAr')?.value.trim(),
      textAr: this.formGroup.get('textAr')?.value.trim(),
    };
    this.isSending = true;
    this.sendError = '';
    this.subs.sink = this.notificationsService.sendCampaign(request).subscribe({
      next: (result) => {
        this.isSending = false;
        if (result.acceptedLanguages > 0) {
          this.toasterService.success(`قبلت Firebase الإرسال إلى ${this.targetLabel}. تم حفظ الإشعار لـ ${result.recipientAccounts} حساب.`);
          if (result.failedLanguages > 0) {
            this.toasterService.warning(this.describeFirebaseFailure(result.failureCode));
          }
          this.modal.close(result);
        } else {
          this.confirming = false;
          this.sendError = result.historyRetained
            ? `${this.describeFirebaseFailure(result.failureCode)} تعذر تنظيف سجل الإشعار تلقائيًا؛ حدّث سجل الإشعارات قبل إعادة المحاولة.`
            : `${this.describeFirebaseFailure(result.failureCode)} لم يُحفظ الإشعار في سجل التطبيق؛ أصلح إعداد Firebase ثم أعد المحاولة.`;
        }
      },
      error: (error) => {
        this.isSending = false;
        this.confirming = false;
        this.sendError = error?.error?.message || 'تعذر إرسال الإشعار. تحقق من الاتصال وحاول مجددًا.';
      },
    });
  }

  private describeFirebaseFailure(code?: string): string {
    switch (code) {
      case 'SenderIdMismatch':
        return 'إعدادات Firebase في التطبيقات لا تطابق مشروع Firebase الذي يستخدمه الخادم.';
      case 'ThirdPartyAuthError':
        return 'تعذر التحقق من إعدادات APNs لتطبيق iOS في Firebase.';
      case 'InvalidArgument':
        return 'رفض Firebase بيانات الإشعار. راجع العنوان والنص والرابط أو الصورة.';
      case 'QuotaExceeded':
        return 'تم تجاوز حصة الإرسال في Firebase. انتظر ثم أعد المحاولة.';
      case 'Unavailable':
      case 'Internal':
        return 'خدمة Firebase غير متاحة مؤقتًا. أعد المحاولة بعد قليل.';
      case 'Unregistered':
        return 'رمز تسجيل الجهاز غير صالح؛ يجب على التطبيق تحديث تسجيله في Firebase.';
      default:
        return 'تعذر على الخادم إرسال الإشعار إلى Firebase. راجع سجل أخطاء الخادم لمعرفة السبب الدقيق.';
    }
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
