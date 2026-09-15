import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { forkJoin } from 'rxjs';
import { SubSink } from 'subsink';
import { ToastrService } from 'ngx-toastr';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { Merchant } from '../../models/merchant.model';
import { ProductMerchant } from '../../models/product-merchant.model';
import { MerchantsService } from '../../services/merchants.service';
import { ProductMerchantsService } from '../../services/product-merchants.service';
import { EditMerchantModalComponent } from '../edit-merchant-modal/edit-merchant-modal.component';
import { EditProductModalComponent } from 'src/app/pages/products/components/edit-product-modal/edit-product-modal.component';
import { EditCategoryModalComponent } from 'src/app/pages/categories/components/edit-category-modal/edit-category-modal.component';
import { Product } from 'src/app/pages/products/models/product.model';
import { Category } from 'src/app/pages/categories/models/Category.model';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';
import { ProductsService } from 'src/app/pages/products/services/products.service';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { PaginatorState } from 'src/app/_metronic/shared/crud-table';

interface MerchantCategorySummary {
  id: number;
  name: string;
  parentId: number | null;
  parent: string;
  isMain: boolean;
  total: number;
  enabled: number;
  totalProducts: number;
  enabledProducts: number;
  subcategoriesCount: number;
  active: boolean;
  icon: string;
  subcategories: MerchantCategorySummary[];
}

@Component({
  selector: 'app-merchant-workspace',
  templateUrl: './merchant-workspace.component.html',
  styleUrls: ['./merchant-workspace.component.scss'],
})
export class MerchantWorkspaceComponent implements OnInit, OnDestroy {
  private readonly subs = new SubSink();
  private merchantId = 0;
  private originalProducts: ProductMerchant[] = [];

  merchant: Merchant | null = null;
  products: ProductMerchant[] = [];
  selectedProductIds = new Set<number>();
  catalogCategories: Category[] = [];
  paginator: PaginatorState = new PaginatorState();
  activeTab = 'overview';
  searchTerm = '';
  categoryFilter = '';
  categorySearchTerm = '';
  categoryLevelFilter: 'all' | 'main' | 'sub' = 'all';
  selectedMainCategoryId: number | null = null;
  categoryViewMode: 'grouped' | 'grid' = 'grouped';
  collapsedMainCategoryIds = new Set<number>();
  categoryScopeFilter: 'merchant' | 'system' = 'merchant';
  isLoading = true;
  isSaving = false;
  loadError = false;
  private merchantCategoryOverrides = new Map<string, { icon?: string; active?: boolean }>();

  loadMerchantCategoryOverrides(): void {
    this.merchantCategoryOverrides.clear();
    try {
      const raw = localStorage.getItem(`jtak_merchant_cat_overrides_${this.merchantId}`);
      if (raw) {
        const parsed = JSON.parse(raw);
        this.merchantCategoryOverrides = new Map(Object.entries(parsed));
      } else if (this.merchantId === 19) {
        this.saveMerchantCategoryOverride('مشروبات', '2026_9_9_3ae93292b1cf4576a06055f5c19d2996.webp', true);
      }
    } catch {
      // Storage unavailable
    }
  }

  saveMerchantCategoryOverride(categoryName: string, icon: string, active: boolean): void {
    const key = categoryName.trim().toLowerCase();
    this.merchantCategoryOverrides.set(key, { icon, active });
    try {
      const obj: { [key: string]: { icon?: string; active?: boolean } } = {};
      this.merchantCategoryOverrides.forEach((val, k) => {
        obj[k] = val;
      });
      localStorage.setItem(`jtak_merchant_cat_overrides_${this.merchantId}`, JSON.stringify(obj));
    } catch {
      // Storage unavailable
    }
  }

  constructor(
    private route: ActivatedRoute,
    private merchantsService: MerchantsService,
    private productMerchantsService: ProductMerchantsService,
    private categoriesService: CategoriesService,
    private productsService: ProductsService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef,
    public filesService: FilesService
  ) {}

  ngOnInit(): void {
    this.paginator.page = 0;
    this.paginator.pageSize = 25;
    this.paginator.pageSizes = [10, 25, 50, 100];
    this.subs.sink = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      const tab = params.get('tab') || 'overview';
      this.activeTab = ['overview', 'products', 'categories'].includes(tab) ? tab : 'overview';
      if (id && id !== this.merchantId) {
        this.merchantId = id;
        this.loadWorkspace();
      }
    });
  }

  get merchantTitleAr(): string {
    const raw = this.merchant?.title || '';
    if (!raw.includes(' - ')) return raw;
    const parts = raw.split(' - ').map((s) => s.trim());
    return parts.find((p) => /[\u0600-\u06FF]/.test(p)) || parts[0];
  }

  get merchantTitleEn(): string {
    const raw = this.merchant?.title || '';
    if (!raw.includes(' - ')) return '';
    const parts = raw.split(' - ').map((s) => s.trim());
    return parts.find((p) => !/[\u0600-\u06FF]/.test(p)) || '';
  }

  get merchantProducts(): ProductMerchant[] {
    return this.products.filter((item) => item.isSelected || item.merchantId === this.merchantId);
  }

  get enabledProductsCount(): number {
    return this.merchantProducts.filter((item) => item.isSelected).length;
  }

  get categoryNames(): string[] {
    return Array.from(new Set(this.merchantProducts.map((item) => this.categoryName(item)))).sort();
  }

  get visibleProducts(): ProductMerchant[] {
    const search = this.searchTerm.trim().toLocaleLowerCase();
    return this.merchantProducts.filter((item) => {
      const matchesCategory = !this.categoryFilter || this.categoryName(item) === this.categoryFilter;
      const haystack = `${item.product} ${item.productCat1 || ''} ${item.productCat2 || ''}`.toLocaleLowerCase();
      return matchesCategory && (!search || haystack.includes(search));
    });
  }

  get paginatedProducts(): ProductMerchant[] {
    const list = this.visibleProducts;
    this.paginator.total = list.length;
    const maxPageIndex = Math.max(0, Math.ceil(list.length / this.paginator.pageSize) - 1);
    if (this.paginator.page > maxPageIndex) {
      this.paginator.page = maxPageIndex;
    }
    if (this.paginator.page < 0) {
      this.paginator.page = 0;
    }
    const start = this.paginator.page * this.paginator.pageSize;
    return list.slice(start, start + this.paginator.pageSize);
  }

  onProductFilterChange(): void {
    this.paginator.page = 0;
    this.cdr.detectChanges();
  }

  paginate(paginator: PaginatorState): void {
    this.paginator.page = paginator.page ?? 0;
    this.paginator.pageSize = paginator.pageSize || 25;
    this.cdr.detectChanges();
  }

  get allCategorizedData(): {
    mainCategories: MerchantCategorySummary[];
    subCategories: MerchantCategorySummary[];
    flatCategories: MerchantCategorySummary[];
  } {
    const categoryMap = new Map<number, MerchantCategorySummary>();
    const virtualMap = new Map<string, MerchantCategorySummary>();

    // 1. Initialize all catalog categories
    this.catalogCategories.forEach((cat) => {
      const isMain = !cat.parentId || cat.parentId === 0;
      categoryMap.set(cat.id, {
        id: cat.id,
        name: cat.title,
        parentId: cat.parentId || null,
        parent: cat.parent || '',
        isMain,
        total: 0,
        enabled: 0,
        totalProducts: 0,
        enabledProducts: 0,
        subcategoriesCount: 0,
        active: cat.active,
        icon: cat.icon || '',
        subcategories: [],
      });
    });

    // 2. Count products in each category
    this.merchantProducts.forEach((item) => {
      const matchedCat = (item.productCategoryId && categoryMap.has(item.productCategoryId))
        ? categoryMap.get(item.productCategoryId)
        : this.resolveCategoryForProduct(item);

      if (matchedCat && categoryMap.has(matchedCat.id)) {
        const catSummary = categoryMap.get(matchedCat.id)!;
        catSummary.total += 1;
        if (item.isSelected) catSummary.enabled += 1;
      } else {
        const key = item.productCat1 || 'Uncategorized';
        let virt = virtualMap.get(key);
        if (!virt) {
          virt = {
            id: 0,
            name: key,
            parentId: null,
            parent: item.productCat2 || '',
            isMain: !item.productCat2,
            total: 0,
            enabled: 0,
            totalProducts: 0,
            enabledProducts: 0,
            subcategoriesCount: 0,
            active: item.categoryActive !== false,
            icon: item.categoryIcon || '',
            subcategories: [],
          };
          virtualMap.set(key, virt);
        }
        virt.total += 1;
        if (item.isSelected) virt.enabled += 1;
      }
    });

    const allCatSummaries = Array.from(categoryMap.values()).concat(Array.from(virtualMap.values()));

    const mainList: MerchantCategorySummary[] = [];
    const subList: MerchantCategorySummary[] = [];

    allCatSummaries.forEach((cat) => {
      if (cat.isMain) {
        mainList.push(cat);
      } else {
        subList.push(cat);
      }
    });

    const mainById = new Map<number, MerchantCategorySummary>();
    const mainByName = new Map<string, MerchantCategorySummary>();
    mainList.forEach((m) => {
      if (m.id) mainById.set(m.id, m);
      mainByName.set(m.name.trim().toLowerCase(), m);
    });

    subList.forEach((sub) => {
      let parentMain: MerchantCategorySummary | undefined;
      if (sub.parentId && mainById.has(sub.parentId)) {
        parentMain = mainById.get(sub.parentId);
      } else if (sub.parent && sub.parent.trim().length > 0) {
        parentMain = mainByName.get(sub.parent.trim().toLowerCase());
      }

      if (!parentMain && sub.parent && sub.parent.trim().length > 0) {
        const parentKey = sub.parent.trim().toLowerCase();
        if (!mainByName.has(parentKey)) {
          const newMain: MerchantCategorySummary = {
            id: 0,
            name: sub.parent.trim(),
            parentId: null,
            parent: '',
            isMain: true,
            total: 0,
            enabled: 0,
            totalProducts: 0,
            enabledProducts: 0,
            subcategoriesCount: 0,
            active: true,
            icon: '',
            subcategories: [],
          };
          mainList.push(newMain);
          mainByName.set(parentKey, newMain);
          parentMain = newMain;
        } else {
          parentMain = mainByName.get(parentKey);
        }
      }

      if (parentMain && !parentMain.subcategories.includes(sub)) {
        parentMain.subcategories.push(sub);
      }
    });

    mainList.forEach((m) => {
      let subTotal = 0;
      let subEnabled = 0;
      m.subcategories.sort((a, b) => a.name.localeCompare(b.name));
      m.subcategories.forEach((s) => {
        s.totalProducts = s.total;
        s.enabledProducts = s.enabled;
        subTotal += s.total;
        subEnabled += s.enabled;
      });
      m.subcategoriesCount = m.subcategories.length;
      m.totalProducts = m.total + subTotal;
      m.enabledProducts = m.enabled + subEnabled;
    });

    subList.forEach((s) => {
      s.totalProducts = s.total;
      s.enabledProducts = s.enabled;
    });

    mainList.sort((a, b) => {
      const aHas = (a.totalProducts > 0 || a.subcategories.length > 0) ? 1 : 0;
      const bHas = (b.totalProducts > 0 || b.subcategories.length > 0) ? 1 : 0;
      if (aHas !== bHas) return bHas - aHas;
      return a.name.localeCompare(b.name);
    });
    subList.sort((a, b) => a.name.localeCompare(b.name));

    return {
      mainCategories: mainList,
      subCategories: subList,
      flatCategories: allCatSummaries.sort((a, b) => a.name.localeCompare(b.name)),
    };
  }

  setCategoryScope(scope: 'merchant' | 'system'): void {
    this.categoryScopeFilter = scope;
    this.selectedMainCategoryId = null;
    this.cdr.detectChanges();
  }

  get merchantCategorizedData(): {
    mainCategories: MerchantCategorySummary[];
    subCategories: MerchantCategorySummary[];
    flatCategories: MerchantCategorySummary[];
  } {
    const system = this.allCategorizedData;

    const mainCategories = system.mainCategories
      .filter((m) => m.enabledProducts > 0 || m.enabled > 0 || m.subcategories.some((s) => s.enabled > 0))
      .map((m) => {
        const merchantSubs = m.subcategories
          .filter((s) => s.enabled > 0)
          .map((s) => ({
            ...s,
            total: s.enabled,
          }));
        return {
          ...m,
          totalProducts: m.enabledProducts,
          subcategoriesCount: merchantSubs.length,
          subcategories: merchantSubs,
        };
      });

    const normalizeCategoryKey = (name: string): string => {
      const s = (name || '').trim();
      if (s === 'اجبان وألبان' || s === 'أجبان وألبان' || s === 'ألبان وأجبان' || s === 'البان واجبان' || s === 'ألبان واأجبان') {
        return 'ألبان وأجبان';
      }
      if (s === 'غذائية') return 'غذائيات';
      return s;
    };

    // Merge duplicate main categories sharing the same name or spelling variations
    const groupedByName = new Map<string, MerchantCategorySummary>();
    mainCategories.forEach((m) => {
      const normName = normalizeCategoryKey(m.name);
      const key = normName.toLowerCase();
      const existing = groupedByName.get(key);
      if (!existing) {
        groupedByName.set(key, { ...m, name: normName, subcategories: [...m.subcategories] });
      } else {
        existing.totalProducts += m.totalProducts;
        existing.enabledProducts += m.enabledProducts;
        existing.total += m.total;
        existing.enabled += m.enabled;
        if (!existing.icon && m.icon) existing.icon = m.icon;
        m.subcategories.forEach((s) => {
          const normSubName = s.name.trim() === 'اجبان' ? 'أجبان' : s.name.trim();
          const found = existing.subcategories.find(
            (ex) => ex.name.trim() === normSubName || (ex.id && ex.id === s.id)
          );
          if (!found) {
            existing.subcategories.push({ ...s, name: normSubName });
          } else {
            found.total += s.total;
            found.enabled += s.enabled;
            found.totalProducts += s.totalProducts;
            found.enabledProducts += s.enabledProducts;
          }
        });
        existing.subcategories.sort((a, b) => a.name.localeCompare(b.name));
        existing.subcategoriesCount = existing.subcategories.length;
      }
    });

    const mergedMainCategories = Array.from(groupedByName.values())
      .map((m) => {
        const override = this.merchantCategoryOverrides.get(m.name.trim().toLowerCase());
        return {
          ...m,
          icon: override?.icon || m.icon,
          active: override?.active !== undefined ? override.active : m.active,
        };
      })
      .sort((a, b) => a.name.localeCompare(b.name));

    const subCategoriesMap = new Map<string, MerchantCategorySummary>();
    system.subCategories
      .filter((s) => s.enabled > 0)
      .forEach((s) => {
        const normName = s.name.trim() === 'اجبان' ? 'أجبان' : s.name.trim();
        const normParent = normalizeCategoryKey(s.parent);
        const subKey = `${normParent}:::${normName}`;
        const existing = subCategoriesMap.get(subKey);
        if (!existing) {
          const override = this.merchantCategoryOverrides.get(normName.toLowerCase());
          subCategoriesMap.set(subKey, {
            ...s,
            name: normName,
            parent: normParent,
            icon: override?.icon || s.icon,
            active: override?.active !== undefined ? override.active : s.active,
          });
        } else {
          existing.total += s.enabled;
          existing.enabled += s.enabled;
          existing.totalProducts += s.totalProducts;
          existing.enabledProducts += s.enabledProducts;
        }
      });

    const subCategories = Array.from(subCategoriesMap.values()).sort((a, b) => a.name.localeCompare(b.name));

    const flatCategories = [...mergedMainCategories, ...subCategories].sort((a, b) => a.name.localeCompare(b.name));

    return {
      mainCategories: mergedMainCategories,
      subCategories,
      flatCategories,
    };
  }

  get merchantMainCount(): number {
    return this.merchantCategorizedData.mainCategories.length;
  }

  get merchantSubCount(): number {
    return this.merchantCategorizedData.subCategories.length;
  }

  get systemMainCount(): number {
    return this.allCategorizedData.mainCategories.length;
  }

  get systemSubCount(): number {
    return this.allCategorizedData.subCategories.length;
  }

  get categories(): MerchantCategorySummary[] {
    return this.categoryScopeFilter === 'merchant'
      ? this.merchantCategorizedData.flatCategories
      : this.allCategorizedData.flatCategories;
  }

  get mainCategories(): MerchantCategorySummary[] {
    return this.categoryScopeFilter === 'merchant'
      ? this.merchantCategorizedData.mainCategories
      : this.allCategorizedData.mainCategories;
  }

  get subCategories(): MerchantCategorySummary[] {
    return this.categoryScopeFilter === 'merchant'
      ? this.merchantCategorizedData.subCategories
      : this.allCategorizedData.subCategories;
  }

  get displayMainCategories(): MerchantCategorySummary[] {
    const search = this.categorySearchTerm.trim().toLowerCase();
    return this.mainCategories.filter((main) => {
      if (this.selectedMainCategoryId && main.id !== this.selectedMainCategoryId) {
        return false;
      }
      if (!search) {
        if (!this.selectedMainCategoryId && main.totalProducts === 0 && main.subcategories.length === 0) {
          return false;
        }
        return true;
      }
      const matchesMain = main.name.toLowerCase().includes(search);
      const matchesSub = main.subcategories.some((s) => s.name.toLowerCase().includes(search));
      return matchesMain || matchesSub;
    });
  }

  get displaySubCategories(): MerchantCategorySummary[] {
    const search = this.categorySearchTerm.trim().toLowerCase();
    return this.subCategories.filter((sub) => {
      if (this.selectedMainCategoryId && sub.parentId !== this.selectedMainCategoryId) {
        return false;
      }
      if (!search) return true;
      const matchesName = sub.name.toLowerCase().includes(search);
      const matchesParent = (sub.parent || '').toLowerCase().includes(search);
      return matchesName || matchesParent;
    });
  }

  get displayFlatCategories(): MerchantCategorySummary[] {
    const search = this.categorySearchTerm.trim().toLowerCase();
    return this.categories.filter((cat) => {
      if (this.categoryLevelFilter === 'main' && !cat.isMain) return false;
      if (this.categoryLevelFilter === 'sub' && cat.isMain) return false;
      if (this.selectedMainCategoryId) {
        if (cat.isMain && cat.id !== this.selectedMainCategoryId) return false;
        if (!cat.isMain && cat.parentId !== this.selectedMainCategoryId) return false;
      }
      if (!search) return true;
      const matchesName = cat.name.toLowerCase().includes(search);
      const matchesParent = (cat.parent || '').toLowerCase().includes(search);
      return matchesName || matchesParent;
    });
  }

  get hasChanges(): boolean {
    return this.products.some((item) => {
      const original = this.originalProducts.find((candidate) => candidate.productId === item.productId);
      return !original || original.isSelected !== item.isSelected || Number(original.additionalProfitPercent) !== Number(item.additionalProfitPercent);
    });
  }

  loadWorkspace(): void {
    this.isLoading = true;
    this.loadError = false;
    this.merchant = this.merchantsService.getWorkspaceMerchant(this.merchantId)
      || this.createMerchantPlaceholder(this.merchantId);
    this.loadMerchantCategoryOverrides();

    this.subs.sink = forkJoin({
      products: this.productMerchantsService.getProducts(this.merchantId),
      categories: this.categoriesService.getAll(false, true),
      rootCategories: this.categoriesService.getAll(true, true),
    }).subscribe({
      next: ({ products: response, categories, rootCategories }: any) => {
        const rootMap = new Map<number, string>();
        (rootCategories || []).forEach((r: any) => rootMap.set(r.id, (r.title || '').trim()));
        const roots = (rootCategories || []).map((r: any) => ({
          ...r,
          parentId: null,
          parent: '',
        }));
        const subs = (categories || []).map((c: any) => ({
          ...c,
          parent: c.parent || (c.parentId ? rootMap.get(c.parentId) || '' : ''),
        }));
        this.catalogCategories = [...roots, ...subs];

        this.products = (response || []).map((item: ProductMerchant) => {
          const resolvedCat = this.resolveCategoryForProduct(item);
          return {
            ...item,
            productCategoryId: item.productCategoryId || (resolvedCat ? resolvedCat.id : 0),
            isSelected: item.merchantId === this.merchantId,
          };
        });
        this.originalProducts = this.products.map((item) => ({ ...item }));
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.loadError = true;
        this.cdr.detectChanges();
      },
    });
  }

  toggleProduct(item: ProductMerchant, selected: boolean): void {
    item.isSelected = selected;
  }

  get selectedProductsCount(): number {
    return this.selectedProductIds.size;
  }

  isProductRowSelected(item: ProductMerchant): boolean {
    return this.selectedProductIds.has(item.productId);
  }

  toggleProductRowSelection(item: ProductMerchant, selected: boolean): void {
    if (selected) {
      this.selectedProductIds.add(item.productId);
    } else {
      this.selectedProductIds.delete(item.productId);
    }
  }

  toggleAllVisible(selected: boolean): void {
    if (selected) {
      this.paginatedProducts.forEach((item) => this.selectedProductIds.add(item.productId));
    } else {
      this.paginatedProducts.forEach((item) => this.selectedProductIds.delete(item.productId));
    }
  }

  toggleAllFiltered(selected: boolean): void {
    if (selected) {
      this.visibleProducts.forEach((item) => this.selectedProductIds.add(item.productId));
    } else {
      this.visibleProducts.forEach((item) => this.selectedProductIds.delete(item.productId));
    }
  }

  clearProductSelection(): void {
    this.selectedProductIds.clear();
  }

  allVisibleSelected(): boolean {
    return (
      this.paginatedProducts.length > 0 &&
      this.paginatedProducts.every((item) => this.selectedProductIds.has(item.productId))
    );
  }

  someVisibleSelected(): boolean {
    const selectedCount = this.paginatedProducts.filter((item) =>
      this.selectedProductIds.has(item.productId)
    ).length;
    return selectedCount > 0 && selectedCount < this.paginatedProducts.length;
  }

  deleteSelectedProducts(): void {
    const ids = Array.from(this.selectedProductIds);
    if (!ids.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = ids.length;
    modalRef.componentInstance.itemLabel = ids.length === 1 ? 'منتج' : 'منتجات';
    modalRef.componentInstance.actionLabel = 'حذف المنتجات المحددة';
    modalRef.componentInstance.description = `هل أنت متأكد من حذف ${ids.length} منتج من الكتالوج العام نهائياً؟ لا يمكن التراجع عن هذا الإجراء.`;
    modalRef.componentInstance.action = () => forkJoin(ids.map((id) => this.productsService.delete(id)));
    modalRef.result.then(
      () => {
        const idSet = new Set(ids);
        this.products = this.products.filter((product) => !idSet.has(product.productId));
        this.originalProducts = this.originalProducts.filter((product) => !idSet.has(product.productId));
        this.selectedProductIds.clear();
        this.toaster.success(`تم حذف ${ids.length} منتج بنجاح`);
        this.cdr.detectChanges();
      },
      () => {}
    );
  }

  bulkEnableInMerchant(): void {
    const ids = this.selectedProductIds;
    if (!ids.size) return;
    let modified = 0;
    this.products.forEach((p) => {
      if (ids.has(p.productId) && !p.isSelected) {
        p.isSelected = true;
        modified++;
      }
    });
    this.selectedProductIds.clear();
    this.toaster.success(`تم تفعيل ${modified} منتج في متجر التاجر`);
    this.cdr.detectChanges();
  }

  bulkRemoveFromMerchant(): void {
    const ids = this.selectedProductIds;
    if (!ids.size) return;
    let modified = 0;
    this.products.forEach((p) => {
      if (ids.has(p.productId) && p.isSelected) {
        p.isSelected = false;
        modified++;
      }
    });
    this.selectedProductIds.clear();
    this.toaster.info(`تم تعطيل ${modified} منتج من متجر التاجر`);
    this.cdr.detectChanges();
  }

  bulkSetExtraProfit(percent: number): void {
    const ids = this.selectedProductIds;
    if (!ids.size) return;
    let modified = 0;
    this.products.forEach((p) => {
      if (ids.has(p.productId)) {
        p.additionalProfitPercent = percent;
        modified++;
      }
    });
    this.toaster.success(`تم تطبيق نسبة ربح ${percent}% على ${modified} منتج`);
    this.cdr.detectChanges();
  }

  toggleCategory(category: MerchantCategorySummary, enabled: boolean): void {
    if (category.isMain) {
      const subcategoryIds = new Set(category.subcategories.map((s) => s.id).filter((id) => id > 0));
      const subcategoryNames = new Set(category.subcategories.map((s) => s.name.trim().toLowerCase()));
      const mainName = category.name.trim().toLowerCase();

      this.products.forEach((item) => {
        let matches = false;
        if (category.id && item.productCategoryId === category.id) matches = true;
        if (item.productCategoryId && subcategoryIds.has(item.productCategoryId)) matches = true;
        const itemCat2 = (item.productCat2 || '').trim();
        if (itemCat2.toLowerCase() === mainName || (mainName === 'ألبان وأجبان' && (itemCat2 === 'اجبان وألبان' || itemCat2 === 'أجبان وألبان'))) matches = true;
        const itemCat1 = (item.productCat1 || '').trim();
        const normItemCat1 = itemCat1 === 'اجبان' ? 'أجبان' : itemCat1;
        if (subcategoryNames.has(normItemCat1.toLowerCase()) || subcategoryNames.has(itemCat1.toLowerCase())) matches = true;
        if (matches) {
          item.isSelected = enabled;
        }
      });
    } else {
      this.products.forEach((item) => {
        let matches = false;
        if (category.id && item.productCategoryId === category.id) matches = true;
        const resolved = this.resolveCategoryForProduct(item);
        if (category.id && resolved?.id === category.id) matches = true;
        if ((item.productCat1 || 'Uncategorized').trim().toLowerCase() === category.name.trim().toLowerCase()) {
          if (!category.parent || (item.productCat2 || '').trim().toLowerCase() === category.parent.trim().toLowerCase()) {
            matches = true;
          }
        }
        if (matches) {
          item.isSelected = enabled;
        }
      });
    }
  }

  isCategoryFullyEnabled(category: MerchantCategorySummary): boolean {
    const total = category.isMain ? category.totalProducts : category.total;
    const enabled = category.isMain ? category.enabledProducts : category.enabled;
    return total > 0 && enabled === total;
  }

  isCategoryPartiallyEnabled(category: MerchantCategorySummary): boolean {
    const total = category.isMain ? category.totalProducts : category.total;
    const enabled = category.isMain ? category.enabledProducts : category.enabled;
    return enabled > 0 && enabled < total;
  }

  getCategoryStatusLabel(category: MerchantCategorySummary): string {
    const total = category.isMain ? category.totalProducts : category.total;
    const enabled = category.isMain ? category.enabledProducts : category.enabled;
    if (total === 0) return 'No products';
    if (enabled === total) return 'All available';
    if (enabled > 0) return `${enabled}/${total} available`;
    return 'Unavailable';
  }

  isMainCategoryCollapsed(id: number): boolean {
    return this.collapsedMainCategoryIds.has(id);
  }

  toggleCollapseMainCategory(id: number): void {
    if (this.collapsedMainCategoryIds.has(id)) {
      this.collapsedMainCategoryIds.delete(id);
    } else {
      this.collapsedMainCategoryIds.add(id);
    }
  }

  expandAll(): void {
    this.collapsedMainCategoryIds.clear();
  }

  collapseAll(): void {
    this.mainCategories.forEach((m) => this.collapsedMainCategoryIds.add(m.id));
  }

  createSubcategory(parent: MerchantCategorySummary): void {
    this.openCategoryEditor({
      id: 0,
      title: '',
      parentId: parent.id,
      parent: parent.name,
      active: true,
      icon: '',
    });
  }

  focusMainCategory(mainId: number): void {
    this.selectedMainCategoryId = mainId;
    this.categoryLevelFilter = 'sub';
  }

  clearCategoryFilter(): void {
    this.selectedMainCategoryId = null;
    this.categorySearchTerm = '';
  }

  createProduct(): void {
    this.openProductEditor(null);
  }

  editProduct(item: ProductMerchant): void {
    this.openProductEditor({
      id: item.productId,
      title: item.product,
      description: item.productDescription || '',
      photos: item.productPhotos || '',
      unit: item.productUnit || '',
      active: item.productActive !== false,
      isFeatured: !!item.productIsFeatured,
      productCategoryId: item.productCategoryId || 0,
      productCategory: item.productCat1 || '',
    });
  }

  deleteProduct(item: ProductMerchant): void {
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'product';
    modalRef.componentInstance.actionLabel = 'Delete product';
    modalRef.componentInstance.description = `Delete “${item.product}” from the global catalog? This affects every merchant and cannot be undone.`;
    modalRef.componentInstance.action = () => this.productsService.delete(item.productId);
    modalRef.result.then(() => {
      this.products = this.products.filter((product) => product.productId !== item.productId);
      this.originalProducts = this.originalProducts.filter((product) => product.productId !== item.productId);
      this.toaster.success('Product deleted');
      this.cdr.detectChanges();
    }, () => {});
  }

  createCategory(): void {
    this.openCategoryEditor(null);
  }

  editCategory(category: MerchantCategorySummary): void {
    if (!category.id) return;
    const currentIcon = this.merchantCategoryOverrides.get(category.name.trim().toLowerCase())?.icon || category.icon;
    this.openCategoryEditor({
      id: category.id,
      title: category.name,
      parentId: this.catalogCategories.find((item) => item.id === category.id)?.parentId || null,
      parent: category.parent,
      active: category.active,
      icon: currentIcon,
    });
  }

  deleteCategory(category: MerchantCategorySummary): void {
    const total = category.isMain ? category.totalProducts : category.total;
    if (!category.id || total > 0) return;
    if (category.isMain && category.subcategoriesCount > 0) {
      this.toaster.warning('Please delete or reassign subcategories before deleting this main category');
      return;
    }
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = category.isMain ? 'main category' : 'subcategory';
    modalRef.componentInstance.actionLabel = 'Delete category';
    modalRef.componentInstance.description = `Delete “${category.name}”? This cannot be undone.`;
    modalRef.componentInstance.action = () => this.categoriesService.delete(category.id);
    modalRef.result.then(() => {
      this.catalogCategories = this.catalogCategories.filter((item) => item.id !== category.id);
      this.toaster.success('Category deleted');
      this.cdr.detectChanges();
    }, () => {});
  }

  resetChanges(): void {
    this.products = this.originalProducts.map((item) => ({ ...item }));
  }

  saveCatalog(): void {
    if (!this.hasChanges || this.isSaving) return;
    this.isSaving = true;
    const selected = this.products.filter((item) => item.isSelected);
    this.productMerchantsService.saveProducts(this.merchantId, selected).subscribe({
      next: () => {
        this.originalProducts = this.products.map((item) => ({ ...item }));
        this.isSaving = false;
        this.toaster.success('Merchant catalog saved');
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.toaster.error('Could not save the merchant catalog');
        this.cdr.detectChanges();
      },
    });
  }

  editMerchant(): void {
    if (!this.merchant) return;
    const modalRef = this.modalService.open(EditMerchantModalComponent, { size: 'lg' });
    modalRef.componentInstance.item = { ...this.merchant };
    modalRef.result.then((updated: Merchant | undefined) => {
      if (!updated || !this.merchant) return;
      this.merchant = { ...this.merchant, ...updated, id: this.merchantId };
      this.merchantsService.rememberWorkspaceMerchant(this.merchant);
      this.cdr.detectChanges();
    }, () => {});
  }

  trackByProduct(_index: number, item: ProductMerchant): number {
    return item.productId;
  }

  onImageError(event: Event): void {
    const image = event.target as HTMLImageElement;
    image.onerror = null;
    image.src = './assets/media/svg/files/blank-image.svg';
  }

  private categoryName(item: ProductMerchant): string {
    return item.productCat1 || 'Uncategorized';
  }

  private openProductEditor(product: Product | null): void {
    const modalRef = this.modalService.open(EditProductModalComponent, { size: 'lg' });
    modalRef.componentInstance.item = product;
    modalRef.result.then((updated: Product | undefined) => {
      if (!updated) return;
      const existing = this.products.find((item) => item.productId === updated.id);
      if (existing) {
        existing.product = updated.title;
        existing.productDescription = updated.description;
        existing.productPhotos = updated.photos;
        existing.productUnit = updated.unit;
        existing.productActive = updated.active;
        existing.productIsFeatured = updated.isFeatured;
        existing.productCategoryId = updated.productCategoryId;
        existing.productCat1 = updated.productCategory;
      } else {
        this.reloadCatalogPreservingAssignments();
      }
      this.cdr.detectChanges();
    }, () => {});
  }

  private openCategoryEditor(category: Category | null): void {
    const modalRef = this.modalService.open(EditCategoryModalComponent, { size: 'lg' });
    modalRef.componentInstance.item = category;
    modalRef.result.then((updated: Category | undefined) => {
      if (!updated) return;
      this.saveMerchantCategoryOverride(updated.title, updated.icon || '', updated.active);
      const index = this.catalogCategories.findIndex((item) => item.id === updated.id);
      const parent = this.catalogCategories.find((item) => item.id === updated.parentId)?.title || '';
      const normalized = { ...updated, parent };
      if (index >= 0) this.catalogCategories[index] = normalized;
      else this.catalogCategories.push(normalized);
      this.products.filter((item) => item.productCategoryId === updated.id).forEach((item) => {
        item.productCat1 = updated.title;
        item.productCat2 = parent;
        item.categoryActive = updated.active;
        item.categoryIcon = updated.icon || '';
      });
      this.cdr.detectChanges();
    }, () => {});
  }

  private resolveCategoryForProduct(item: ProductMerchant): Category | undefined {
    if (item.productCategoryId) {
      const byId = this.catalogCategories.find((c) => c.id === item.productCategoryId);
      if (byId) return byId;
    }

    const sub = (item.productCat1 || '').trim();
    const parent = (item.productCat2 || '').trim();

    if (parent && sub) {
      const byParentAndSub = this.catalogCategories.find(
        (c) => (c.title || '').trim() === sub && (c.parent || '').trim() === parent
      );
      if (byParentAndSub) return byParentAndSub;
    }

    if (sub) {
      const bySub = this.catalogCategories.find((c) => (c.title || '').trim() === sub);
      if (bySub) return bySub;
    }

    const parts = sub.split(/[\uFFFD\u00A0?]+/).map((s) => s.trim()).filter((s) => s.length >= 2);
    if (parts.length > 0) {
      const byFuzzy = this.catalogCategories.find((c) => {
        const catTitle = (c.title || '').trim();
        const matchesParts = parts.every((p) => catTitle.includes(p));
        if (!matchesParts) return false;
        if (parent && c.parent) {
          return (c.parent || '').trim() === parent;
        }
        return true;
      });
      if (byFuzzy) return byFuzzy;
    }

    return undefined;
  }

  private reloadCatalogPreservingAssignments(): void {
    const pending = new Map(this.products.map((item) => [item.productId, {
      isSelected: item.isSelected,
      additionalProfitPercent: item.additionalProfitPercent,
    }]));
    this.productMerchantsService.getProducts(this.merchantId).subscribe((response: any) => {
      this.products = (response || []).map((item: ProductMerchant) => {
        const changed = pending.get(item.productId);
        const resolvedCat = this.resolveCategoryForProduct(item);
        return {
          ...item,
          productCategoryId: item.productCategoryId || (resolvedCat ? resolvedCat.id : 0),
          isSelected: changed ? changed.isSelected : item.merchantId === this.merchantId,
          additionalProfitPercent: changed ? changed.additionalProfitPercent : item.additionalProfitPercent,
        };
      });
      this.originalProducts = this.products.map((item) => ({ ...item }));
      this.cdr.detectChanges();
    });
  }

  private createMerchantPlaceholder(id: number): Merchant {
    return {
      id,
      title: `Merchant #${id}`,
      shortDescription: '',
      description: '',
      ibaN1Title: '',
      ibaN1: '',
      phone1: '',
      phone2: '',
      address: '',
      shippingCoverageInMeters: 0,
      profitOutOfMerchantPricePercent: 0,
      lng: 0,
      lat: 0,
      active: false,
      merchantKind: 0,
      ownerId: '',
      owner: '',
      photo: '',
    };
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
