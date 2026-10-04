import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { BannersService } from '../../services/banners.service';
import { EditBannerModalComponent } from '../edit-banner-modal/edit-banner-modal.component';
import { DeleteBannerModalComponent } from '../delete-banner-modal/delete-banner-modal.component';
import { Banner } from '../../models/banner.model';
import { Subscription } from 'rxjs';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { Merchant } from 'src/app/pages/merchant/models/merchant.model';

@Component({
  selector: 'app-banners-list',
  templateUrl: './banners-list.component.html',
  styleUrls: ['./banners-list.component.scss'],
})
export class BannersListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  private summaryRequest?: Subscription;
  private destroyed = false;
  mutating = false;
  selection = new TableSelection<Banner>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real Operational KPIs
  kpiTotal = 0;
  kpiActive = 0;
  kpiDaily = 0;
  kpiDontMiss = 0;

  // Filter States
  selectedSection: 'all' | 'daily' | 'dont_miss' | 'both' = 'all';
  selectedStatus: 'all' | 'active' | 'disabled' = 'all';

  paginator: PaginatorState;
  sorting: SortState;
  merchantsMap = new Map<number, Merchant>();

  constructor(
    private fb: UntypedFormBuilder,
    public bannersService: BannersService,
    private merchantsService: MerchantsService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.bannersService.setDefaults();
    this.sorting = this.bannersService.sorting;
    this.paginator = this.bannersService.paginator;
    this.searchForm();
    this.bannersService.fetchPost();
    this.loadSummary();

    this.subs.sink = this.merchantsService.getAllMerchants().subscribe({
      next: (merchants) => {
        if (merchants) {
          merchants.forEach((m) => this.merchantsMap.set(Number(m.id), m));
          this.cdr.detectChanges();
        }
      },
      error: () => this.toaster.error('تعذر تحميل أسماء وجهات الإعلانات'),
    });

    this.subs.sink = this.bannersService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.bannersService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
    });

    this.sorting = this.bannersService.sorting;
    this.paginator = this.bannersService.paginator;
  }

  private loadSummary(): void {
    this.summaryRequest?.unsubscribe();
    this.subs.sink = this.summaryRequest = this.bannersService.summary().subscribe({
      next: s => { this.kpiTotal = s.total; this.kpiActive = s.active; this.kpiDaily = s.daily; this.kpiDontMiss = s.dontMiss; this.cdr.detectChanges(); },
      error: () => { this.kpiTotal = this.kpiActive = this.kpiDaily = this.kpiDontMiss = 0; this.toaster.error('تعذر تحميل إحصائيات الإعلانات'); this.cdr.detectChanges(); }
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
    this.bannersService.patchState({ searchTerm });
  }

  filterBySection(section: 'all' | 'daily' | 'dont_miss' | 'both'): void {
    this.selectedSection = section;
    this.selection.clear();
    this.applyFilters();
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
    this.applyFilters();
  }

  private applyFilters(): void { this.bannersService.patchState({ filter: {section: this.selectedSection, status: this.selectedStatus} }); }
  getDisplayedItems(items: Banner[]): Banner[] { return items || []; }

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.bannersService.patchState({ paginator });
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
    this.bannersService.patchState({ sorting });
  }

  create(): void {
    this.edit(null);
  }

  edit(item: Banner | null): void {
    const modalRef = this.modalService.open(EditBannerModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: false,
      beforeDismiss: () => !modalRef.componentInstance.isSaving,
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => {
        if (!this.destroyed) this.refresh();
      },
      () => {}
    );
  }

  delete(id: string): void {
    const modalRef = this.modalService.open(DeleteBannerModalComponent, {
      size: 'md',
      beforeDismiss: () => !modalRef.componentInstance.deleting,
    });
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        if (!this.destroyed) this.refresh();
      },
      () => {}
    );
  }

  toggleBannerStatus(banner: Banner): void { this.updateStatus([Number(banner.id)], !banner.active); }
  bulkSetStatus(items: Banner[], targetActive: boolean): void {
    this.updateStatus(this.selection.selectedItems(items).filter(i => i.active !== targetActive).map(i => Number(i.id)), targetActive);
  }
  private updateStatus(ids: number[], active: boolean): void {
    if (this.mutating || !ids.length) return;
    this.mutating = true;
    this.subs.sink = this.bannersService.setStatus(ids, active).subscribe({
      next: () => { this.mutating = false; this.toaster.success('تم تحديث حالة الإعلانات'); this.refresh(); },
      error: err => { this.mutating = false; this.toaster.error(typeof err?.error === 'string' ? err.error : 'تعذر تحديث حالة الإعلان'); this.cdr.detectChanges(); }
    });
  }

  bulkDelete(items: Banner[]): void {
    if (this.mutating) return;
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent, {
      beforeDismiss: () => !modalRef.componentInstance.isLoading,
    });
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = 'إعلان';
    modalRef.componentInstance.action = () =>
      this.bannersService.deleteMany(selected.map(item => Number(item.id)));
    modalRef.result.then(
      () => {
        this.selection.clear();
        if (!this.destroyed) this.refresh();
      },
      () => {}
    );
  }

  refresh(): void {
    this.selection.clear();
    this.bannersService.fetchPost();
    this.loadSummary();
  }

  isRestaurants(banner: Banner): boolean { return banner?.bannerLocation === 2; }
  isMarket(banner: Banner): boolean { return banner?.bannerLocation === 3; }
  isDontMiss(banner: Banner): boolean { return banner?.bannerLocation === 1; }
  isAllSections(banner: Banner): boolean { return banner?.bannerLocation === 4; }
  isDailyOffers(banner: Banner): boolean { return banner?.bannerLocation === 0; }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  getTargetInfo(banner: Banner): {
    type: 'none' | 'restaurant' | 'market' | 'category' | 'offers' | 'external';
    label: string;
    icon: string;
    url?: string;
  } {
    const rawUrl = (banner?.url || '').trim();
    const cleanUrl = rawUrl.replace(/#section:[a-z_]+/gi, '').trim();

    if (!cleanUrl || cleanUrl === 'none' || cleanUrl === 'no_link') {
      return {
        type: 'none',
        label: 'للعرض فقط',
        icon: 'fas fa-eye-slash',
      };
    }

    if (cleanUrl.startsWith('restaurant:')) {
      const id = parseInt(cleanUrl.split(':')[1], 10);
      const m = this.merchantsMap.get(id);
      return {
        type: 'restaurant',
        label: m ? `مطعم: ${m.title}` : `مطعم #${id}`,
        icon: 'fas fa-utensils',
      };
    }

    if (/^(market|merchant|store):\d+$/i.test(cleanUrl) || /^\d+$/.test(cleanUrl)) {
      const id = Number(cleanUrl.includes(':') ? cleanUrl.split(':')[1] : cleanUrl);
      const m = this.merchantsMap.get(id);
      return {
        type: 'market',
        label: m ? `متجر: ${m.title}` : `متجر #${id}`,
        icon: 'fas fa-shopping-basket',
      };
    }

    if (/^category:\d+$/i.test(cleanUrl)) {
      return { type: 'category', label: `تصنيف #${Number(cleanUrl.split(':')[1])}`, icon: 'fas fa-folder' };
    }

    if (cleanUrl === 'offers' || cleanUrl === 'promotions') {
      return {
        type: 'offers',
        label: 'صفحة العروض والتخفيضات',
        icon: 'fas fa-tags',
      };
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return {
        type: 'external',
        label: cleanUrl,
        icon: 'fas fa-external-link-alt',
        url: cleanUrl,
      };
    }

    return {
      type: 'external',
      label: cleanUrl,
      icon: 'fas fa-link',
      url: cleanUrl,
    };
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.subs.unsubscribe();
  }
}
