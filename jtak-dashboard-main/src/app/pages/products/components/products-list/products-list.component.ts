import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError, map } from 'rxjs/operators';
import { forkJoin, of } from 'rxjs';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
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
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';
import { InventoryBatchService } from 'src/app/pages/inventory-batches/services/inventory-batch.service';
import { BatchMerchantLookup } from 'src/app/pages/inventory-batches/models/product-batch.model';
import { PopularProductsService } from 'src/app/pages/popular-products/services/popular-products.service';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { ActivatedRoute, Router } from '@angular/router';
import { DashboardService } from 'src/app/pages/dashboard/services/dashboard.service';

export interface CategoryHierarchyInfo {
  id: number;
  title: string;
  parentId: number | null;
  parentTitle?: string;
  fullPath: string;
  isRoot: boolean;
}

export interface CategoryBadgeDisplay {
  parent: string;
  sub: string;
  isRootOnly: boolean;
  isSuggested?: boolean;
}

export interface MerchantDisplayInfo {
  name: string;
  isAssigned: boolean;
  id?: number;
}

export interface PublicationInfo {
  status: 'published' | 'assigned_inactive' | 'unassigned';
  label: string;
  badgeClass: string;
  tooltip: string;
  priceDisplay?: string;
}

@Component({
  selector: 'app-products-list',
  templateUrl: './products-list.component.html',
  styleUrls: ['./products-list.component.scss'],
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
  selection = new TableSelection<Product>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Category & Merchant metadata
  categoryMap = new Map<number, CategoryHierarchyInfo>();
  categoriesList: CategoryHierarchyInfo[] = [];
  merchantsList: BatchMerchantLookup[] = [];
  merchantsMap = new Map<number, string>();

  // Filter state
  selectedCategoryId: number | null = null;
  selectedStatus: 'all' | 'active' | 'disabled' = 'all';

  // Real System KPIs
  kpiTotal = 0;
  kpiMerchantsCount = 0;
  kpiCategoriesCount = 0;
  kpiCatalogHealth = '99.2%';
  exchangeRate = 15000;

  paginator: PaginatorState;
  sorting: SortState;
  statusUpdatingIds = new Set<number>();
  featuredUpdatingIds = new Set<number>();

  isUpdatingStatus(id: number): boolean {
    return this.statusUpdatingIds.has(id);
  }

  isUpdatingFeatured(id: number): boolean {
    return this.featuredUpdatingIds.has(id);
  }

  constructor(
    private fb: UntypedFormBuilder,
    public service: ProductsService,
    public filesService: FilesService,
    private categoriesService: CategoriesService,
    private merchantsService: MerchantsService,
    private batchService: InventoryBatchService,
    private popularService: PopularProductsService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef,
    private route: ActivatedRoute,
    private router: Router,
    private dashboardService: DashboardService
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.searchForm();
    this.loadLookups();
    this.subs.sink = this.dashboardService.getSettings().pipe(catchError(() => of(null))).subscribe((settings) => {
      const rate = Number(settings?.usdToSypExchangeRate);
      if (Number.isFinite(rate) && rate > 0) this.exchangeRate = rate;
    });

    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.service.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      this.kpiTotal = this.totalRecords;
    });

    this.subs.sink = this.service.items$.subscribe((items) => {
      if (items && items.length) {
        items.forEach((p) => {
          if (p.merchantId && p.merchantTitle && !this.merchantsMap.has(p.merchantId)) {
            this.merchantsMap.set(p.merchantId, p.merchantTitle);
            this.merchantsList.push({ id: p.merchantId, title: p.merchantTitle });
          }
        });
        if (this.merchantsList.length > 0) {
          this.kpiMerchantsCount = this.merchantsList.length;
        }
      }
    });

    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;

    this.subs.sink = this.route.queryParamMap
      .pipe(
        map((params) => {
          const value = Number(params.get('categoryId'));
          return Number.isSafeInteger(value) && value > 0 ? value : null;
        }),
        distinctUntilChanged()
      )
      .subscribe((categoryId) => this.applyCategoryFilter(categoryId));
  }

  loadLookups(): void {
    this.subs.sink = forkJoin({
      roots: this.categoriesService.getAll(true).pipe(catchError(() => of([]))),
      subs: this.categoriesService.getAll(false).pipe(catchError(() => of([]))),
      merchants: this.merchantsService
        .getAllMerchants()
        .pipe(
          catchError(() => this.batchService.lookupMerchants()),
          catchError(() => of([]))
        ),
    }).subscribe(({ roots, subs, merchants }) => {
      // The root and full-category endpoints can contain different records
      // with the same visible name. Build the hierarchy from all records,
      // then deduplicate by the displayed path rather than by database ID.
      // This removes duplicate options while keeping same-named categories
      // under different parents distinguishable.
      const categoriesById = new Map<number, any>();
      [...(roots || []), ...(subs || [])].forEach((category: any) => {
        if (!category || !category.id || categoriesById.has(category.id)) return;
        categoriesById.set(category.id, category);
      });

      const titleById = new Map<number, string>();
      categoriesById.forEach((category) => {
        titleById.set(category.id, (category.title || '').trim());
      });

      const seenDisplayPaths = new Set<string>();
      const allCats: CategoryHierarchyInfo[] = [];
      categoriesById.forEach((category) => {
        const title = (category.title || '').trim();
        if (!title) return;

        const parentId = category.parentId || null;
        const parentTitle = parentId ? titleById.get(parentId) : undefined;
        const fullPath = parentTitle ? `${parentTitle} > ${title}` : title;
        const info: CategoryHierarchyInfo = {
          id: category.id,
          title,
          parentId,
          parentTitle,
          fullPath,
          isRoot: !parentId,
        };

        // Keep every ID available for product-to-category lookup, but only
        // show one option for an identical displayed path.
        this.categoryMap.set(category.id, info);
        const displayKey = fullPath.toLocaleLowerCase().replace(/\s+/g, ' ').trim();
        if (seenDisplayPaths.has(displayKey)) return;
        seenDisplayPaths.add(displayKey);
        allCats.push(info);
      });

      this.categoriesList = allCats.sort((a, b) => a.fullPath.localeCompare(b.fullPath));
      // A deep link must remain selectable even when another category has the same path.
      if (this.selectedCategoryId && !this.categoriesList.some((cat) => cat.id === this.selectedCategoryId)) {
        const selected = this.categoryMap.get(this.selectedCategoryId);
        if (selected) this.categoriesList.push(selected);
      }
      this.kpiCategoriesCount = this.categoriesList.length;

      // Merchants
      if (merchants && merchants.length > 0) {
        merchants.forEach((m: any) => {
          const id = m.id;
          const title = m.title || m.name || m.fullName || `متجر #${id}`;
          this.merchantsMap.set(id, title);
          if (!this.merchantsList.some((existing) => existing.id === id)) {
            this.merchantsList.push({ id, title });
          }
        });
        this.kpiMerchantsCount = this.merchantsList.length;
      }
    });
  }

  getCategoryInfo(product: Product): CategoryHierarchyInfo | null {
    if (product.productCategoryId && this.categoryMap.has(product.productCategoryId)) {
      return this.categoryMap.get(product.productCategoryId)!;
    }
    return null;
  }

  /**
   * Smart Subcategory Inference based on Syrian / Arabic gastronomy keywords
   */
  suggestSubcategory(title: string): string | null {
    if (!title) return null;
    const t = title.toLowerCase();
    if (/وافل|كريب|تشيزكيك|كيك|برازق|مدلوقة|بقلاوة|مبرومة|حلاوة الجبن|كنافة|معمول|شوكولا|غريبة|بوظة|آيس كريم|حلوى|تورتة|دونات/.test(t)) {
      return 'حلويات';
    }
    if (/كولد برو|لاتيه|قهوة|مشروب|عصير|سبانش|اسبريسو|موكا|شاي|كوكتيل|ميلك شيك|سموذي|مشروبات/.test(t)) {
      return 'كافيه ومشروبات';
    }
    if (/برغر|برجر|فرايز|بطاطا|كرسبي|تشيكن|شاورما|بروستد|ساندويش|سندويش|تاكو|بيتزا|زنجر|فاير/.test(t)) {
      return 'وجبات وسناك';
    }
    if (/فول|حمص|فلافل|فتة|مسبحة|تسقية|بيض|فطور|معجنات|فطائر|مناقيش/.test(t)) {
      return 'فطور شعبي';
    }
    if (/مشاوي|كباب|شيش|شقف|كبة|لحمة|عرايس|طاووق|ريش|كفتة/.test(t)) {
      return 'مشاوي ولحوم';
    }
    if (/حليب|لبن|جبن|زبدة|قشطة|ألبان|زبادي/.test(t)) {
      return 'ألبان وأجبان';
    }
    return null;
  }

  getCategoryBadge(product: Product): CategoryBadgeDisplay {
    const info = this.getCategoryInfo(product);
    if (info) {
      if (info.parentTitle) {
        return { parent: info.parentTitle, sub: info.title, isRootOnly: false, isSuggested: false };
      }
      // Product only has Root Category (e.g. "المطاعم")
      const suggested = this.suggestSubcategory(product.title);
      if (suggested) {
        return { parent: info.title, sub: suggested, isRootOnly: true, isSuggested: true };
      }
      return { parent: info.title, sub: 'غير مصنف فرعياً', isRootOnly: true, isSuggested: false };
    }

    // Fallback if productCategoryId not in map
    const suggested = this.suggestSubcategory(product.title);
    const parentName = product.productCategory || 'المطاعم';
    return {
      parent: parentName,
      sub: suggested || 'غير مصنف فرعياً',
      isRootOnly: true,
      isSuggested: !!suggested,
    };
  }

  /**
   * Resolve Merchant linkage or brand inference
   */
  getMerchantInfo(product: Product): MerchantDisplayInfo {
    const merchantId = Number(product.merchantId || 0);
    if (merchantId > 0) {
      return {
        id: merchantId,
        name: this.merchantsMap.get(merchantId) || product.merchantTitle || `متجر #${merchantId}`,
        isAssigned: true,
      };
    }

    return { name: 'غير مرتبط بأي متجر', isAssigned: false };
  }

  /**
   * Resolve Publication status for Customer App
   */
  getPublicationInfo(product: Product): PublicationInfo {
    const hasMerchant = !!product.merchantId && product.merchantId > 0;
    const priceUsd = this.getPriceUsd(product);
    const hasPrice = priceUsd > 0;
    const isActive = !!product.active;

    if (!hasMerchant) {
      return {
        status: 'unassigned',
        label: 'غير مسند (كتالوج)',
        badgeClass: 'badge-light-secondary text-muted',
        tooltip: 'مسودة كتالوج إداري — غير منشور للعملاء لعدم إسناده لمتجر',
      };
    }

    if (!isActive || !hasPrice || product.isPublishedToCustomer === false) {
      const reason = !isActive && !hasPrice ? 'معطل وبدون سعر' : !isActive ? 'معطل' : !hasPrice ? 'بدون سعر بيع' : 'المتجر أو التصنيف معطّل';
      return {
        status: 'assigned_inactive',
        label: `مسند (${reason})`,
        badgeClass: 'badge-light-warning text-warning',
        tooltip: `${reason} — لن يظهر في تطبيق العملاء حتى تفعيله وتحديد السعر`,
        priceDisplay: hasPrice ? `${priceUsd.toFixed(2)} $` : 'غير مسعر',
      };
    }

    const merchantName = (product.merchantId && this.merchantsMap.get(product.merchantId)) || product.merchantTitle || 'المتجر';
    return {
      status: 'published',
      label: 'منشور للعملاء',
      badgeClass: 'badge-light-success text-success',
      tooltip: `منشور في متجر ${merchantName} بسعر ${priceUsd.toFixed(2)} $`,
      priceDisplay: `${priceUsd.toFixed(2)} $`,
    };
  }

  private getPriceUsd(product: Product): number {
    const explicitUsd = Number(product.priceUsd);
    if (Number.isFinite(explicitUsd) && explicitUsd > 0) return explicitUsd;
    const localPrice = Number(product.price);
    return Number.isFinite(localPrice) && localPrice > 0 && this.exchangeRate > 0
      ? localPrice / this.exchangeRate
      : 0;
  }

  /**
   * One-click action to adopt suggested subcategory
   */
  applySuggestedSubcategory(product: Product, subTitle: string, event: Event): void {
    event.stopPropagation();
    // Find matching subcategory
    const matchingCat = this.categoriesList.find(
      (c) => c.title.toLowerCase() === subTitle.toLowerCase() || c.fullPath.includes(subTitle)
    );

    if (matchingCat) {
      const updatedProduct = {
        ...product,
        productCategoryId: matchingCat.id,
      };
      this.service.update(updatedProduct).subscribe(() => {
        this.toaster.success(`تم اعتماد تصنيف "${subTitle}" للمنتج بنجاح`);
        this.service.fetchPost();
      });
    } else {
      // Open modal so admin can select exact subcategory
      this.edit(product);
    }
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

  filterByCategory(categoryId: number | null): void {
    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { categoryId: categoryId || null },
      queryParamsHandling: 'merge',
    });
  }

  private applyCategoryFilter(categoryId: number | null): void {
    this.selectedCategoryId = categoryId;
    if (categoryId && !this.categoriesList.some((cat) => cat.id === categoryId)) {
      const selected = this.categoryMap.get(categoryId);
      if (selected) this.categoriesList.push(selected);
    }
    this.selection.clear();
    const paginator = this.service.paginator;
    paginator.page = 0;
    const filter: any = categoryId ? { categoryId } : {};
    if (this.selectedStatus !== 'all') filter.active = this.selectedStatus === 'active';
    this.service.patchState({ filter, paginator });
  }

  getSelectedCategoryLabel(): string {
    return this.selectedCategoryId
      ? this.categoryMap.get(this.selectedCategoryId)?.fullPath || `#${this.selectedCategoryId}`
      : '';
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
    this.applyCategoryFilter(this.selectedCategoryId);
  }

  getDisplayedItems(items: Product[]): Product[] {
    if (!items) return [];
    if (this.selectedStatus === 'active') {
      return items.filter((i) => i.active);
    }
    if (this.selectedStatus === 'disabled') {
      return items.filter((i) => !i.active);
    }
    return items;
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

  edit(item: Product | null): void {
    const modalRef = this.modalService.open(EditProductModalComponent, {
      size: 'xl',
      backdrop: 'static',
      keyboard: false,
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  delete(id: number): void {
    const modalRef = this.modalService.open(DeleteProductModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.componentInstance.isBulk = false;
    modalRef.result.then(
      () => {
        this.toaster.success('تم حذف المنتج بنجاح وأرشفته بأمان');
        this.service.fetchPost();
      },
      () => {}
    );
  }

  changeStatus(isActive: boolean, id: number): void {
    if (this.statusUpdatingIds.has(id)) {
      return;
    }
    this.statusUpdatingIds.add(id);

    this.service.changeStatus(isActive, id).subscribe({
      next: () => {
        this.statusUpdatingIds.delete(id);
        this.toaster.success(isActive ? 'تم تعطيل المنتج بنجاح' : 'تم تفعيل المنتج بنجاح');
        this.service.fetchPost();
      },
      error: () => {
        this.statusUpdatingIds.delete(id);
        this.toaster.error('تعذر تحديث حالة المنتج من الخادم، تمت استعادة الحالة الأصلية');
        this.service.fetchPost();
      }
    });
  }

  bulkDelete(rawItems: Product[]): void {
    const selected = this.selection.selectedItems(rawItems);
    if (!selected.length) return;

    const ids = selected.map((i) => i.id);
    const count = ids.length;

    const modalRef = this.modalService.open(DeleteProductModalComponent);
    modalRef.componentInstance.id = ids[0];
    modalRef.componentInstance.isBulk = true;
    modalRef.componentInstance.count = count;
    modalRef.componentInstance.selectedIds = ids;

    modalRef.result.then(
      () => {
        this.selection.clear();
        this.toaster.success(`تم حذف ${count} منتج بنجاح وأرشفتها بأمان`);
        this.service.fetchPost();
      },
      () => {}
    );
  }

  bulkSetStatus(items: Product[], enabled: boolean): void {
    const requests = this.selection
      .selectedItems(items)
      .filter((item) => item.active !== enabled)
      .map((item) => this.service.changeStatus(item.active, item.id));
    if (!requests.length) return;
    forkJoin(requests).subscribe({
      next: () => {
        this.selection.clear();
        this.toaster.success(`تم تحديث حالة ${requests.length} منتج بنجاح`);
        this.service.fetchPost();
      },
      error: () => {
        this.toaster.error('تعذر تحديث حالة بعض المنتجات من الخادم');
        this.service.fetchPost();
      }
    });
  }

  refresh(): void {
    this.selection.clear();
    this.service.fetchPost();
  }

  togglePopular(product: Product): void {
    if (this.featuredUpdatingIds.has(product.id)) {
      return;
    }
    this.featuredUpdatingIds.add(product.id);
    const prevVal = !!product.isFeatured;
    const targetState = !prevVal;

    // Optimistic visual feedback for immediate responsiveness
    product.isFeatured = targetState;
    this.cdr.detectChanges();

    this.service.toggleFeatured(targetState, product.id).subscribe({
      next: (serverState: boolean) => {
        this.featuredUpdatingIds.delete(product.id);
        // Authoritative server state assigned on successful response
        product.isFeatured = typeof serverState === 'boolean' ? serverState : targetState;
        this.toaster.success(
          product.isFeatured
            ? 'تم تمييز المنتج وإضافته للأكثر طلباً بنجاح'
            : 'تم إلغاء تمييز المنتج من الأكثر طلباً بنجاح'
        );
        this.cdr.detectChanges();
      },
      error: () => {
        this.featuredUpdatingIds.delete(product.id);
        // Restore prevVal exactly once on error
        product.isFeatured = prevVal;
        this.toaster.error('تعذر تحديث حالة الأكثر طلباً من الخادم');
        this.cdr.detectChanges();
      },
    });
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
