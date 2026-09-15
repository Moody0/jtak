import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
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

// Financial Payments & Settlements Component
@Component({
  selector: 'app-payments-list',
  templateUrl: './payments-list.component.html',
  styleUrls: ['./payments-list.component.scss'],
})
export class PaymentsListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<Payment>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: FormGroup;

  // Real Financial KPIs
  kpiTotalPaid = 0;
  kpiTransactions = 0;
  kpiAvgPayment = 0;
  kpiUniqueMerchants = 0;

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: FormBuilder,
    public paymentsService: paymentsService,
    private modalService: NgbModal,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.paymentsService.setDefaults();
    this.searchForm();
    this.paymentsService.fetchPost();

    this.subs.sink = this.paymentsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.paymentsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiTransactions) {
        this.kpiTransactions = this.totalRecords;
      }
    });

    this.subs.sink = this.paymentsService.items$.subscribe((items) => {
      if (items && items.length) {
        this.calculateKpis(items);
      }
    });

    this.sorting = this.paymentsService.sorting;
    this.paginator = this.paymentsService.paginator;
  }

  calculateKpis(items: Payment[]): void {
    if (!items || !items.length) return;
    this.kpiTransactions = this.totalRecords > items.length ? this.totalRecords : items.length;
    this.kpiTotalPaid = items.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
    this.kpiAvgPayment = Math.round(this.kpiTotalPaid / (items.length || 1));
    const uniquePayees = new Set(items.map((p) => p.toUser || p.toUserId));
    this.kpiUniqueMerchants = uniquePayees.size;
    this.cdr.detectChanges();
  }

  searchForm(): void {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(400), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string): void {
    this.selection.clear();
    this.paymentsService.patchState({ searchTerm });
  }

  getDisplayedItems(items: Payment[]): Payment[] {
    return items || [];
  }

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.paymentsService.patchState({ paginator });
  }

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

  create(): void {
    const modalRef = this.modalService.open(CreatePaymentModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: false,
    });
    modalRef.componentInstance.item = null;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  refresh(): void {
    this.selection.clear();
    this.paymentsService.fetchPost();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
