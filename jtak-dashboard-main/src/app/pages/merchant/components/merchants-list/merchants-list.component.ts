import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { forkJoin, of } from 'rxjs';
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
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { ActivatedRoute, Router } from '@angular/router';

export interface MerchantTypeInfo {
  kind: number;
  label: string;
  icon: string;
  badgeClass: string;
}

@Component({
  selector: 'app-merchants-list',
  templateUrl: './merchants-list.component.html',
  styleUrls: ['./merchants-list.component.scss'],
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
  selection = new TableSelection<Merchant>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real System KPIs
  kpiTotal = 0;
  kpiActive = 0;
  kpiGrocery = 0;
  kpiRestaurants = 0;

  // Filter States
  selectedKind: number | 'all' = 'all';
  selectedStatus: 'all' | 'active' | 'disabled' = 'all';

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: UntypedFormBuilder,
    public service: MerchantsService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef,
    private route: ActivatedRoute,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.service.paginator.pageSize = 50;
    this.searchForm();
    this.loadKpis();
    this.service.fetchPost();

    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.service.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiTotal) {
        this.kpiTotal = this.totalRecords;
      }
      this.cdr.markForCheck();
    });

    this.subs.sink = this.service.items$.subscribe((items) => {
      if (items && items.length) {
        if (!this.kpiActive && !this.kpiGrocery && !this.kpiRestaurants) {
          this.calculateKpis(items);
        }
      }
    });

    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;

    // Allow the central warehouse page to open the warehouse form directly.
    if (this.route.snapshot.queryParamMap.get('create') === 'warehouse') {
      setTimeout(() => {
        this.edit(null, 4);
        // Prevent a refresh or later return to the merchant list from reopening the form.
        this.router.navigate([], {
          relativeTo: this.route,
          queryParams: { create: null },
          queryParamsHandling: 'merge',
          replaceUrl: true,
        });
      });
    }
  }

  calculateKpis(merchants: Merchant[]): void {
    if (!merchants || !merchants.length) return;
    this.kpiTotal = Math.max(this.kpiTotal, merchants.length, this.totalRecords);
    this.kpiActive = merchants.filter((m) => m.active).length;
    this.kpiGrocery = merchants.filter(
      (m) => m.merchantKind === 1 || this.isMarket(m)
    ).length;
    this.kpiRestaurants = merchants.filter(
      (m) =>
        (m.merchantKind === 0 || m.merchantKind === 3 || m.merchantKind == null) && !this.isMarket(m)
    ).length;
    this.cdr.markForCheck();
  }

  loadKpis(): void {
    this.service
      .getSummary()
      .pipe(catchError(() => of(null as any)))
      .subscribe((summary) => {
        if (summary) {
          this.kpiTotal = summary.total;
          this.kpiActive = summary.active;
          this.kpiGrocery = summary.grocery;
          this.kpiRestaurants = summary.restaurants;
          this.cdr.markForCheck();
          return;
        }

        this.service
          .getAllMerchants()
          .pipe(catchError(() => of([])))
          .subscribe((merchants) => {
            if (!merchants || !merchants.length) return;
            this.calculateKpis(merchants);
          });
      });
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
    this.service.patchState({ searchTerm });
  }

  clearSearch(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  filterByKind(kind: number | 'all'): void {
    this.selectedKind = kind;
    this.selection.clear();
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
  }

  getDisplayedItems(items: Merchant[]): Merchant[] {
    if (!items) return [];

    return items.filter((merchant) => {
      // Kind filter
      if (this.selectedKind !== 'all') {
        const rawKind = merchant.merchantKind ?? (this.isMarket(merchant) ? 1 : 0);
        if (rawKind !== this.selectedKind) {
          return false;
        }
      }

      // Status filter
      if (this.selectedStatus === 'active' && !merchant.active) return false;
      if (this.selectedStatus === 'disabled' && merchant.active) return false;

      return true;
    });
  }

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.service.patchState({ paginator });
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
    this.service.patchState({ sorting });
  }

  create(): void {
    this.edit(null);
  }

  edit(item: Merchant | null, initialMerchantKind?: number): void {
    const modalRef = this.modalService.open(EditMerchantModalComponent, {
      size: 'xl',
      backdrop: 'static',
      keyboard: false,
    });
    modalRef.componentInstance.item = item;
    modalRef.componentInstance.initialMerchantKind = initialMerchantKind ?? null;
    modalRef.result.then(
      () => {
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  delete(id: number): void {
    const modalRef = this.modalService.open(DeleteMerchantModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  changeStatus(merchant: Merchant): void {
    const updated: Merchant = {
      ...merchant,
      active: !merchant.active,
    };
    this.service.update(updated as any).subscribe(() => {
      this.toaster.success('تم تحديث حالة المتجر بنجاح');
      this.loadKpis();
      this.service.fetchPost();
    });
  }

  bulkDelete(items: Merchant[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'merchant' : 'merchants';
    modalRef.componentInstance.action = () =>
      forkJoin(selected.map((item) => this.service.delete(item.id)));
    modalRef.result.then(
      () => {
        this.selection.clear();
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  bulkSetStatus(items: Merchant[], active: boolean): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    forkJoin(
      selected.map((item) => this.service.update({ ...item, active } as any))
    ).subscribe(() => {
      this.toaster.success(active ? 'تم تفعيل المتاجر المحددة' : 'تم تعطيل المتاجر المحددة');
      this.selection.clear();
      this.loadKpis();
      this.service.fetchPost();
    });
  }

  rememberMerchant(merchant: Merchant): void {
    this.service.rememberWorkspaceMerchant(merchant);
  }

  isMarket(merchant: Merchant): boolean {
    if (!merchant) return false;
    if (merchant.merchantKind != null) return merchant.merchantKind === 1;
    const title = (merchant.title || '').toLowerCase();
    const desc = (merchant.shortDescription || '').toLowerCase();

    const descHasMarket =
      desc.includes('سوبرماركت') ||
      desc.includes('سوبر ماركت') ||
      desc.includes('ماركت') ||
      desc.includes('market') ||
      desc.includes('mart') ||
      desc.includes('بقالة') ||
      desc.includes('أسواق') ||
      desc.includes('تموينات') ||
      desc.includes('هايبر');

    const descHasRestaurant =
      desc.includes('مطعم') ||
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

    return (
      title.includes('ماركت') ||
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
      title.includes('grocery')
    );
  }

  getMerchantTypeInfo(merchant: Merchant): MerchantTypeInfo {
    const kind = merchant?.merchantKind ?? (this.isMarket(merchant) ? 1 : 0);
    switch (kind) {
      case 1:
        return {
          kind: 1,
          label: 'سوبرماركت / بقالية',
          icon: 'fas fa-shopping-basket',
          badgeClass: 'type-grocery',
        };
      case 3:
        return {
          kind: 3,
          label: 'أخرى',
          icon: 'fas fa-store',
          badgeClass: 'type-store',
        };
      default:
        return {
          kind: 0,
          label: 'مطعم',
          icon: 'fas fa-utensils',
          badgeClass: 'type-restaurant',
        };
    }
  }

  refresh(): void {
    this.selection.clear();
    this.loadKpis();
    this.service.fetchPost();
  }

  onImageError(event: any): void {
    event.target.src = './assets/media/svg/files/blank-image.svg';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
