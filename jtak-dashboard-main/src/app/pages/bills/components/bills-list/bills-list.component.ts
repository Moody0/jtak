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
    this.sorting=this.billsService.sorting;this.paginator=this.billsService.paginator;
    this.searchForm();
    this.billsService.fetchPost();

    this.subs.sink = this.billsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.billsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
    });

    this.subs.sink = this.billsService.summary$.subscribe((summary) => {
      this.kpiBillsCount=summary?.billsCount ?? 0;this.kpiTotalBilled=summary?.totalBilled ?? 0;
      this.kpiMerchantShare=summary?.merchantShare ?? 0;this.kpiPlatformRevenue=summary?.platformRevenue ?? 0;
      this.cdr.detectChanges();
    });

    this.sorting = this.billsService.sorting;
    this.paginator = this.billsService.paginator;
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
    paginator.page = 0;
    this.billsService.patchState({ searchTerm, paginator });
  }

  filterByDues(filter: 'all' | 'added' | 'pending'): void {
    this.selectedDuesFilter = filter;
    this.selection.clear();
    this.billsService.patchState({filter:{duesStatus:filter}});
  }

  getDisplayedItems(items: Bill[]): Bill[] {
    return items || [];
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
