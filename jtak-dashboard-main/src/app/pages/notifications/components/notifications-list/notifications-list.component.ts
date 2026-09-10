import { Component, Input, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
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
import { Notification } from '../../models/notification.model';
import { NotificationsCreateComponent } from '../notifications-create/notifications-create.component';



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
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
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
  create(item: Notification | null) {
    const modalRef = this.modalService.open(NotificationsCreateComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.notificationsService.fetchPost(),
      () => {}
    );
  }

  ngOnInit(): void {
    this.notificationsService.setDefaults();
    this.searchForm();
    this.notificationsService.fetchPost();
    this.subs.sink = this.notificationsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.notificationsService.sorting;
    this.paginator = this.notificationsService.paginator;
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
