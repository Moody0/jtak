import { Component, Input, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { ToastrService } from 'ngx-toastr';
import { NotificationsService } from '../../services/notifications.service';
import { NotificationsCreateComponent } from '../notifications-create/notifications-create.component';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';



@Component({
  selector: 'app-notifications-list',
  templateUrl: './notifications-list.component.html',
  styles: [
  ]
})
export class NotificationsListComponent implements
    OnInit,
    OnDestroy,
    ISortView,
    IPaginatorView,
    ISearchView
{
  private subs = new SubSink();
  private destroyed = false;
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: UntypedFormGroup;

  constructor(
    private fb: UntypedFormBuilder,
    public notificationsService: NotificationsService,
    private modalService: NgbModal,
    private toasterService: ToastrService
  ) {}

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.notificationsService.patchState({ paginator });
  }

  sorting: SortState;
  sort(column: string): void {
    this.selection.clear();
    const sorting = this.sorting;
    const isActiveColumn = sorting.column === column;
    if (!isActiveColumn) {
      sorting.column = column;
      sorting.direction = 'ASC';
    } else {
      sorting.direction = sorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }

    this.notificationsService.patchState({ sorting });
  }

  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string) {
    this.selection.clear();
    this.notificationsService.patchState({ searchTerm });
  }

  // form actions
  create() {
    const modalRef = this.modalService.open(NotificationsCreateComponent, {
      size: 'xl',
      centered: true,
      backdrop: 'static',
      beforeDismiss: () => !modalRef.componentInstance?.isSending,
    });
    modalRef.result.then(
      () => { if (!this.destroyed) this.notificationsService.fetchPost(); },
      () => {}
    );
  }

  deleteSelected(items: any[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;

    const modalRef = this.modalService.open(BulkConfirmModalComponent, {backdrop: 'static', beforeDismiss: () => !modalRef.componentInstance?.isLoading});
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = 'notifications';
    modalRef.componentInstance.actionLabel = 'حذف';
    modalRef.componentInstance.description =
      'سيؤدي ذلك إلى حذف الإشعارات المحددة من سجل التطبيق للمستخدمين. لا يمكن سحب إشعار سبق أن وصل إلى شريط إشعارات الهاتف.';
    modalRef.componentInstance.action = () =>
      this.notificationsService.deleteCampaigns(selected.map((item) => item.id));

    modalRef.result.then(
      () => {
        if (this.destroyed) return;
        this.selection.clear();
        this.toasterService.success('تم حذف الإشعارات المحددة من سجل التطبيق.');
        this.notificationsService.fetchPost();
      },
      () => {}
    );
  }

  getAudienceLabel(topic?: string): string {
    switch (topic) {
      case 'all': return 'العملاء';
      case 'campaign_delivery': return 'التوصيل';
      case 'campaign_warehouse': return 'التاجر';
      default: return 'غير محدد';
    }
  }

  ngOnInit(): void {
    this.notificationsService.setDefaults();
    this.sorting = this.notificationsService.sorting;
    this.paginator = this.notificationsService.paginator;
    this.subs.sink = this.notificationsService.totalRecords$.subscribe(total => this.totalRecords = total || 0);
    this.subs.sink = this.notificationsService.items$.subscribe(() => this.selection.clear());
    this.searchForm();
    this.notificationsService.fetchPost();
    this.subs.sink = this.notificationsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.notificationsService.sorting;
    this.paginator = this.notificationsService.paginator;
  }

  ngOnDestroy() {
    this.destroyed = true;
    this.subs.unsubscribe();
  }
}
