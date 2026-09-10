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
  IDeleteAction,
} from 'src/app/_metronic/shared/crud-table';
import { MerchantsService } from '../../services/merchants.service';
import { DeleteMerchantModalComponent } from '../delete-merchant-modal/delete-merchant-modal.component';
import { EditMerchantModalComponent } from '../edit-merchant-modal/edit-merchant-modal.component';
import { Merchant } from '../../models/merchant.model';
@Component({
  selector: 'app-merchants-list',
  templateUrl: './merchants-list.component.html',
})
export class MerchantsListComponent
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
    public service: MerchantsService,
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

  edit(item: Merchant | null) {
    const modalRef = this.modalService.open(EditMerchantModalComponent, {
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
    const modalRef = this.modalService.open(DeleteMerchantModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  rememberMerchant(merchant: Merchant): void {
    this.service.rememberWorkspaceMerchant(merchant);
  }

  isMarket(merchant: Merchant): boolean {
    if (!merchant) return false;
    if (merchant.merchantKind != null) return merchant.merchantKind === 1;
    const title = (merchant.title || '').toLowerCase();
    const desc = (merchant.shortDescription || '').toLowerCase();

    // 1. Check description keywords
    const descHasMarket = desc.includes('سوبرماركت') ||
                          desc.includes('سوبر ماركت') ||
                          desc.includes('ماركت') ||
                          desc.includes('market') ||
                          desc.includes('mart') ||
                          desc.includes('بقالة') ||
                          desc.includes('أسواق') ||
                          desc.includes('تموينات') ||
                          desc.includes('هايبر');

    const descHasRestaurant = desc.includes('مطعم') ||
                              desc.includes('وجبات') ||
                              desc.includes('مأكولات') ||
                              desc.includes('ساندويش') ||
                              desc.includes('شاورما') ||
                              desc.includes('برجر') ||
                              desc.includes('بيتزا') ||
                              desc.includes('مشاوي') ||
                              desc.includes('حلويات') ||
                              desc.includes('مقهى') ||
                              desc.includes('restaurant') ||
                              desc.includes('cafe');

    if (descHasMarket && !descHasRestaurant) return true;
    if (descHasRestaurant && !descHasMarket) return false;
    if (descHasMarket) return true;

    // 2. Fallback to title keywords
    return title.includes('ماركت') ||
           title.includes('سوبرماركت') ||
           title.includes('سوبر ماركت') ||
           title.includes('هايبر') ||
           title.includes('أسواق') ||
           title.includes('بقالة') ||
           title.includes('تموينات') ||
           title.includes('مول') ||
           title.includes('market') ||
           title.includes('mart') ||
           title.includes('mall') ||
           title.includes('grocery');
  }

  merchantKindLabel(merchant: Merchant): string {
    switch (merchant?.merchantKind) {
      case 1: return 'Grocery / Market';
      case 2: return 'Pharmacy';
      case 3: return 'Store';
      default: return 'Restaurant';
    }
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
