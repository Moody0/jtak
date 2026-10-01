import { Component, OnDestroy, OnInit } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { SubSink } from 'subsink';
import {
  IPaginatorView,
  ISearchView,
  ISortView,
  PaginatorState,
  SortState,
} from 'src/app/_metronic/shared/crud-table';
import { AdminAuditLog, AdminAuditLogSummary } from '../../models/audit-log.model';
import { AuditLogsService } from '../../services/audit-logs.service';
import { AuditLogDetailsModalComponent } from '../audit-log-details-modal/audit-log-details-modal.component';

@Component({
  selector: 'app-audit-logs-list',
  templateUrl: './audit-logs-list.component.html',
  styleUrls: ['./audit-logs-list.component.scss'],
})
export class AuditLogsListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();

  summary: AdminAuditLogSummary = {
    totalOperations: 0,
    todayOperations: 0,
    thisWeekOperations: 0,
    successCount: 0,
    failureCount: 0,
    topModule: 'Orders',
    topAdmin: 'Admin',
  };

  searchGroup: UntypedFormGroup;
  paginator: PaginatorState;
  sorting: SortState = new SortState();
  isLoading: boolean = false;

  selectedModule: string = '';
  selectedAction: string = '';
  selectedResult: string = '';
  fromDate: string = '';
  toDate: string = '';

  readonly modules = [
    { value: '', label: 'AUDIT_LOGS_PAGE.FILTER_ALL' },
    { value: 'Orders', label: 'الطلبات' },
    { value: 'Settlements', label: 'التسويات والمالية' },
    { value: 'Merchants', label: 'التجار والشركاء' },
    { value: 'Users', label: 'المستخدمون والمناديب' },
    { value: 'Catalog', label: 'الكتالوج والمنتجات' },
    { value: 'Banners', label: 'الإعلانات والبنرات' },
    { value: 'Settings', label: 'إعدادات النظام' },
    { value: 'Auth', label: 'المصادقة والدخول' },
  ];

  readonly actions = [
    { value: '', label: 'AUDIT_LOGS_PAGE.FILTER_ALL' },
    { value: 'Create', label: 'إنشاء' },
    { value: 'Update', label: 'تعديل' },
    { value: 'Delete', label: 'حذف' },
    { value: 'Archive', label: 'أرشفة' },
    { value: 'Restore', label: 'استعادة' },
    { value: 'Approve', label: 'موافقة وقبول' },
    { value: 'Reject', label: 'رفض' },
    { value: 'Pay', label: 'صرف مالي' },
    { value: 'Deliver', label: 'تسليم' },
    { value: 'AssignDriver', label: 'تعيين مندوب' },
  ];

  readonly results = [
    { value: '', label: 'AUDIT_LOGS_PAGE.FILTER_ALL' },
    { value: 'Success', label: 'AUDIT_LOGS_PAGE.RESULT_SUCCESS' },
    { value: 'Failed', label: 'AUDIT_LOGS_PAGE.RESULT_FAILED' },
  ];

  constructor(
    private fb: UntypedFormBuilder,
    public auditLogsService: AuditLogsService,
    private modalService: NgbModal
  ) {}

  ngOnInit(): void {
    // Keep the last successful totals visible while the page refreshes them.
    this.summary = this.auditLogsService.getCachedSummary() || this.summary;

    this.subs.sink = this.auditLogsService.isLoading$.subscribe((val) => {
      this.isLoading = val;
    });

    this.paginator = this.auditLogsService.paginator;
    this.sorting = this.auditLogsService.sorting;

    this.searchForm();
    this.loadSummary();
    this.auditLogsService.fetchPost();
  }

  loadSummary(): void {
    this.subs.sink = this.auditLogsService.getSummary().subscribe({
      next: (summary) => {
        this.summary = summary;
        this.auditLogsService.cacheSummary(summary);
      },
      error: () => {},
    });
  }

  searchForm(): void {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(300), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string): void {
    this.auditLogsService.patchState({ searchTerm });
  }

  clearSearch(): void {
    this.searchGroup.controls.searchTerm.setValue('');
  }

  applyFilters(): void {
    const filter: any = {};
    if (this.selectedModule) filter.module = this.selectedModule;
    if (this.selectedAction) filter.action = this.selectedAction;
    if (this.selectedResult) filter.result = this.selectedResult;
    if (this.fromDate) filter.fromDate = this.fromDate;
    if (this.toDate) filter.toDate = this.toDate;

    const paginator = this.auditLogsService.paginator;
    paginator.page = 1;

    this.auditLogsService.patchState({
      filter,
      paginator,
    });
  }

  filterAll(): void {
    this.clearKpiFilters();
  }

  filterToday(): void {
    const today = this.getDamascusToday();
    this.applyKpiFilters({ fromDate: today, toDate: today });
  }

  filterThisWeek(): void {
    const today = this.getDamascusToday();
    this.applyKpiFilters({
      fromDate: this.getWeekStart(today),
      toDate: today,
    });
  }

  filterByResult(result: string): void {
    this.applyKpiFilters({ result });
  }

  filterByModule(module: string): void {
    if (!module) return;
    this.applyKpiFilters({ module });
  }

  isDateFilterActive(range: 'today' | 'week'): boolean {
    const today = this.getDamascusToday();
    if (range === 'today') return this.fromDate === today && this.toDate === today;

    return this.fromDate === this.getWeekStart(today) && this.toDate === today;
  }

  private applyKpiFilters(options: {
    module?: string;
    result?: string;
    fromDate?: string;
    toDate?: string;
  }): void {
    this.selectedModule = options.module || '';
    this.selectedAction = '';
    this.selectedResult = options.result || '';
    this.fromDate = options.fromDate || '';
    this.toDate = options.toDate || '';
    this.searchGroup?.controls.searchTerm.setValue('', { emitEvent: false });

    const filter: any = {};
    if (this.selectedModule) filter.module = this.selectedModule;
    if (this.selectedResult) filter.result = this.selectedResult;
    if (this.fromDate) filter.fromDate = this.fromDate;
    if (this.toDate) filter.toDate = this.toDate;

    const paginator = this.auditLogsService.paginator;
    paginator.page = 1;
    this.auditLogsService.patchState({ filter, searchTerm: '', paginator });
  }

  private clearKpiFilters(): void {
    this.selectedModule = '';
    this.selectedAction = '';
    this.selectedResult = '';
    this.fromDate = '';
    this.toDate = '';
    this.searchGroup?.controls.searchTerm.setValue('', { emitEvent: false });
    const paginator = this.auditLogsService.paginator;
    paginator.page = 1;
    this.auditLogsService.patchState({ filter: {}, searchTerm: '', paginator });
  }

  private getDamascusToday(): string {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Damascus',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const value = (type: string) => parts.find((part) => part.type === type)?.value;
    return `${value('year')}-${value('month')}-${value('day')}`;
  }

  private getWeekStart(today: string): string {
    const date = new Date(`${today}T00:00:00Z`);
    date.setUTCDate(date.getUTCDate() - ((date.getUTCDay() + 6) % 7));
    return date.toISOString().slice(0, 10);
  }

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
      Payment: 'دفعة مالية',
      Banner: 'إعلان',
      Category: 'تصنيف',
      Settings: 'إعدادات',
    };
    return labels[entityType || ''] || entityType || '—';
  }

  resetFilters(): void {
    this.selectedModule = '';
    this.selectedAction = '';
    this.selectedResult = '';
    this.fromDate = '';
    this.toDate = '';
    this.searchGroup.controls.searchTerm.setValue('');

    const paginator = this.auditLogsService.paginator;
    paginator.page = 1;

    this.auditLogsService.patchState({
      filter: {},
      searchTerm: '',
      paginator,
    });
  }

  hasActiveFilters(): boolean {
    return (
      !!this.selectedModule ||
      !!this.selectedAction ||
      !!this.selectedResult ||
      !!this.fromDate ||
      !!this.toDate ||
      !!this.searchGroup?.controls?.searchTerm?.value
    );
  }

  refresh(): void {
    this.loadSummary();
    this.auditLogsService.fetchPost();
  }

  paginate(paginator: PaginatorState): void {
    this.auditLogsService.patchState({ paginator });
  }

  sort(column: string): void {
    const sorting = this.sorting;
    const isActiveColumn = sorting.column === column;
    if (!isActiveColumn) {
      sorting.column = column;
      sorting.direction = 'ASC';
    } else {
      sorting.direction = sorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }
    this.auditLogsService.patchState({ sorting });
  }

  openDetailsModal(log: AdminAuditLog): void {
    const modalRef = this.modalService.open(AuditLogDetailsModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: true,
      centered: true,
    });
    modalRef.componentInstance.log = log;
  }

  getModuleBadgeClass(module: string): string {
    switch (module?.toLowerCase()) {
      case 'orders':
        return 'badge-light-primary text-primary';
      case 'settlements':
        return 'badge-light-success text-success';
      case 'merchants':
        return 'badge-light-warning text-warning';
      case 'catalog':
        return 'badge-light-info text-info';
      case 'users':
        return 'badge-light-dark text-dark';
      case 'banners':
        return 'badge-light-secondary text-secondary';
      default:
        return 'badge-light-primary text-primary';
    }
  }

  getActionBadgeClass(action: string): string {
    switch (action?.toLowerCase()) {
      case 'create':
      case 'approve':
      case 'restore':
        return 'badge-light-success text-success';
      case 'delete':
      case 'reject':
        return 'badge-light-danger text-danger';
      case 'archive':
        return 'badge-light-warning text-warning';
      case 'update':
      case 'pay':
        return 'badge-light-info text-info';
      default:
        return 'badge-light-secondary text-secondary';
    }
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
