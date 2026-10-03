import { Component, Input, OnDestroy, OnInit, Output, EventEmitter } from '@angular/core';
import { DomSanitizer, SafeUrl } from '@angular/platform-browser';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { Subject, Subscription, timer } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { SupportMessage, SupportMessageStatus, ErrandStatus, ErrandDriver } from '../../models/support-message.model';
import { SupportMessagesService } from '../../services/support-messages.service';
import { FilesService } from 'src/app/modules/shared/services/files.service';

@Component({
  selector: 'app-view-message-modal',
  templateUrl: './view-message-modal.component.html',
  styleUrls: ['./view-message-modal.component.scss'],
})
export class ViewMessageModalComponent implements OnInit, OnDestroy {
  @Input() message: SupportMessage;
  @Output() updated = new EventEmitter<void>();

  SupportMessageStatus = SupportMessageStatus;
  ErrandStatus = ErrandStatus;
  selectedStatus: SupportMessageStatus;
  adminNotes: string = '';
  isSaving: boolean = false;
  isLoadingMessage = false;
  itemPrice: number | null = null;
  deliveryFee: number | null = null;
  purchaseCost: number | null = null;
  receiptReference = '';
  driverUserId = '';
  customerReceived = false;
  cashCollected = false;
  deliveryCode = '';
  recoveryReason = '';
  refundAmount: number | null = null;
  returnReason = '';
  drivers: ErrandDriver[] = [];
  isRefreshingErrand = false;
  errandDriverEarning: number | null = null;
  acceptDriverSubsidy = false;
  private destroyed$ = new Subject<void>();

  get proposedDriverSubsidy(): number {
    return Math.max(0, Number(this.errandDriverEarning || 0) - Number(this.deliveryFee || 0));
  }

  get recordedOrderProfit(): number | null {
    if (this.message?.errandPurchaseCost == null || ![ErrandStatus.Purchased, ErrandStatus.DeliveryPending,
        ErrandStatus.Delivered].includes(this.message.errandStatus!)) return null;
    return this.errandTotal - Number(this.message.errandPurchaseCost) -
      Number(this.message.errandDriverEarning ?? this.message.errandDeliveryFee ?? 0);
  }

  get recordedOrderProfitAmount(): number {
    return Math.abs(this.recordedOrderProfit ?? 0);
  }

  get cleanExceptionMessage(): string {
    const raw = this.message?.errandLatestException || '';
    return raw.replace(/^EXCEPTION:\s*/i, '').trim();
  }

  get isErrandFinalized(): boolean {
    return [ErrandStatus.Delivered, ErrandStatus.Returned, ErrandStatus.Cancelled].includes(this.message?.errandStatus!);
  }

  get errandStatusText(): string {
    switch (this.message?.errandStatus) {
      case ErrandStatus.Submitted: return 'جديد – بانتظار التسعير';
      case ErrandStatus.Quoted: return 'بانتظار موافقة العميل على العرض';
      case ErrandStatus.Approved: return 'وافق العميل – بانتظار تعيين مندوب';
      case ErrandStatus.Assigned: return 'تم تعيين المندوب – بانتظار الشراء';
      case ErrandStatus.Purchased: return 'تم الشراء – بانتظار التسليم';
      case ErrandStatus.Delivered: return 'تم التسليم والتحصيل بنجاح';
      case ErrandStatus.PurchasePending: return 'تسجيل الشراء قيد الإكمال';
      case ErrandStatus.DeliveryPending: return 'تسجيل التسليم قيد الإكمال';
      case ErrandStatus.ReturnPending: return 'تسجيل الإرجاع قيد الإكمال';
      case ErrandStatus.Returned: return 'مرتجع';
      case ErrandStatus.Unavailable: return 'الغرض غير متوفر';
      case ErrandStatus.Cancelled: return 'أُلغي الطلب';
      case ErrandStatus.Declined: return 'رفض العميل العرض';
      default: return 'غير معروف';
    }
  }

  get errandStatusClass(): string {
    switch (this.message?.errandStatus) {
      case ErrandStatus.Submitted: return 'errand-status-tag--amber';
      case ErrandStatus.Quoted: return 'errand-status-tag--blue';
      case ErrandStatus.Approved: return 'errand-status-tag--green';
      case ErrandStatus.Assigned:
      case ErrandStatus.Purchased: return 'errand-status-tag--orange';
      case ErrandStatus.Delivered: return 'errand-status-tag--emerald';
      case ErrandStatus.Unavailable:
      case ErrandStatus.Cancelled:
      case ErrandStatus.Declined: return 'errand-status-tag--danger';
      default: return 'errand-status-tag--neutral';
    }
  }
  private quoteExpiryTimer: ReturnType<typeof setTimeout> | null = null;
  private quoteExpiryNow = Date.now();
  private pollSubscription?: Subscription;
  private refreshSubscription?: Subscription;
  private receiptSubscription?: Subscription;
  private receiptPhotoKey = '';
  receiptPhotoUrl: string | null = null;
  trustedReceiptPhotoUrl: SafeUrl | null = null;
  receiptPhotoError = false;

  get isErrand(): boolean {
    return this.message?.errandStatus !== null && this.message?.errandStatus !== undefined;
  }

  get errandTotal(): number {
    return Number(this.message?.errandItemPrice || 0) + Number(this.message?.errandDeliveryFee || 0);
  }

  get proposedTotal(): number {
    return Number(this.itemPrice || 0) + Number(this.deliveryFee || 0);
  }

  get hasActiveQuote(): boolean {
    const expiresAt = this.message?.errandQuoteExpiresAt;
    return this.message?.errandStatus === ErrandStatus.Quoted && !!expiresAt &&
      new Date(expiresAt).getTime() > this.quoteExpiryNow;
  }

  private get mapUrls(): string[] {
    const links: string[] = [];
    const expression = /https:\/\/www\.google\.com\/maps\?q=-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?/g;
    let match: RegExpExecArray | null;
    while ((match = expression.exec(this.message?.message || '')) !== null) {
      links.push(match[0]);
    }
    return links;
  }

  get deliveryMapUrl(): string | null {
    const links = this.mapUrls;
    return links.length ? links[links.length - 1] : null;
  }

  get pickupMapUrl(): string | null {
    const links = this.mapUrls;
    return links.length > 1 ? links[0] : null;
  }

  constructor(
    public modal: NgbActiveModal,
    private supportService: SupportMessagesService,
    private toastr: ToastrService,
    public filesService: FilesService,
    private sanitizer: DomSanitizer
  ) {}

  ngOnInit(): void {
    if (this.message) {
      this.selectedStatus = this.message.status;
      this.adminNotes = this.message.adminNotes || '';
      this.itemPrice = this.message.errandItemPrice ?? null;
      this.deliveryFee = this.message.errandDeliveryFee ?? null;
      this.purchaseCost = this.message.errandPurchaseCost ?? null;
      this.receiptReference = this.message.errandReceiptReference || '';
      this.driverUserId = this.message.errandDriverUserId || '';
      this.refundAmount = this.message.errandRefundAmount ?? null;
      this.returnReason = this.message.errandReturnReason || '';
      this.loadReceiptPhoto();
      this.scheduleQuoteExpiryRefresh();
      if (!this.isErrand) {
        this.isLoadingMessage = true;
        this.supportService.getMessage(this.message.id).pipe(takeUntil(this.destroyed$)).subscribe({
          next: message => {
            this.message = message;
            this.selectedStatus = message.status;
            this.adminNotes = message.adminNotes || '';
            this.isLoadingMessage = false;
            this.updated.emit();
          },
          error: () => { this.isLoadingMessage = false; this.toastr.error('تعذر تحميل تفاصيل الرسالة'); }
        });
      }
      if (this.isErrand) {
        this.pollSubscription = timer(10000, 10000).subscribe(() => {
          if (!this.isSaving) this.refreshErrand(true);
        });
        this.supportService.getErrandDriverEarning().pipe(takeUntil(this.destroyed$)).subscribe({
          next: (setting) => this.errandDriverEarning = Number(setting?.amount ?? 0),
          error: () => this.errandDriverEarning = null,
        });
        this.supportService.getErrandDrivers().pipe(takeUntil(this.destroyed$)).subscribe({
          next: (drivers) => this.drivers = drivers,
          error: () => this.toastr.error('تعذر تحميل قائمة المندوبين'),
        });
      }
    }
  }

  setStatus(status: SupportMessageStatus): void {
    if (this.isSaving || this.isLoadingMessage) return;
    this.selectedStatus = status;
  }

  ngOnDestroy(): void {
    this.destroyed$.next();
    this.destroyed$.complete();
    if (this.quoteExpiryTimer) clearTimeout(this.quoteExpiryTimer);
    this.pollSubscription?.unsubscribe();
    this.refreshSubscription?.unsubscribe();
    this.receiptSubscription?.unsubscribe();
    if (this.receiptPhotoUrl) URL.revokeObjectURL(this.receiptPhotoUrl);
  }

  private loadReceiptPhoto(): void {
    const token = this.message?.errandReceiptPhotoToken;
    const key = token ? `${this.message.id}:${token}` : '';
    if (key === this.receiptPhotoKey) return;
    this.receiptPhotoKey = key;
    this.receiptSubscription?.unsubscribe();
    if (this.receiptPhotoUrl) URL.revokeObjectURL(this.receiptPhotoUrl);
    this.receiptPhotoUrl = null;
    this.trustedReceiptPhotoUrl = null;
    this.receiptPhotoError = false;
    if (!key) return;
    // HttpClient attaches the admin bearer token; image tags cannot do that.
    this.receiptSubscription = this.filesService.getErrandReceipt(this.message.id).subscribe({
      next: (blob) => {
        if (!blob || blob.size === 0) {
          this.receiptPhotoError = true;
          return;
        }
        this.receiptPhotoUrl = URL.createObjectURL(blob);
        // The URL is a browser-created object URL for the authenticated receipt blob.
        this.trustedReceiptPhotoUrl = this.sanitizer.bypassSecurityTrustUrl(this.receiptPhotoUrl);
      },
      error: () => this.receiptPhotoError = true,
    });
  }

  onReceiptPhotoError(): void {
    this.receiptPhotoError = true;
    if (this.receiptPhotoUrl) {
      URL.revokeObjectURL(this.receiptPhotoUrl);
      this.receiptPhotoUrl = null;
      this.trustedReceiptPhotoUrl = null;
    }
  }

  private scheduleQuoteExpiryRefresh(): void {
    if (this.quoteExpiryTimer) clearTimeout(this.quoteExpiryTimer);
    this.quoteExpiryNow = Date.now();
    const expiresAt = this.message?.errandQuoteExpiresAt;
    if (this.message?.errandStatus !== ErrandStatus.Quoted || !expiresAt) return;
    const delay = new Date(expiresAt).getTime() - this.quoteExpiryNow + 50;
    if (delay > 0) {
      this.quoteExpiryTimer = setTimeout(() => {
        this.quoteExpiryNow = Date.now();
        this.quoteExpiryTimer = null;
      }, delay);
    }
  }

  refreshErrand(silent = false): void {
    if (!this.message || this.isRefreshingErrand) return;
    this.isRefreshingErrand = true;
    this.refreshSubscription = this.supportService.getMessage(this.message.id).subscribe({
      next: (message) => {
        if (silent && this.isSaving) { this.isRefreshingErrand = false; return; }
        const keepPurchaseDraft = silent && this.purchaseCost !== (this.message.errandPurchaseCost ?? null);
        const keepReceiptDraft = silent && this.receiptReference !== (this.message.errandReceiptReference || '');
        this.message = message;
        this.loadReceiptPhoto();
        this.scheduleQuoteExpiryRefresh();
        if (!keepPurchaseDraft) this.purchaseCost = message.errandPurchaseCost ?? null;
        if (!keepReceiptDraft) this.receiptReference = message.errandReceiptReference || '';
        this.isRefreshingErrand = false;
      },
      error: () => {
        this.isRefreshingErrand = false;
        if (!silent) this.toastr.error('تعذر تحديث بيانات الطلب');
      },
    });
  }

  saveChanges(): void {
    if (!this.message || this.isErrand || this.isSaving || this.isLoadingMessage) return;
    this.isSaving = true;

    this.supportService
      .updateStatus(this.message.id, this.selectedStatus, this.adminNotes)
      .pipe(takeUntil(this.destroyed$))
      .subscribe({
        next: () => {
          this.isSaving = false;
          this.message.status = this.selectedStatus;
          this.message.adminNotes = this.adminNotes;
          this.toastr.success('تم تحديث حالة الرسالة بنجاح', 'تم الحفظ');
          this.updated.emit();
          this.modal.close(true);
        },
        error: () => {
          this.isSaving = false;
          this.toastr.error('تعذر حفظ التعديلات، يرجى المحاولة لاحقاً', 'خطأ');
        },
      });
  }

  runErrandAction(action: 'quote' | 'assign' | 'purchase' | 'deliver' | 'cancel' | 'return'): void {
    if (!this.message || this.isSaving) return;
    const id = this.message.id;
    let operation;
    if (action === 'quote') {
      if (this.hasActiveQuote) {
        this.toastr.info('يوجد عرض سعر صالح بانتظار موافقة العميل.');
        return;
      }
      if (this.itemPrice === null || this.itemPrice <= 0 || this.deliveryFee === null || this.deliveryFee < 0) {
        this.toastr.error('أدخل سعر الغرض وأجرة التوصيل');
        return;
      }
      if (this.errandDriverEarning === null) {
        this.toastr.error('انتظر تحميل أجر المندوب قبل إرسال العرض.');
        return;
      }
      if (this.proposedDriverSubsidy > 0 && !this.acceptDriverSubsidy) {
        this.toastr.error('أكد قبول دعم أجر المندوب من الشركة قبل إرسال العرض.');
        return;
      }
      operation = this.supportService.quoteErrand(id, Number(this.itemPrice), Number(this.deliveryFee), this.acceptDriverSubsidy);
    } else if (action === 'assign') {
      if (!this.driverUserId) { this.toastr.error('اختر مندوباً'); return; }
      operation = this.supportService.assignErrand(id, this.driverUserId);
    } else if (action === 'purchase') {
      if (this.purchaseCost === null || this.purchaseCost <= 0 ||
          (!this.receiptReference.trim() && !this.message.errandReceiptPhotoToken)) {
        this.toastr.error('أدخل تكلفة الشراء ورقم الإيصال أو أرفق صورة الفاتورة');
        return;
      }
      operation = this.supportService.purchaseErrand(id, Number(this.purchaseCost), this.receiptReference.trim());
    } else if (action === 'deliver') {
      if (!this.customerReceived || !this.cashCollected || !/^\d{6}$/.test(this.deliveryCode) || !this.recoveryReason.trim()) {
        this.toastr.error('أدخل سبب الإجراء الاستثنائي، وتأكد من التسليم والتحصيل والرمز');
        return;
      }
      operation = this.supportService.deliverErrand(id, this.errandTotal, this.deliveryCode, this.recoveryReason.trim());
    } else if (action === 'cancel') {
      if (!this.returnReason.trim()) { this.toastr.error('اكتب سبب الإلغاء'); return; }
      operation = this.supportService.cancelErrand(id, this.returnReason.trim());
    } else {
      if (this.refundAmount === null || this.refundAmount < 0 || !this.returnReason.trim()) {
        this.toastr.error('أدخل المبلغ المسترد وسبب الإرجاع'); return;
      }
      operation = this.supportService.returnErrand(id, Number(this.refundAmount), this.returnReason.trim());
    }
    // A poll started before this action must not overwrite its newer result.
    this.refreshSubscription?.unsubscribe();
    this.isRefreshingErrand = false;
    this.isSaving = true;
    operation.pipe(takeUntil(this.destroyed$)).subscribe({
      next: () => this.supportService.getMessage(id).pipe(takeUntil(this.destroyed$)).subscribe({
        next: (message) => {
          this.message = message;
          this.loadReceiptPhoto();
          this.itemPrice = message.errandItemPrice ?? null;
          this.deliveryFee = message.errandDeliveryFee ?? null;
          this.purchaseCost = message.errandPurchaseCost ?? null;
          this.receiptReference = message.errandReceiptReference || '';
          this.driverUserId = message.errandDriverUserId || '';
          this.scheduleQuoteExpiryRefresh();
          this.isSaving = false;
          this.updated.emit();
          this.toastr.success('تم تحديث الطلب');
        },
        error: () => {
          this.isSaving = false;
          this.updated.emit();
          this.toastr.success('تم التحديث. أعد فتح الطلب لعرض حالته.');
        },
      }),
      error: (error) => {
        this.isSaving = false;
        const errors = error?.error?.errors;
        const explanation = Array.isArray(errors) ? errors.find((entry) => typeof entry === 'string') : null;
        this.toastr.error(explanation || error?.error?.message || error?.error?.error || 'تعذر تحديث الطلب. تحقق من الحالة والمبالغ.');
      },
    });
  }

  openWhatsApp(): void {
    if (!this.message?.senderPhone) return;
    let phone = this.message.senderPhone.replace(/\D/g, '');
    if (phone.startsWith('09')) {
      phone = '963' + phone.substring(1);
    } else if (phone.startsWith('00')) {
      phone = phone.substring(2);
    } else if (!phone.startsWith('963') && phone.length === 9) {
      phone = '963' + phone;
    }
    const text = encodeURIComponent(
      `مرحباً بك ${this.message.senderName}، نتواصل معك من فريق دعم تطبيق جيتك بخصوص استفسارك.`
    );
    window.open(`https://wa.me/${phone}?text=${text}`, '_blank');
  }

  callPhone(): void {
    if (!this.message?.senderPhone) return;
    window.open(`tel:${this.message.senderPhone}`, '_self');
  }
}
