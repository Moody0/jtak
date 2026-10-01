import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { AdminAuditLog } from '../../models/audit-log.model';

export interface FieldDiff {
  field: string;
  label: string;
  beforeValue: any;
  afterValue: any;
  changed: boolean;
}

@Component({
  selector: 'app-audit-log-details-modal',
  templateUrl: './audit-log-details-modal.component.html',
  styleUrls: ['./audit-log-details-modal.component.scss'],
})
export class AuditLogDetailsModalComponent implements OnInit {
  @Input() log: AdminAuditLog;

  formattedBeforeState: string | null = null;
  formattedAfterState: string | null = null;
  fieldDiffs: FieldDiff[] = [];
  activeDiffTab: 'table' | 'side-by-side' | 'before' | 'after' = 'table';

  private fieldLabels: Record<string, string> = {
    id: 'المعرّف',
    Id: 'المعرّف',
    title: 'الاسم / العنوان',
    Title: 'الاسم / العنوان',
    fullName: 'الاسم الكامل',
    FullName: 'الاسم الكامل',
    phoneNumber: 'رقم الهاتف',
    PhoneNumber: 'رقم الهاتف',
    email: 'البريد الإلكتروني',
    Email: 'البريد الإلكتروني',
    role: 'الدور / الصلاحية',
    Role: 'الدور / الصلاحية',
    roles: 'الأدوار',
    Roles: 'الأدوار',
    isActive: 'حالة التفعيل',
    IsActive: 'حالة التفعيل',
    active: 'حالة التفعيل',
    Active: 'حالة التفعيل',
    price: 'السعر (ل.س)',
    Price: 'السعر (ل.س)',
    priceUsd: 'السعر ($)',
    PriceUsd: 'السعر ($)',
    discount: 'الخصم',
    Discount: 'الخصم',
    productCategoryId: 'معرّف التصنيف',
    ProductCategoryId: 'معرّف التصنيف',
    merchantId: 'معرّف التاجر',
    MerchantId: 'معرّف التاجر',
    driverId: 'معرّف السائق',
    DriverId: 'معرّف السائق',
    driverName: 'اسم السائق',
    DriverName: 'اسم السائق',
    usdToSypExchangeRate: 'سعر صرف الدولار (ل.س)',
    UsdToSypExchangeRate: 'سعر صرف الدولار (ل.س)',
    deletionDate: 'تاريخ الأرشفة',
    DeletionDate: 'تاريخ الأرشفة',
    deletedBy: 'المسؤول المؤرشف',
    DeletedBy: 'المسؤول المؤرشف',
    deleteReason: 'سبب الحذف / الأرشفة',
    DeleteReason: 'سبب الحذف / الأرشفة',
    orderStatus: 'حالة الطلب',
    OrderStatus: 'حالة الطلب',
    deliveredAt: 'تاريخ التسليم',
    DeliveredAt: 'تاريخ التسليم',
    deliveryFee: 'أجور التوصيل',
    DeliveryFee: 'أجور التوصيل',
    profitOutOfMerchantPricePercent: 'نسبة العمولة (%)',
    ProfitOutOfMerchantPricePercent: 'نسبة العمولة (%)',
    address: 'العنوان',
    Address: 'العنوان',
    phone1: 'الهاتف 1',
    Phone1: 'الهاتف 1',
    phone2: 'الهاتف 2',
    Phone2: 'الهاتف 2',
    notes: 'ملاحظات',
    Notes: 'ملاحظات',
    reason: 'السبب',
    Reason: 'السبب',
    cashResolutionMode: 'طريقة معالجة النقد',
    CashResolutionMode: 'طريقة معالجة النقد',
    homeFeaturedCategoryIds: 'أقسام الواجهة المميزة',
    HomeFeaturedCategoryIds: 'أقسام الواجهة المميزة',
    homeFeaturedProductIds: 'منتجات الواجهة المميزة',
    HomeFeaturedProductIds: 'منتجات الواجهة المميزة',
    batchId: 'معرّف الدفعة',
    BatchId: 'معرّف الدفعة',
    captainId: 'معرّف الكابتن',
    CaptainId: 'معرّف الكابتن',
    captainName: 'اسم الكابتن',
    CaptainName: 'اسم الكابتن',
    compensationType: 'طريقة الاحتساب',
    CompensationType: 'طريقة الاحتساب',
    compensationTypeDisplay: 'نموذج أجر الكابتن',
    CompensationTypeDisplay: 'نموذج أجر الكابتن',
    handledByAdminName: 'المشرف المعتمد',
    HandledByAdminName: 'المشرف المعتمد',
    netDueToCompany: 'المبلغ المستحق للشركة (ل.س)',
    NetDueToCompany: 'المبلغ المستحق للشركة (ل.س)',
    totalOrders: 'إجمالي الطلبات',
    TotalOrders: 'إجمالي الطلبات',
    totalCashCollected: 'المحصل نقداً (ل.س)',
    TotalCashCollected: 'المحصل نقداً (ل.س)',
    totalEarnings: 'استحقاق الكابتن (ل.س)',
    TotalEarnings: 'استحقاق الكابتن (ل.س)',
    status: 'الحالة',
    Status: 'الحالة'
  };

  getModuleLabel(module?: string): string {
    const labels: { [key: string]: string } = {
      Orders: 'الطلبات',
      Settlements: 'التسويات والمالية',
      Merchants: 'التجار والشركاء',
      Users: 'المستخدمون والمناديب',
      Catalog: 'الكتالوج والمنتجات',
      Banners: 'الإعلانات والبنرات',
      Settings: 'إعدادات النظام',
      Auth: 'المصادقة والدخول',
      System: 'النظام',
    };
    return labels[module || ''] || module || '—';
  }

  getActionLabel(action?: string): string {
    const labels: { [key: string]: string } = {
      Create: 'إنشاء',
      Update: 'تعديل',
      Delete: 'حذف',
      Archive: 'أرشفة',
      Restore: 'استعادة',
      Approve: 'موافقة وقبول',
      Reject: 'رفض',
      Pay: 'صرف مالي',
      Deliver: 'تسليم',
      AssignDriver: 'تعيين مندوب',
      Login: 'تسجيل الدخول',
      Logout: 'تسجيل الخروج',
      Execute: 'تنفيذ',
      ConfirmCaptainSettlement: 'اعتماد تسوية الكابتن',
      BatchSettlement: 'تسوية مجمعة',
      DisableUser: 'تعطيل مستخدم',
      EnableUser: 'تفعيل مستخدم',
      ResetPassword: 'إعادة تعيين كلمة المرور',
      ChangeStatus: 'تغيير الحالة',
    };
    return labels[action || ''] || action || '—';
  }

  getEntityLabel(entityType?: string): string {
    const labels: { [key: string]: string } = {
      Order: 'طلب',
      Merchant: 'متجر',
      Product: 'منتج',
      User: 'مستخدم',
      Delivery: 'مندوب توصيل',
      Driver: 'مندوب توصيل',
      SettlementRequest: 'طلب تسوية',
      CaptainSettlementBatch: 'دفعة تسوية كابتن',
      CaptainSettlement: 'تسوية كابتن',
      Payment: 'دفعة مالية',
      Banner: 'إعلان',
      Category: 'تصنيف',
      Settings: 'إعدادات',
      Auth: 'جلسة دخول',
    };
    return labels[entityType || ''] || entityType || '—';
  }

  getResultLabel(result?: string): string {
    if (!result) return '—';
    const r = result.toLowerCase();
    if (r === 'success') return 'ناجحة';
    if (r === 'failure' || r === 'failed') return 'فاشلة';
    if (r === 'warning') return 'تحذير';
    if (r === 'forbidden') return 'مرفوضة / صلاحيات';
    return result;
  }

  getAdminInitials(name?: string): string {
    const trimmed = (name || '').trim();
    if (!trimmed) return 'A';
    const parts = trimmed.split(' ').filter(Boolean);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed.slice(0, 2).toUpperCase();
  }

  constructor(
    public activeModal: NgbActiveModal,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    if (this.log) {
      this.formattedBeforeState = this.formatJson(this.log.beforeStateJson);
      this.formattedAfterState = this.formatJson(this.log.afterStateJson);
      this.computeFieldDiffs();
      if (this.fieldDiffs.length === 0) {
        this.activeDiffTab = 'side-by-side';
      }
    }
  }

  computeFieldDiffs(): void {
    const beforeObj = this.parseJsonSafe(this.log?.beforeStateJson);
    const afterObj = this.parseJsonSafe(this.log?.afterStateJson);

    if (!beforeObj && !afterObj) {
      this.fieldDiffs = [];
      return;
    }

    const allKeys = new Set<string>([
      ...Object.keys(beforeObj || {}),
      ...Object.keys(afterObj || {})
    ]);

    const diffs: FieldDiff[] = [];
    for (const key of allKeys) {
      const beforeVal = beforeObj ? beforeObj[key] : undefined;
      const afterVal = afterObj ? afterObj[key] : undefined;
      const changed = JSON.stringify(beforeVal) !== JSON.stringify(afterVal);

      diffs.push({
        field: key,
        label: this.fieldLabels[key] || key,
        beforeValue: this.formatValue(beforeVal),
        afterValue: this.formatValue(afterVal),
        changed
      });
    }

    // Sort: changed fields first
    this.fieldDiffs = diffs.sort((a, b) => {
      if (a.changed && !b.changed) return -1;
      if (!a.changed && b.changed) return 1;
      return a.label.localeCompare(b.label);
    });
  }

  parseJsonSafe(raw: string | undefined | null): any {
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }

  formatValue(val: any): string {
    if (val === null || val === undefined) return '—';
    if (typeof val === 'boolean') return val ? 'نشط / نعم' : 'معطل / لا';
    if (Array.isArray(val)) return val.length === 0 ? 'فارغ' : JSON.stringify(val);
    if (typeof val === 'object') return JSON.stringify(val);
    return String(val);
  }

  formatJson(raw: string | undefined | null): string | null {
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw);
      return JSON.stringify(parsed, null, 2);
    } catch {
      return raw;
    }
  }

  copyJson(jsonText: string | null, label: string): void {
    if (!jsonText) return;
    navigator.clipboard.writeText(jsonText).then(() => {
      this.toastr.success(`تم نسخ بيانات ${label} إلى الحافظة.`);
    });
  }

  dismiss(): void {
    this.activeModal.dismiss();
  }
}
