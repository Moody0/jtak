import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
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
import { forkJoin } from 'rxjs';
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
  selection = new TableSelection<Banner>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: FormGroup;

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
    private fb: FormBuilder,
    public bannersService: BannersService,
    private merchantsService: MerchantsService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.bannersService.setDefaults();
    this.searchForm();
    this.bannersService.fetchPost();

    this.subs.sink = this.merchantsService.getAllMerchants().subscribe({
      next: (merchants) => {
        if (merchants) {
          merchants.forEach((m) => this.merchantsMap.set(Number(m.id), m));
          this.cdr.detectChanges();
        }
      },
    });

    this.subs.sink = this.bannersService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.bannersService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiTotal) {
        this.kpiTotal = this.totalRecords;
      }
    });

    this.subs.sink = this.bannersService.items$.subscribe((items) => {
      if (items && items.length) {
        this.calculateKpis(items);
      }
    });

    this.sorting = this.bannersService.sorting;
    this.paginator = this.bannersService.paginator;
  }

  calculateKpis(items: Banner[]): void {
    if (!items || !items.length) return;
    this.kpiTotal = this.totalRecords > items.length ? this.totalRecords : items.length;
    this.kpiActive = items.filter((b) => b.active).length;
    this.kpiDaily = items.filter((b) => this.isDailyOffers(b) || this.isAllSections(b)).length;
    this.kpiDontMiss = items.filter((b) => this.isDontMiss(b) || this.isAllSections(b)).length;
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
    this.bannersService.patchState({ searchTerm });
  }

  filterBySection(section: 'all' | 'daily' | 'dont_miss' | 'both'): void {
    this.selectedSection = section;
    this.selection.clear();
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
  }

  getDisplayedItems(items: Banner[]): Banner[] {
    if (!items) return [];

    return items.filter((banner) => {
      // Section filter
      if (this.selectedSection === 'daily' && !this.isDailyOffers(banner) && !this.isAllSections(banner)) {
        return false;
      }
      if (this.selectedSection === 'dont_miss' && !this.isDontMiss(banner) && !this.isAllSections(banner)) {
        return false;
      }
      if (this.selectedSection === 'both' && !this.isAllSections(banner)) {
        return false;
      }

      // Status filter
      if (this.selectedStatus === 'active' && !banner.active) return false;
      if (this.selectedStatus === 'disabled' && banner.active) return false;

      return true;
    });
  }

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
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  delete(id: string): void {
    const modalRef = this.modalService.open(DeleteBannerModalComponent, {
      size: 'md',
    });
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  toggleBannerStatus(banner: Banner): void {
    const updated = { ...banner, active: !banner.active };
    this.bannersService.update(updated as any).subscribe(() => {
      this.toaster.success(
        updated.active
          ? 'تم تفعيل الإعلان بنجاح'
          : 'تم تعطيل الإعلان بنجاح'
      );
      this.refresh();
    });
  }

  bulkSetStatus(items: Banner[], targetActive: boolean): void {
    const requests = this.selection
      .selectedItems(items)
      .filter((item) => item.active !== targetActive)
      .map((item) => this.bannersService.update({ ...item, active: targetActive } as any));

    if (!requests.length) return;

    forkJoin(requests).subscribe(() => {
      this.toaster.success(
        targetActive
          ? 'تم تفعيل الإعلانات المحددة بنجاح'
          : 'تم تعطيل الإعلانات المحددة بنجاح'
      );
      this.selection.clear();
      this.refresh();
    });
  }

  bulkDelete(items: Banner[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'banner' : 'banners';
    modalRef.componentInstance.action = () =>
      forkJoin(selected.map((item) => this.bannersService.delete(item.id)));
    modalRef.result.then(
      () => {
        this.selection.clear();
        this.refresh();
      },
      () => {}
    );
  }

  refresh(): void {
    this.selection.clear();
    this.bannersService.fetchPost();
  }

  isRestaurants(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    const desc = (banner?.description || '').toLowerCase();
    return banner?.bannerLocation === 2 || url.includes('section:restaurant') || desc.includes('restaurants') || desc.includes('مطاعم');
  }

  isMarket(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    const desc = (banner?.description || '').toLowerCase();
    return banner?.bannerLocation === 3 || url.includes('section:market') || desc.includes('market') || desc.includes('ماركت');
  }

  isDontMiss(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    const desc = (banner?.description || '').toLowerCase();
    return banner?.bannerLocation === 1 || url.includes('section:dontmiss') || desc.includes('dontmiss') || desc.includes('لا تفوتها');
  }

  isAllSections(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    return banner?.bannerLocation === 4 || url.includes('section:all');
  }

  isDailyOffers(banner: Banner): boolean {
    return !this.isDontMiss(banner) && !this.isAllSections(banner) && !this.isRestaurants(banner) && !this.isMarket(banner);
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  getTargetInfo(banner: Banner): {
    type: 'none' | 'restaurant' | 'market' | 'offers' | 'external';
    label: string;
    icon: string;
    url?: string;
  } {
    const rawUrl = (banner?.url || '').trim();
    const cleanUrl = rawUrl.replace(/#section:[a-z_]+/g, '').trim();

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

    if (cleanUrl.startsWith('market:') || cleanUrl.startsWith('merchant:')) {
      const id = parseInt(cleanUrl.split(':')[1], 10);
      const m = this.merchantsMap.get(id);
      return {
        type: 'market',
        label: m ? `متجر: ${m.title}` : `متجر #${id}`,
        icon: 'fas fa-shopping-basket',
      };
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
    this.subs.unsubscribe();
  }
}
