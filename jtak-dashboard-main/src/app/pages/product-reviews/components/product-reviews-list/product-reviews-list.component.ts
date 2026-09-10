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
import { productReviewsService } from '../../services/product-reviews.service';
import { productReview } from '../../models/product-reviews.model';


@Component({
  selector: 'app-product-reviews-list',
  templateUrl: './product-reviews-list.component.html',
  styles: [],
})
export class productReviewsListComponent implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
    public productReviewsService: productReviewsService,
    private modalService: NgbModal
  ) {}
  

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.productReviewsService.patchState({ paginator });
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

    this.productReviewsService.patchState({ sorting });
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
    this.productReviewsService.patchState({ searchTerm });
  }

  ngOnInit(): void {
    this.productReviewsService.setDefaults();
    this.searchForm();
    this.productReviewsService.fetchPost();
    this.subs.sink = this.productReviewsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.productReviewsService.sorting;
    this.paginator = this.productReviewsService.paginator;
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
