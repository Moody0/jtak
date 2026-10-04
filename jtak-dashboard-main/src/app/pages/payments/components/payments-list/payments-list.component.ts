import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
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
import { paymentsService } from '../../services/payments.service';
import { CreatePaymentModalComponent } from '../create-payment-modal/create-payment-modal.component';
import { DriverCashAdvanceModalComponent } from '../driver-cash-advance-modal/driver-cash-advance-modal.component';
import { Payment } from '../../models/payments.model';
import { DriverCashAdvanceOverview } from '../../models/driver-cash-advance.model';
import { DriverCashAdvancesService } from '../../services/driver-cash-advances.service';

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
  private overviewRequest?:Subscription;
  private destroyed=false;
  selection = new TableSelection<Payment>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real Financial KPIs
  kpiTotalPaid = 0;
  kpiOtherCurrencies:{currency:string;totalPaid:number}[]=[];
  kpiTransactions = 0;
  kpiAvgPayment = 0;
  kpiUniqueMerchants = 0;
  driverCashAdvances: DriverCashAdvanceOverview | null = null;
  isLoadingDriverCashAdvances = false;
  driverCashAdvancesError = '';

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: UntypedFormBuilder,
    public paymentsService: paymentsService,
    private modalService: NgbModal,
    private cdr: ChangeDetectorRef,
    private cashAdvancesService: DriverCashAdvancesService
  ) {}

  ngOnInit(): void {
    this.paymentsService.setDefaults();
    this.sorting=this.paymentsService.sorting;this.paginator=this.paymentsService.paginator;
    this.searchForm();
    this.paymentsService.fetchPost();
    this.loadDriverCashAdvances();

    this.subs.sink = this.paymentsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.paymentsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
    });

    this.subs.sink = this.paymentsService.summary$.subscribe(summary=>{
      this.kpiOtherCurrencies=(summary?.currencyTotals || []).filter((item:any)=>item.currency!=='SYP');
      this.kpiTransactions=summary?.recordsCount ?? 0;this.kpiTotalPaid=summary?.totalPaid ?? 0;
      this.kpiAvgPayment=summary?.averagePayment ?? 0;this.kpiUniqueMerchants=summary?.uniqueRecipients ?? 0;this.cdr.detectChanges();
    });

    this.sorting = this.paymentsService.sorting;
    this.paginator = this.paymentsService.paginator;
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
    this.paginator.page=0;
    this.paymentsService.patchState({ searchTerm, paginator:this.paginator });
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
      beforeDismiss: () => !modalRef.componentInstance.isSaving,
    });
    modalRef.componentInstance.item = null;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  createDriverCashAdvance(): void {
    const modalRef = this.modalService.open(DriverCashAdvanceModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: false,
      beforeDismiss: () => !modalRef.componentInstance.isSaving,
      scrollable: true,
    });
    modalRef.result.then(
      () => this.refresh(),
      () => {}
    );
  }

  refresh(): void {
    if(this.destroyed) return;
    this.selection.clear();
    this.paymentsService.fetchPost();
    this.loadDriverCashAdvances();
  }

  loadDriverCashAdvances(): void {
    this.isLoadingDriverCashAdvances = true;
    this.driverCashAdvancesError = '';
    this.overviewRequest?.unsubscribe();
    this.overviewRequest=this.cashAdvancesService.getOverview().subscribe({
      next: (overview) => {
        this.driverCashAdvances = overview;
        this.isLoadingDriverCashAdvances = false;
      },
      error: () => {
        this.driverCashAdvancesError = 'PAYMENTS_PAGE.DRIVER_ADVANCE_AUDIT_ERROR';
        this.isLoadingDriverCashAdvances = false;
      },
    });
  }

  ngOnDestroy(): void {
    this.destroyed=true;this.overviewRequest?.unsubscribe();
    this.subs.unsubscribe();
  }
}
