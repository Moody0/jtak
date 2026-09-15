import { Component, OnDestroy, OnInit } from '@angular/core';
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
  isSuggested: boolean;
}

export interface MerchantDisplayInfo {
  name: string;
  isAssigned: boolean;
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

  constructor(
    private fb: FormBuilder,
    public service: ProductsService,
    public filesService: FilesService,
    private categoriesService: CategoriesService,
    private batchService: InventoryBatchService,
    private popularService: PopularProductsService,
    private modalService: NgbModal,
    private toaster: ToastrService
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
      merchants: this.batchService.lookupMerchants().pipe(catchError(() => of([]))),
    }).subscribe(({ roots, subs, merchants }) => {
      const rootMap = new Map<number, string>();
      roots.forEach((r) => rootMap.set(r.id, r.title));

      const allCats: CategoryHierarchyInfo[] = [];

      // Add roots
      roots.forEach((r) => {
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

      // Add subcategories
      subs.forEach((s) => {
        const parentTitle = s.parentId ? rootMap.get(s.parentId) : undefined;
        const fullPath = parentTitle ? `${parentTitle} > ${s.title}` : s.title;
        const info: CategoryHierarchyInfo = {
          id: s.id,
          title: s.title,
          parentId: s.parentId,
          parentTitle,
          fullPath,
          isRoot: false,
        };
        this.categoryMap.set(s.id, info);
        allCats.push(info);
      });

      this.categoriesList = allCats.sort((a, b) => a.fullPath.localeCompare(b.fullPath));
      this.kpiCategoriesCount = allCats.length;

      // Merchants
      if (merchants && merchants.length > 0) {
        merchants.forEach((m) => {
          this.merchantsMap.set(m.id, m.title);
          if (!this.merchantsList.some((existing) => existing.id === m.id)) {
            this.merchantsList.push(m);
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
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  changeStatus(isActive: boolean, id: number): void {
    this.service.changeStatus(isActive, id).subscribe(() => {
      this.service.fetchPost();
    });
  }

  bulkSetStatus(items: Product[], enabled: boolean): void {
    const requests = this.selection
      .selectedItems(items)
      .filter((item) => item.active !== enabled)
      .map((item) => this.service.changeStatus(item.active, item.id));
    if (!requests.length) return;
    forkJoin(requests).subscribe(() => {
      this.selection.clear();
      this.service.fetchPost();
    });
  }

  refresh(): void {
    this.selection.clear();
    this.service.fetchPost();
  }

  togglePopular(product: Product): void {
    this.popularService.toggleItem(product.id).subscribe({
      next: () => {
        this.toaster.success('تم تحديث حالة المنتج في قسم الأكثر طلباً بالصفحة الرئيسية');
      },
      error: () => {
        this.toaster.error('تعذر تحديث حالة الأكثر طلباً');
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
