import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { forkJoin } from 'rxjs';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
  IDeleteAction,
} from 'src/app/_metronic/shared/crud-table';
import { DeleteProductModalComponent } from '../delete-product-modal/delete-product-modal.component';
import { EditProductModalComponent } from '../edit-product-modal/edit-product-modal.component';
import { Product } from '../../models/product.model';
import { ProductsService } from '../../services/products.service';
@Component({
  selector: 'app-products-list',
  templateUrl: './products-list.component.html',
})
export class ProductsListComponent
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
    public service: ProductsService,
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

  edit(item: Product | null) {
    const modalRef = this.modalService.open(EditProductModalComponent, {
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
    const modalRef = this.modalService.open(DeleteProductModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }
  changeStatus(isActive: boolean, id: number) {
    this.service.changeStatus(isActive, id).subscribe(() => {
      this.service.fetchPost();
    });
  }

  bulkSetStatus(items: Product[], enabled: boolean): void {
    const requests = this.selection.selectedItems(items)
      .filter((item) => item.active !== enabled)
      .map((item) => this.service.changeStatus(item.active, item.id));
    if (!requests.length) return;
    forkJoin(requests).subscribe(() => {
      this.selection.clear();
      this.service.fetchPost();
    });
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
