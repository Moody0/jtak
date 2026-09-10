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
  IDeleteAction,
} from 'src/app/_metronic/shared/crud-table';
import { DeleteCategoryModalComponent } from '../delete-category-modal/delete-category-modal.component';
import { EditCategoryModalComponent } from '../edit-category-modal/edit-category-modal.component';
import { CategoriesService } from '../../services/categories.service';
import { Category } from '../../models/Category.model';
import { forkJoin } from 'rxjs';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
@Component({
  selector: 'app-categories-list',
  templateUrl: './categories-list.component.html',
})
export class CategoriesListComponent
  implements
    OnInit,
    OnDestroy,
    ISortView,
    IPaginatorView,
    ISearchView,
    IDeleteAction
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
    public service: CategoriesService,
    private modalService: NgbModal
  ) {}

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.service.patchState({ paginator });
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

    this.service.patchState({ sorting });
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
    this.service.patchState({ searchTerm });
  }

  // form actions
  create() {
    this.edit(null);
  }

 edit(item: Category | null) {
    const modalRef = this.modalService.open(EditCategoryModalComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  delete(id: number) {
    // +
    const modalRef = this.modalService.open(DeleteCategoryModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  bulkDelete(items: Category[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'category' : 'categories';
    modalRef.componentInstance.action = () => forkJoin(selected.map((item) => this.service.delete(item.id)));
    modalRef.result.then(() => { this.selection.clear(); this.service.fetchPost(); }, () => {});
  }

  ngOnInit(): void {
    this.service.setDefaults();
    this.searchForm();
    this.service.fetchPost();
    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
