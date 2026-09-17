import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup } from '@angular/forms';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { SubSink } from 'subsink';
import {
  IPaginatorView,
  ISearchView,
  ISortView,
  PaginatorState,
  SortState,
} from 'src/app/_metronic/shared/crud-table';
import { SupportMessage, SupportMessageStats, SupportMessageStatus } from '../../models/support-message.model';
import { SupportMessagesService } from '../../services/support-messages.service';
import { ViewMessageModalComponent } from '../view-message-modal/view-message-modal.component';

import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';

@Component({
  selector: 'app-support-messages-list',
  templateUrl: './support-messages-list.component.html',
  styleUrls: ['./support-messages-list.component.scss'],
})
export class SupportMessagesListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();

  SupportMessageStatus = SupportMessageStatus;
  currentStatusFilter: SupportMessageStatus | null = null;
  stats: SupportMessageStats = {
    totalCount: 0,
    newCount: 0,
    inProgressCount: 0,
    resolvedCount: 0,
  };

  searchGroup: FormGroup;
  paginator: PaginatorState;
  sorting: SortState = new SortState();
  isLoading: boolean = false;

  constructor(
    private fb: FormBuilder,
    public supportService: SupportMessagesService,
    private modalService: NgbModal,
    private toastr: ToastrService,
    private notificationSummaryService: NotificationSummaryService
  ) {}

  ngOnInit(): void {
    this.subs.sink = this.supportService.isLoading$.subscribe((val) => {
      this.isLoading = val;
    });
    this.searchForm();
    this.loadStats();
    // DataTable is a POST endpoint; using fetch() sends an unsupported GET
    // and leaves the page empty even when messages exist.
    this.supportService.fetchPost();
  }

  loadStats(): void {
    this.subs.sink = this.supportService.getStats().subscribe({
      next: (stats) => {
        this.stats = stats;
        this.notificationSummaryService.refresh();
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
    this.supportService.patchState({ searchTerm });
  }

  filterByStatus(status: SupportMessageStatus | null): void {
    this.currentStatusFilter = status;
    const filter: any = {};
    if (status !== null) {
      filter.status = status;
    }
    this.supportService.patchState({ filter });
  }

  paginate(paginator: PaginatorState): void {
    this.supportService.patchState({ paginator });
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
    this.supportService.patchState({ sorting });
  }

  openViewModal(message: SupportMessage): void {
    const modalRef = this.modalService.open(ViewMessageModalComponent, {
      size: 'lg',
      centered: true,
      backdrop: 'static',
    });
    modalRef.componentInstance.message = message;
    modalRef.componentInstance.updated.subscribe(() => {
      this.loadStats();
      this.supportService.fetchPost();
    });
    modalRef.result.then(
      () => {
        this.loadStats();
        this.supportService.fetchPost();
      },
      () => {
        this.loadStats();
        this.supportService.fetchPost();
      }
    );
  }

  quickResolve(message: SupportMessage): void {
    this.supportService
      .updateStatus(message.id, SupportMessageStatus.Resolved, message.adminNotes)
      .subscribe({
        next: () => {
          message.status = SupportMessageStatus.Resolved;
          this.toastr.success('تم تحديد الاستفسار كمنجز بنجاح', 'تمت المعالجة');
          this.loadStats();
        },
        error: () => {
          this.toastr.error('تعذر تحديث الحالة', 'خطأ');
        },
      });
  }

  deleteMessage(message: SupportMessage): void {
    if (!confirm('هل أنت متأكد من رغبتك في حذف هذه الرسالة نهائياً؟')) {
      return;
    }
    this.supportService.deleteMessage(message.id).subscribe({
      next: () => {
        this.toastr.success('تم حذف الرسالة بنجاح', 'تم الحذف');
        this.loadStats();
        this.supportService.fetchPost();
      },
      error: () => {
        this.toastr.error('تعذر حذف الرسالة', 'خطأ');
      },
    });
  }

  openWhatsApp(message: SupportMessage): void {
    if (!message?.senderPhone) return;
    let phone = message.senderPhone.replace(/\D/g, '');
    if (phone.startsWith('09')) {
      phone = '963' + phone.substring(1);
    } else if (phone.startsWith('00')) {
      phone = phone.substring(2);
    } else if (!phone.startsWith('963') && phone.length === 9) {
      phone = '963' + phone;
    }
    const text = encodeURIComponent(
      `مرحباً بك ${message.senderName}، نتواصل معك من إدارة تطبيق جيتك بخصوص استفسارك.`
    );
    window.open(`https://wa.me/${phone}?text=${text}`, '_blank');
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
