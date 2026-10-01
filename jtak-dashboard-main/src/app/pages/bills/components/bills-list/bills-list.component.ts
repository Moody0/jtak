import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { BillsService } from '../../services/bills.service';
import { Bill } from '../../models/bill.model';

// Financial Bills Operations Component
@Component({
  selector: 'app-bills-list',
  templateUrl: './bills-list.component.html',
  styleUrls: ['./bills-list.component.scss'],
})
export class BillsListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<Bill>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real Financial KPIs
  kpiTotalBilled = 0;
  kpiMerchantShare = 0;
  kpiPlatformRevenue = 0;
  kpiBillsCount = 0;

  // Filters
  selectedDuesFilter: 'all' | 'added' | 'pending' = 'all';

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: UntypedFormBuilder,
    public billsService: BillsService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.billsService.setDefaults();
    this.searchForm();
    this.billsService.fetchPost();

    this.subs.sink = this.billsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.billsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiBillsCount) {
        this.kpiBillsCount = this.totalRecords;
      }
    });

    this.subs.sink = this.billsService.items$.subscribe((items) => {
      if (items && items.length) {
        this.calculateKpis(items);
      }
    });

    this.sorting = this.billsService.sorting;
    this.paginator = this.billsService.paginator;
  }

  calculateKpis(items: Bill[]): void {
    if (!items || !items.length) {
      this.kpiBillsCount = 0;
      this.kpiTotalBilled = 0;
      this.kpiMerchantShare = 0;
      this.kpiPlatformRevenue = 0;
      this.cdr.detectChanges();
      return;
    }
    const earnedBills = items.filter(b => b.isAddedToDues);
    this.kpiBillsCount = earnedBills.length;
    this.kpiTotalBilled = earnedBills.reduce((sum, b) => sum + (Number(b.totalAmount) || 0), 0);
    this.kpiMerchantShare = earnedBills.reduce((sum, b) => sum + (Number(b.merchantAmount) || 0), 0);
    // JTakAmount is the commission already included in the invoice total.
    // JTakAdditionalAmount is a separate informational field and must not be
    // added again, otherwise merchant dues plus platform revenue exceed the
    // invoice total. Use the invoice residual as the authoritative value so
    // the KPI always reconciles with the amounts shown in each row.
    this.kpiPlatformRevenue = earnedBills.reduce((sum, b) => {
      const totalAmount = Number(b.totalAmount) || 0;
      const merchantAmount = Number(b.merchantAmount) || 0;
      return sum + Math.max(totalAmount - merchantAmount, 0);
    }, 0);
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
    const paginator = this.billsService.paginator;
    paginator.page = 1;
    this.billsService.patchState({ searchTerm, paginator });
  }

  filterByDues(filter: 'all' | 'added' | 'pending'): void {
    this.selectedDuesFilter = filter;
    this.selection.clear();
  }

  getDisplayedItems(items: Bill[]): Bill[] {
    if (!items) return [];

    return items.filter((bill) => {
      if (this.selectedDuesFilter === 'added' && !bill.isAddedToDues) return false;
      if (this.selectedDuesFilter === 'pending' && bill.isAddedToDues) return false;
      return true;
    });
  }

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.billsService.patchState({ paginator });
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
    this.billsService.patchState({ sorting });
  }

  refresh(): void {
    this.selection.clear();
    this.billsService.fetchPost();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
