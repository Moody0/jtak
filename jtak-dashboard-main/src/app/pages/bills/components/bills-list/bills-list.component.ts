import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { BillsService } from '../../services/bills.service';


@Component({
  selector: 'app-bills-list',
  templateUrl: './bills-list.component.html',
  styles: [
  ]
})

export class BillsListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
    public billsService: BillsService,
  ) {
  }
  
  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.billsService.patchState({ paginator });
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

    this.billsService.patchState({ sorting });
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
    this.billsService.patchState({ searchTerm });
  }


  ngOnInit(): void {
    this.billsService.setDefaults();
    this.searchForm();
    this.billsService.fetchPost();
    this.subs.sink = this.billsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.billsService.sorting;
    this.paginator = this.billsService.paginator;
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
