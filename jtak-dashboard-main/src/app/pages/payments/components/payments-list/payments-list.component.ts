import { Component, OnDestroy, OnInit } from '@angular/core';
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
import { paymentsService } from '../../services/payments.service';
import { CreatePaymentModalComponent } from '../create-payment-modal/create-payment-modal.component';
import { Payment } from '../../models/payments.model';


@Component({
  selector: 'app-payments-list',
  templateUrl: './payments-list.component.html',
  styles: [],
})
export class PaymentsListComponent implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
    public paymentsService: paymentsService,
    private modalService: NgbModal
  ) {}
  

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.paymentsService.patchState({ paginator });
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

    this.paymentsService.patchState({ sorting });
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
    this.paymentsService.patchState({ searchTerm });
  }


  create(item: Payment | null) {
    const modalRef = this.modalService.open(CreatePaymentModalComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.paymentsService.fetchPost(),
      () => {}
    );
  }



  ngOnInit(): void {
    this.paymentsService.setDefaults();
    this.searchForm();
    this.paymentsService.fetchPost();
    this.subs.sink = this.paymentsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.paymentsService.sorting;
    this.paginator = this.paymentsService.paginator;
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
