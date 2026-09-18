import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup } from '@angular/forms';
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

  searchGroup: FormGroup;
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
    { value: 'Orders', label: 'الطلبات (Orders)' },
    { value: 'Settlements', label: 'التسويات والمالية (Settlements)' },
    { value: 'Merchants', label: 'التجار والشركاء (Merchants)' },
    { value: 'Users', label: 'المستخدمون والمناديب (Users)' },
    { value: 'Catalog', label: 'الكتالوج والمنتجات (Catalog)' },
    { value: 'Banners', label: 'الإعلانات والبنرات (Banners)' },
    { value: 'Settings', label: 'إعدادات النظام (Settings)' },
    { value: 'Auth', label: 'المصادقة والدخول (Auth)' },
  ];

  readonly actions = [
    { value: '', label: 'AUDIT_LOGS_PAGE.FILTER_ALL' },
    { value: 'Create', label: 'إنشاء (Create)' },
    { value: 'Update', label: 'تعديل (Update)' },
    { value: 'Delete', label: 'حذف (Delete)' },
    { value: 'Archive', label: 'أرشفة (Archive)' },
    { value: 'Restore', label: 'استعادة (Restore)' },
    { value: 'Approve', label: 'موافقة وقبول (Approve)' },
    { value: 'Reject', label: 'رفض (Reject)' },
    { value: 'Pay', label: 'صرف مالي (Pay)' },
    { value: 'Deliver', label: 'تسليم (Deliver)' },
    { value: 'AssignDriver', label: 'تعيين مندوب (Assign)' },
  ];

  readonly results = [
    { value: '', label: 'AUDIT_LOGS_PAGE.FILTER_ALL' },
    { value: 'Success', label: 'AUDIT_LOGS_PAGE.RESULT_SUCCESS' },
    { value: 'Failed', label: 'AUDIT_LOGS_PAGE.RESULT_FAILED' },
  ];

  constructor(
    private fb: FormBuilder,
    public auditLogsService: AuditLogsService,
    private modalService: NgbModal
  ) {}

  ngOnInit(): void {
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
