import { Component, OnInit, TemplateRef } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormBuilder, Validators } from '@angular/forms';
import { NgbModal, NgbModalRef } from '@ng-bootstrap/ng-bootstrap';
import { TranslateService } from '@ngx-translate/core';
import { finalize } from 'rxjs';
import { environment } from 'src/environments/environment';

interface StaffRole { id: string; name: string; description: string; permissions: string[]; accountCount: number; }
interface StaffAccount { id: string; fullName: string; email: string; roleId: string | null; isActive: boolean; isSuperAdmin: boolean; lastLoginDate: string | null; }
interface StaffData { sections: string[]; roles: StaffRole[]; accounts: StaffAccount[]; }

@Component({ selector: 'app-staff', templateUrl: './staff.component.html', styleUrls: ['./staff.component.scss'] })
export class StaffComponent implements OnInit {
  private readonly url = `${environment.apiUrl}/Admin/Staff`;
  data: StaffData = { sections: [], roles: [], accounts: [] };
  tab: 'accounts' | 'roles' = 'accounts';
  loading = true;
  saving = false;
  query = '';
  error = '';
  modalError = '';
  success = '';
  editingId: string | null = null;
  selectedPermissions = new Set<string>();
  deletingRole: StaffRole | null = null;
  private modalRef: NgbModalRef | null = null;
  roleForm = this.fb.nonNullable.group({ name: ['', [Validators.required, Validators.maxLength(80)]], description: ['', Validators.maxLength(300)], template: ['custom'] });
  accountForm = this.fb.nonNullable.group({ fullName: ['', [Validators.required, Validators.maxLength(120)]], email: ['', [Validators.required, Validators.email, Validators.maxLength(254)]], roleId: ['', Validators.required], password: [''], isActive: [true] });
  constructor(private http: HttpClient, private fb: FormBuilder, private modals: NgbModal, private translate: TranslateService) {}
  ngOnInit(): void { this.load(); }
  t(ar: string, en: string): string { return this.translate.currentLang === 'ar' ? ar : en; }
  sectionName(section: string): string {
    const names: Record<string, [string, string]> = {
      dashboard: ['الصفحة الرئيسية والتقارير', 'Overview & reports'], orders: ['الطلبات والتوصيل وخدمة تدلل', 'Orders, delivery & Tedallal'],
      support: ['خدمة العملاء والتقييمات', 'Customer support & reviews'], catalog: ['المنتجات والتجار والمتاجر', 'Products & merchants'],
      storefront: ['واجهة تطبيق العملاء', 'Customer app content'], finance: ['المالية والتسويات', 'Finance & settlements'],
      users: ['مستخدمو التطبيقات والمناديب', 'App users & couriers'], communications: ['الإشعارات والحملات', 'Notifications & campaigns'],
      settings: ['إعدادات النظام والصفحات', 'System settings & pages'], audit: ['سجل العمليات', 'Audit log'],
    };
    return names[section] ? this.t(...names[section]) : section;
  }
  get accounts(): StaffAccount[] {
    const q = this.query.toLocaleLowerCase().trim();
    return this.data.accounts.filter(a => !q || `${a.fullName} ${a.email} ${this.roleName(a)}`.toLocaleLowerCase().includes(q));
  }
  roleName(account: StaffAccount): string {
    return account.isSuperAdmin ? this.t('مسؤول النظام', 'Administrator') : this.data.roles.find(r => r.id === account.roleId)?.name || this.t('دور غير متاح', 'No assigned role');
  }
  load(): void {
    this.loading = true; this.error = '';
    this.http.get<StaffData>(this.url, { headers: { 'X-Silent-Error': '1' } }).pipe(finalize(() => this.loading = false)).subscribe({
      next: data => this.data = data,
      error: error => this.error = this.errorText(error),
    });
  }
  openRole(template: TemplateRef<unknown>, role?: StaffRole): void {
    this.editingId = role?.id || null;
    this.roleForm.reset({ name: role?.name || '', description: role?.description || '', template: 'custom' });
    this.selectedPermissions = new Set(role?.permissions || []);
    this.open(template);
  }
  useTemplate(): void {
    const template = this.roleForm.controls.template.value;
    const presets: Record<string, { name: string; permissions: string[] }> = {
      callCenter: { name: this.t('خدمة العملاء / كول سنتر', 'Call Center'), permissions: ['orders.manage', 'orders.view', 'support.manage', 'support.view'] },
      accountant: { name: this.t('محاسب', 'Accountant'), permissions: ['finance.manage', 'finance.view'] },
      catalogManager: { name: this.t('مدير المنتجات والمتاجر', 'Catalog Manager'), permissions: ['catalog.manage', 'catalog.view', 'storefront.manage', 'storefront.view'] },
    };
    const preset = presets[template];
    if (preset) { this.selectedPermissions = new Set(preset.permissions); this.roleForm.controls.name.setValue(preset.name); }
  }
  togglePermission(section: string, level: 'view' | 'manage', enabled: boolean): void {
    const permission = `${section}.${level}`;
    if (enabled) { this.selectedPermissions.add(permission); if (level === 'manage') this.selectedPermissions.add(`${section}.view`); }
    else { this.selectedPermissions.delete(permission); if (level === 'view') this.selectedPermissions.delete(`${section}.manage`); }
  }
  openAccount(template: TemplateRef<unknown>, account?: StaffAccount): void {
    if (account?.isSuperAdmin) return;
    this.editingId = account?.id || null;
    this.accountForm.reset({ fullName: account?.fullName || '', email: account?.email || '', roleId: account?.roleId || '', password: '', isActive: account?.isActive ?? true });
    const password = this.accountForm.controls.password;
    password.setValidators([Validators.minLength(10), Validators.maxLength(100), ...(account ? [] : [Validators.required])]);
    password.updateValueAndValidity();
    this.open(template);
  }
  private open(template: TemplateRef<unknown>): void {
    this.modalError = '';
    this.modalRef = this.modals.open(template, { size: 'lg', centered: true, scrollable: true, backdrop: 'static', beforeDismiss: () => !this.saving });
    this.modalRef.result.catch(() => undefined);
  }
  close(): void { if (!this.saving) this.modalRef?.dismiss(); }
  saveRole(): void {
    this.roleForm.markAllAsTouched();
    if (this.roleForm.invalid || this.saving) return;
    if (!this.selectedPermissions.size) { this.modalError = this.t('اختر صلاحية عرض لقسم واحد على الأقل.', 'Choose access to at least one section.'); return; }
    const body = { name: this.roleForm.controls.name.value.trim(), description: this.roleForm.controls.description.value.trim(), permissions: [...this.selectedPermissions] };
    this.save(this.editingId ? this.http.put(`${this.url}/Roles/${this.editingId}`, body, { headers: { 'X-Silent-Error': '1' } }) : this.http.post(`${this.url}/Roles`, body, { headers: { 'X-Silent-Error': '1' } }));
  }
  saveAccount(): void {
    this.accountForm.markAllAsTouched();
    if (this.accountForm.invalid || this.saving) return;
    const values = this.accountForm.getRawValue();
    const body = { ...values, fullName: values.fullName.trim(), email: values.email.trim(), password: values.password || null };
    this.save(this.editingId ? this.http.put(`${this.url}/Accounts/${this.editingId}`, body, { headers: { 'X-Silent-Error': '1' } }) : this.http.post(`${this.url}/Accounts`, body, { headers: { 'X-Silent-Error': '1' } }));
  }
  confirmDelete(template: TemplateRef<unknown>, role: StaffRole): void { this.deletingRole = role; this.open(template); }
  deleteRole(): void { if (!this.saving && this.deletingRole) this.save(this.http.delete(`${this.url}/Roles/${this.deletingRole.id}`, { headers: { 'X-Silent-Error': '1' } })); }
  private save(request: import('rxjs').Observable<unknown>): void {
    this.saving = true; this.modalError = ''; this.success = '';
    request.pipe(finalize(() => this.saving = false)).subscribe({
      next: () => { this.modalRef?.close(); this.success = this.t('تم حفظ التغييرات بنجاح.', 'Changes saved successfully.'); this.accountForm.controls.password.reset(''); this.load(); },
      error: error => this.modalError = this.errorText(error),
    });
  }
  private errorText(error: any): string {
    const body = error?.error;
    if (typeof body?.message === 'string') return body.message;
    if (Array.isArray(body?.errors)) return body.errors.join(' ');
    if (body?.errors && typeof body.errors === 'object') return Object.values(body.errors).map(value => Array.isArray(value) ? value.join(' ') : String(value)).join(' ');
    return this.t('تعذر إتمام العملية. يرجى المحاولة مرة أخرى.', 'Unable to complete this operation. Please try again.');
  }
}
