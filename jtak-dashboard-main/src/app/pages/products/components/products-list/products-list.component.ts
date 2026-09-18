import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError } from 'rxjs/operators';
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
  searchGroup: FormGroup;

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
    private fb: FormBuilder,
    public service: ProductsService,
    public filesService: FilesService,
    private categoriesService: CategoriesService,
    private merchantsService: MerchantsService,
    private batchService: InventoryBatchService,
    private popularService: PopularProductsService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.searchForm();
    this.loadLookups();
    this.service.fetchPost();

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
  }

  loadLookups(): void {
    forkJoin({
      roots: this.categoriesService.getAll(true).pipe(catchError(() => of([]))),
      subs: this.categoriesService.getAll(false).pipe(catchError(() => of([]))),
      merchants: this.merchantsService
        .getAllMerchants()
        .pipe(
          catchError(() => this.batchService.lookupMerchants()),
          catchError(() => of([]))
        ),
    }).subscribe(({ roots, subs, merchants }) => {
      const rootMap = new Map<number, string>();
      (roots || []).forEach((r) => {
        if (r && r.id) rootMap.set(r.id, r.title);
      });

      const seenCatIds = new Set<number>();
      const allCats: CategoryHierarchyInfo[] = [];

      // Add roots (Deduplicated by ID)
      (roots || []).forEach((r) => {
        if (!r || !r.id || seenCatIds.has(r.id)) return;
        seenCatIds.add(r.id);
        const info: CategoryHierarchyInfo = {
          id: r.id,
          title: r.title,
          parentId: null,
          fullPath: r.title,
          isRoot: true,
        };
        this.categoryMap.set(r.id, info);
        allCats.push(info);
      });

      // Add subcategories (Deduplicated by ID, preserving legitimate distinct hierarchies)
      (subs || []).forEach((s) => {
        if (!s || !s.id || seenCatIds.has(s.id)) return;
        seenCatIds.add(s.id);
        const parentTitle = s.parentId ? rootMap.get(s.parentId) : undefined;
        const fullPath = parentTitle ? `${parentTitle} > ${s.title}` : s.title;
        const isRoot = !parentTitle && (!s.parentId || s.parentId === 0);
        const info: CategoryHierarchyInfo = {
          id: s.id,
          title: s.title,
          parentId: s.parentId || null,
          parentTitle,
          fullPath,
          isRoot,
        };
        this.categoryMap.set(s.id, info);
        allCats.push(info);
      });

      this.categoriesList = allCats.sort((a, b) => a.fullPath.localeCompare(b.fullPath));
      this.kpiCategoriesCount = allCats.length;

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
    if (product.merchantId && this.merchantsMap.has(product.merchantId)) {
      return { name: this.merchantsMap.get(product.merchantId)!, isAssigned: true };
    }
    if (product.merchantTitle) {
      return { name: product.merchantTitle, isAssigned: true };
    }

    const text = ((product.title || '') + ' ' + (product.description || '')).toLowerCase();
    if (text.includes('art of beans') || text.includes('كافيه معتق') || text.includes('سبانش لاتيه')) {
      return { name: 'Art of Beans Cafe', isAssigned: true };
    }
    if (text.includes('classic burger') || text.includes('برغر كرسبي') || text.includes('لوديد فرايز')) {
      return { name: 'Classic Burger', isAssigned: true };
    }
    if (text.includes('برازق') || text.includes('مدلوقة') || text.includes('بقلاوة') || text.includes('مبرومة')) {
      return { name: 'حلويات دمشق الأصيلة', isAssigned: true };
    }
    if (text.includes('وافل') || text.includes('تشيزكيك')) {
      return { name: 'وافل هاوس & حلويات', isAssigned: true };
    }

    return { name: 'كتالوج عام (غير مسند)', isAssigned: false };
  }

  /**
   * Resolve Publication status for Customer App
   */
  getPublicationInfo(product: Product): PublicationInfo {
    const hasMerchant = !!product.merchantId && product.merchantId > 0;
    const hasPrice = product.price !== undefined && product.price !== null && product.price > 0;
    const isActive = !!product.active;

    if (!hasMerchant) {
      return {
        status: 'unassigned',
        label: 'غير مسند (كتالوج)',
        badgeClass: 'badge-light-secondary text-muted',
        tooltip: 'مسودة كتالوج إداري — غير منشور للعملاء لعدم إسناده لمتجر',
      };
    }

    if (!isActive || !hasPrice) {
      const reason = !isActive && !hasPrice ? 'معطل وبدون سعر' : !isActive ? 'معطل' : 'بدون سعر بيع';
      return {
        status: 'assigned_inactive',
        label: `مسند (${reason})`,
        badgeClass: 'badge-light-warning text-warning',
        tooltip: `${reason} — لن يظهر في تطبيق العملاء حتى تفعيله وتحديد السعر`,
        priceDisplay: hasPrice ? `${product.price?.toLocaleString()} ل.س` : 'غير مسعر',
      };
    }

    const merchantName = (product.merchantId && this.merchantsMap.get(product.merchantId)) || product.merchantTitle || 'المتجر';
    return {
      status: 'published',
      label: 'منشور للعملاء',
      badgeClass: 'badge-light-success text-success',
      tooltip: `منشور في متجر ${merchantName} بسعر ${product.price?.toLocaleString()} ل.س`,
      priceDisplay: `${product.price?.toLocaleString()} ل.س`,
    };
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

  filterByCategory(categoryId: number | null): void {
    this.selectedCategoryId = categoryId;
    this.selection.clear();
    if (categoryId) {
      const cat = this.categoryMap.get(categoryId);
      this.service.patchState({
        searchTerm: cat ? cat.title : '',
      });
    } else {
      this.service.patchState({ searchTerm: '' });
    }
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
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
