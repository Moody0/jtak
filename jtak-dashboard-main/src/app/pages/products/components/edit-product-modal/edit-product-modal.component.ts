import { merchantBaseDiscountFromSaving, merchantDiscountQuote } from '../../models/merchant-discount-pricing';
import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal, NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable, forkJoin, of } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap, catchError } from 'rxjs/operators';
import { Product } from '../../models/product.model';
import { ProductsService } from '../../services/products.service';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { InventoryBatchService } from 'src/app/pages/inventory-batches/services/inventory-batch.service';
import { BatchMerchantLookup } from 'src/app/pages/inventory-batches/models/product-batch.model';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { DeleteProductModalComponent } from '../delete-product-modal/delete-product-modal.component';
import { DashboardService } from 'src/app/pages/dashboard/services/dashboard.service';

export interface CategoryOption {
  id: number;
  title: string;
  parentId: number | null;
  parentTitle?: string;
  fullPath: string;
  isRoot: boolean;
}

const EMPTY_Product: Product = {
  id: null,
  title: '',
  barcode: '',
  description: '',
  photos: '',
  unit: 'قطعة',
  active: true,
  isFeatured: false,
  productCategoryId: 0,
  productCategory: '',
  merchantId: undefined,
  price: null,
  priceUsd: null,
  discount: null,
  originalPrice: null,
  discountPercent: 0,
};

@Component({
  selector: 'app-edit-product-modal',
  templateUrl: './edit-product-modal.component.html',
  styleUrls: ['./edit-product-modal.component.scss'],
})
export class EditProductModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Product;

  isLoading$: Observable<boolean>;
  formGroup: UntypedFormGroup;
  isSaving = false;

  // Category & Hierarchy structure
  categoriesList: CategoryOption[] = [];
  categoryMap = new Map<number, CategoryOption>();

  // Merchants
  merchantsList: BatchMerchantLookup[] = [];
  merchantOptions: BatchMerchantLookup[] = [];
  merchantsLoading = false;
  merchantsLoadError = false;
  exchangeRate = 15000;
  private originalBaseUsd: number | null = null;
  private initialDisplayedPriceUsd: number | null = null;

  // Quick Unit Presets
  unitPresets = ['قطعة', 'كغ', 'علبة', 'وجبة', 'لتر', 'صندوق', 'حبة'];

  constructor(
    private service: ProductsService,
    private categoriesService: CategoriesService,
    private merchantsService: MerchantsService,
    private batchService: InventoryBatchService,
    public filesService: FilesService,
    private fb: UntypedFormBuilder,
    public modal: NgbActiveModal,
    private modalService: NgbModal,
    private toasterService: ToastrService,
    private dashboardService: DashboardService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.initItemAndForm();
    for (const field of ['priceUsd', 'merchantId']) {
      this.subs.sink = this.formGroup.get(field)!.valueChanges.subscribe(() => this.syncCustomerDiscountInput());
    }
    this.subs.sink = this.formGroup.get('customerSavingPercent')!.valueChanges.subscribe(() => this.applyCustomerSaving());
    this.loadExchangeRate();
    this.loadLookups();
  }

  private initItemAndForm(): void {
    if (!this.item) {
      this.item = { ...EMPTY_Product };
    }

    const photoList = this.item.photos
      ? this.item.photos.split(',').map((p) => p.trim()).filter(Boolean)
      : [];

    this.formGroup = this.fb.group({
      id: [this.item.id],
      title: [this.item.title || '', [Validators.required, Validators.minLength(2)]],
      barcode: [this.item.barcode || ''],
      description: [this.item.description || ''],
      unit: [this.item.unit || 'قطعة', [Validators.required]],
      isFeatured: [this.item.isFeatured ?? false],
      active: [this.item.active ?? true],
      photos: [photoList],
      productCategoryId: [this.item.productCategoryId || null, [Validators.required]],
      merchantId: [this.item.merchantId ? Number(this.item.merchantId) : null, [Validators.required]],
      priceUsd: [this.item.originalPrice != null && Number(this.item.originalPrice) > 0
        ? this.roundUsd(Number(this.item.originalPrice))
        : this.item.priceUsd != null && Number(this.item.priceUsd) > 0
          ? this.roundUsd(Number(this.item.priceUsd))
          : null, [Validators.min(0)]],
      discountPercent: [0, [Validators.min(0), Validators.max(99.99)]],
      customerSavingPercent: [0, [Validators.min(0)]],
    });

    this.initializeDiscountInputs();
  }

  private loadExchangeRate(): void {
    this.subs.sink = this.dashboardService.getCatalogDefaults().pipe(catchError(() => of(null))).subscribe((settings) => {
      const rate = Number(settings?.usdToSypExchangeRate);
      if (Number.isFinite(rate) && rate > 0) this.exchangeRate = rate;
      this.initializeDiscountInputs();
      this.syncCustomerDiscountInput();
    });
  }

  private initializeDiscountInputs(): void {
    if (!this.formGroup || this.formGroup.get('priceUsd')?.dirty) return;

    const storedDiscount = this.normalizeNumber(this.item?.discount, 0) || 0;
    const storedPriceUsd = this.normalizeNumber(this.item?.priceUsd, 0) || 0;
    const storedLocalPrice = this.normalizeNumber(this.item?.price, 0) || 0;
    const storedOriginalUsd = this.normalizeNumber(this.item?.originalPrice, 0) || 0;
    const explicitPercent = this.normalizeNumber(this.item?.discountPercent, null);

    let percentage = 0;
    if (explicitPercent !== null && explicitPercent > 0) {
      percentage = Math.round(explicitPercent * 100) / 100;
    } else if (storedOriginalUsd > 0 && storedPriceUsd > 0 && storedOriginalUsd > storedPriceUsd) {
      percentage = Math.round((1 - storedPriceUsd / storedOriginalUsd) * 10000) / 100;
    } else if (storedDiscount > 0) {
      const saleLocalPrice = storedLocalPrice > 0 ? storedLocalPrice : this.toLocalPrice(storedPriceUsd);
      if (saleLocalPrice > 0) {
        percentage = Math.round((storedDiscount / (saleLocalPrice + storedDiscount)) * 10000) / 100;
      }
    }

    percentage = Math.max(0, Math.min(99.99, percentage));

    let oldPriceUsd: number | null = null;
    if (explicitPercent !== null) {
      oldPriceUsd = storedPriceUsd > 0 ? storedPriceUsd : storedLocalPrice / this.exchangeRate;
    } else if (storedOriginalUsd > 0) {
      oldPriceUsd = storedOriginalUsd;
    } else if (storedPriceUsd > 0) {
      if (percentage > 0 && percentage < 100) {
        oldPriceUsd = storedPriceUsd / (1 - percentage / 100);
      } else {
        oldPriceUsd = storedPriceUsd;
      }
    } else if (storedLocalPrice > 0 && this.exchangeRate > 0) {
      const baseUsd = storedLocalPrice / this.exchangeRate;
      if (percentage > 0 && percentage < 100) {
        oldPriceUsd = baseUsd / (1 - percentage / 100);
      } else {
        oldPriceUsd = baseUsd;
      }
    }

    // A two-decimal USD display must not overwrite the precise supplier quote.
    // For example, 550 / 135 is 4.074074..., not 4.07 (549.45 local).
    this.originalBaseUsd = oldPriceUsd;
    this.initialDisplayedPriceUsd = oldPriceUsd !== null ? this.roundUsd(oldPriceUsd) : null;
    this.formGroup.patchValue({
      priceUsd: this.initialDisplayedPriceUsd,
      ...(this.formGroup.get('discountPercent')?.dirty ? {} : { discountPercent: percentage }),
    }, { emitEvent: false });
    this.syncCustomerDiscountInput();
  }

  private get preservedBasePrice(): boolean {
    return !!this.item?.id && this.originalBaseUsd !== null &&
      this.normalizeNumber(this.formGroup?.get('priceUsd')?.value, null) === this.initialDisplayedPriceUsd;
  }

  private get basePriceUsd(): number | null {
    const entered = this.normalizeNumber(this.formGroup?.get('priceUsd')?.value, null);
    return this.preservedBasePrice ? this.originalBaseUsd : entered !== null ? this.roundUsd(entered) : null;
  }

  roundUsd(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }

  onPriceUsdBlur(): void {
    const val = this.formGroup?.get('priceUsd')?.value;
    if (val !== null && val !== undefined && val !== '') {
      const num = Number(val);
      if (!isNaN(num)) {
        this.formGroup.get('priceUsd')?.setValue(this.roundUsd(num));
      }
    }
  }

  onDiscountBlur(): void {
    const percent = this.normalizeNumber(this.formGroup?.get('customerSavingPercent')?.value, 0) || 0;
    this.setDiscountPreset(percent);
    this.syncCustomerDiscountInput();
  }

  setDiscountPreset(percent: number): void {
    this.formGroup?.get('customerSavingPercent')?.setValue(Math.max(0,
      Math.min(this.maxCustomerSavingPercent, Math.round(percent * 100) / 100)));
    this.formGroup?.get('customerSavingPercent')?.markAsDirty();
    this.formGroup?.get('discountPercent')?.markAsDirty();
  }

  private get merchantMarkupPercent(): number {
    const merchantId = this.normalizeNumber(this.formGroup?.get('merchantId')?.value, null);
    const selected = this.merchantsList.find((merchant) => merchant.id === merchantId);
    return this.normalizeNumber(selected?.profitOutOfMerchantPricePercent,
      merchantId === Number(this.item?.merchantId)
        ? this.normalizeNumber(this.item?.profitOutOfMerchantPricePercent, 0) : 0) || 0;
  }

  get maxCustomerSavingPercent(): number {
    return merchantDiscountQuote(this.basePriceUsd || 0, this.exchangeRate, this.merchantMarkupPercent,
      Math.min(this.merchantMarkupPercent, 99.99))?.effectivePercent || 0;
  }

  private syncCustomerDiscountInput(): void {
    const control = this.formGroup?.get('customerSavingPercent');
    if (!control) return;
    control.setValidators([Validators.min(0), Validators.max(this.maxCustomerSavingPercent)]);
    control.setValue(this.pricingQuote?.effectivePercent || 0, { emitEvent: false });
  }

  private applyCustomerSaving(): void {
    const requested = this.normalizeNumber(this.formGroup.get('customerSavingPercent')?.value, 0) || 0;
    const basePercent = merchantBaseDiscountFromSaving(this.basePriceUsd || 0, this.exchangeRate,
      this.merchantMarkupPercent, Math.min(requested, this.maxCustomerSavingPercent));
    this.formGroup.get('discountPercent')?.setValue(basePercent, { emitEvent: false });
    this.formGroup.get('discountPercent')?.markAsDirty();
  }

  private get pricingQuote() {
    if (!this.formGroup) return null;
    const baseUsd = this.basePriceUsd || 0;
    const requestedPercent = this.normalizeNumber(this.formGroup.get('discountPercent')?.value, 0) || 0;
    return merchantDiscountQuote(baseUsd, this.exchangeRate, this.merchantMarkupPercent, requestedPercent);
  }

  get discountPreview() {
    const quote = this.pricingQuote;
    const requested = this.normalizeNumber(this.formGroup?.get('discountPercent')?.value, 0) || 0;
    if (!quote || requested <= 0) return null;
    return {
      oldPriceUsd: quote.price / this.exchangeRate,
      oldPriceLocal: quote.price,
      salePriceUsd: quote.finalPrice / this.exchangeRate,
      salePriceLocal: quote.finalPrice,
      percentage: quote.effectivePercent,
      requestedPercentage: requested,
      limited: quote.limited,
      merchantPrice: quote.merchantPrice,
      appliedBasePercentage: quote.appliedBasePercent,
      markupPercentage: quote.markupPercent,
    };
  }

  get customerPricePreview() {
    const quote = this.pricingQuote;
    return quote ? { merchantPrice: quote.merchantPrice, oldPrice: quote.price, salePrice: quote.finalPrice,
      discountPercent: quote.effectivePercent } : null;
  }

  toLocalPrice(priceUsd: number | null | undefined): number {
    if (priceUsd === null || priceUsd === undefined) return 0;
    return Math.round(Number(priceUsd) * this.exchangeRate);
  }

  loadLookups(): void {
    this.merchantsLoading = true;
    this.merchantsLoadError = false;
    this.subs.sink = forkJoin({
      roots: this.categoriesService.getAll(true).pipe(catchError(() => of([]))),
      subs: this.categoriesService.getAll(false).pipe(catchError(() => of([]))),
      merchants: this.merchantsService
        .getAllMerchants()
        .pipe(
          catchError(() => this.batchService.lookupMerchants()),
          catchError(() => of([]))
        ),
    }).subscribe({
      next: ({ roots, subs, merchants }) => {
        const rootMap = new Map<number, string>();
        (roots || []).forEach((r) => {
          if (r && r.id) rootMap.set(r.id, r.title);
        });

        const seenCatIds = new Set<number>();
        const allCats: CategoryOption[] = [];

        // Add roots (Deduplicated by ID)
        (roots || []).forEach((r) => {
          if (!r || !r.id || seenCatIds.has(r.id)) return;
          seenCatIds.add(r.id);
          const option: CategoryOption = {
            id: r.id,
            title: r.title,
            parentId: null,
            fullPath: `[تصنيف رئيسي] ${r.title}`,
            isRoot: true,
          };
          this.categoryMap.set(r.id, option);
          allCats.push(option);
        });

        // Add subcategories (Deduplicated by ID, preserving distinct same-name hierarchies)
        (subs || []).forEach((s) => {
          if (!s || !s.id || seenCatIds.has(s.id)) return;
          seenCatIds.add(s.id);
          const parentTitle = s.parentId ? rootMap.get(s.parentId) : undefined;
          const fullPath = parentTitle ? `${parentTitle} > ${s.title}` : s.title;
          const option: CategoryOption = {
            id: s.id,
            title: s.title,
            parentId: s.parentId || null,
            parentTitle,
            fullPath,
            isRoot: !parentTitle && (!s.parentId || s.parentId === 0),
          };
          this.categoryMap.set(s.id, option);
          allCats.push(option);
        });

        this.categoriesList = allCats.sort((a, b) => a.fullPath.localeCompare(b.fullPath));

        // Merchants
        const mList: BatchMerchantLookup[] = [];
        if (merchants && merchants.length > 0) {
          merchants.forEach((m: any) => {
            const id = Number(m.id ?? m.Id);
            const title = m.title || m.Title || m.name || m.Name || m.fullName || `متجر #${id}`;
            if (id > 0 && !mList.some((existing) => existing.id === id)) {
              const rawKind = m.merchantKind ?? m.MerchantKind;
              const merchantKind = rawKind === undefined || rawKind === null ? undefined : Number(rawKind);
              mList.push({ id, title, merchantKind,
                profitOutOfMerchantPricePercent: this.normalizeNumber(m.profitOutOfMerchantPricePercent ?? m.ProfitOutOfMerchantPricePercent, null) ?? undefined,
              });
            }
          });
        }
        this.merchantsList = mList;

        if (this.item?.merchantId && this.item?.merchantTitle) {
          if (!this.merchantsList.some((m) => m.id === Number(this.item.merchantId))) {
            this.merchantsList.unshift({
              id: Number(this.item.merchantId),
              title: this.item.merchantTitle,
            });
          }
        }

        const market = this.getMarketMerchant();
        const currentMerchantId = Number(this.formGroup.get('merchantId')?.value || 0);
        this.merchantOptions = [...this.merchantsList];
        if (currentMerchantId && !this.merchantOptions.some((merchant) => merchant.id === currentMerchantId)) {
          const current = this.merchantsList.find((merchant) => merchant.id === currentMerchantId);
          if (current) this.merchantOptions.unshift(current);
        }
        if (!currentMerchantId && market) {
          this.formGroup.patchValue({ merchantId: market.id });
        }

        this.merchantsLoading = false;

        this.merchantsLoadError = this.merchantsList.length === 0;
        this.syncCustomerDiscountInput();
      },
      error: () => {
        this.merchantsLoading = false;
        this.merchantsLoadError = true;
      },
    });
  }

  retryMerchantLookup(): void {
    this.loadLookups();
  }

  getSelectedMerchant(): BatchMerchantLookup | null {
    const id = Number(this.formGroup?.get('merchantId')?.value || 0);
    return id > 0 ? this.merchantsList.find((merchant) => Number(merchant.id) === id) || null : null;
  }

  getMarketMerchant(): BatchMerchantLookup | null {
    const named = this.merchantsList.filter((merchant) => this.isMarketMerchant(merchant));
    if (named.length === 1) return named[0];
    if (named.length > 1) return null;

    const groceryMerchants = this.merchantsList.filter((merchant) => merchant.merchantKind === 1);
    return groceryMerchants.length === 1 ? groceryMerchants[0] : null;
  }

  isMarketMerchant(merchant: BatchMerchantLookup | null | undefined): boolean {
    if (!merchant) return false;
    const title = (merchant.title || '').toLowerCase().replace(/[\s_-]/g, '');
    return title.includes('jtakmarket') || title.includes('جيتكماركت');
  }

  isSelectedMarket(): boolean {
    const selected = this.getSelectedMerchant();
    const market = this.getMarketMerchant();
    return !!selected && (selected.id === market?.id || this.isMarketMerchant(selected));
  }

  setUnit(unit: string): void {
    this.formGroup.patchValue({ unit });
  }

  getSelectedCategoryInfo(): CategoryOption | null {
    const catId = this.formGroup.get('productCategoryId')?.value;
    if (catId && this.categoryMap.has(catId)) {
      return this.categoryMap.get(catId)!;
    }
    return null;
  }

  getSuggestedSubcategory(): CategoryOption | null {
    const title = this.formGroup.get('title')?.value;
    if (!title) return null;
    const t = title.toLowerCase();
    let keyword = '';
    if (/وافل|كريب|تشيزكيك|كيك|برازق|مدلوقة|بقلاوة|مبرومة|حلاوة الجبن|كنافة|معمول|شوكولا|غريبة|بوظة|آيس كريم|حلوى|تورتة|دونات/.test(t)) {
      keyword = 'حلويات';
    } else if (/كولد برو|لاتيه|قهوة|مشروب|عصير|سبانش|اسبريسو|موكا|شاي|كوكتيل|ميلك شيك|سموذي|مشروبات/.test(t)) {
      keyword = 'مشروبات';
    } else if (/برغر|برجر|فرايز|بطاطا|كرسبي|تشيكن|شاورما|بروستد|ساندويش|سندويش|تاكو|بيتزا|زنجر|فاير/.test(t)) {
      keyword = 'وجبات';
    } else if (/فول|حمص|فلافل|فتة|مسبحة|تسقية|بيض|فطور|معجنات|فطائر|مناقيش/.test(t)) {
      keyword = 'فطور';
    } else if (/مشاوي|كباب|شيش|شقف|كبة|لحمة|عرايس|طاووق|ريش|كفتة/.test(t)) {
      keyword = 'مشاوي';
    }

    if (!keyword) return null;
    return this.categoriesList.find((c) => !c.isRoot && (c.title.includes(keyword) || c.fullPath.includes(keyword))) || null;
  }

  applySuggestion(option: CategoryOption): void {
    this.formGroup.patchValue({ productCategoryId: option.id });
    this.toasterService.success(`تم اختيار "${option.fullPath}" كإعداد للتصنيف`);
  }

  getPrimaryPhoto(): string | undefined {
    const photos = this.formGroup.get('photos')?.value;
    return photos && photos.length ? photos[0] : undefined;
  }

  onFileUploaded(filesIds: string[], key: string): void {
    const current = this.formGroup.get(key)?.value || [];
    const updated = [...current, ...filesIds];
    this.formGroup.patchValue({ [key]: updated });
  }

  onFileDelete(key: string, fileId: string): void {
    const current = this.formGroup.get(key)?.value || [];
    const updated = current.filter((id: string) => id !== fileId);
    this.formGroup.patchValue({ [key]: updated });
  }

  setAsPrimaryPhoto(fileId: string): void {
    const current: string[] = this.formGroup.get('photos')?.value || [];
    const reordered = [fileId, ...current.filter((id) => id !== fileId)];
    this.formGroup.patchValue({ photos: reordered });
    this.toasterService.info('تم تعيين الصورة كصورة رئيسية للمنتج');
  }

  private normalizeNumber(val: any, defaultVal: number | null = null): number | null {
    if (val === null || val === undefined) return defaultVal;
    if (typeof val === 'number') {
      return isNaN(val) ? defaultVal : val;
    }
    const str = String(val).trim().replace(/,/g, '.');
    if (str === '') return defaultVal;
    const parsed = Number(str);
    return isNaN(parsed) ? defaultVal : parsed;
  }

  save(): void {
    if (this.isSaving) return;
    if (this.formGroup.invalid) { this.formGroup.markAllAsTouched(); return; }
    if (!String(this.formGroup.get('title')?.value || '').trim()) {
      this.formGroup.get('title')?.setErrors({ required: true }); return;
    }
    if (this.formGroup.invalid) {
      this.formGroup.markAllAsTouched();
      return;
    }

    this.isSaving = true;
    const raw = this.formGroup.value;
    // UI-only customer percentage must not change the API's base-price contract.
    delete raw.customerSavingPercent;
    const photosArray = raw.photos || [];
    const photosStr = Array.isArray(photosArray) ? photosArray.join(',') : (photosArray || '');

    const preDiscountPriceUsd = this.basePriceUsd;
    // Editing only a discount must also preserve local-currency pricing.
    const storedPriceUsd = this.preservedBasePrice && !(Number(this.item.priceUsd) > 0)
      ? null : preDiscountPriceUsd;
    const discountPercent = this.normalizeNumber(raw.discountPercent, 0) || 0;
    const catId = this.normalizeNumber(raw.productCategoryId, null);
    const merchantId = this.normalizeNumber(raw.merchantId, null);

    let salePriceUsd: number | null = null;
    let originalPriceUsd: number | null = null;
    let salePriceLocal = 0;
    let discountAmount = 0;

    if (preDiscountPriceUsd !== null && preDiscountPriceUsd > 0) {
      const quote = this.pricingQuote;
      if (!quote) { this.isSaving = false; return; }
      salePriceUsd = storedPriceUsd;
      originalPriceUsd = discountPercent > 0 ? storedPriceUsd : null;
      salePriceLocal = quote.merchantPrice;
      discountAmount = quote.discount;
    }

    const formValues: Product = {
      ...this.item,
      ...raw,
      title: (raw.title || '').trim(),
      barcode: (raw.barcode || '').trim(),
      description: (raw.description || '').trim(),
      unit: (raw.unit || 'قطعة').trim(),
      photos: photosStr,
      productCategoryId: catId || this.item.productCategoryId,
      merchantId: merchantId ? Number(merchantId) : undefined,
      price: salePriceLocal,
      priceUsd: storedPriceUsd,
      originalPrice: originalPriceUsd,
      discountPercent,
      discount: discountAmount,
      active: !!raw.active,
      isFeatured: !!raw.isFeatured,
    };

    const computedResult = {
      merchantPrice: salePriceLocal,
      priceUsd: salePriceUsd,
      originalPrice: originalPriceUsd,
      discount: discountAmount,
      discountPercent,
    };

    if (this.item.id) {
      this.edit(formValues, computedResult);
    } else {
      delete formValues.id;
      this.create(formValues, computedResult);
    }
  }

  private handleSaveError(error: any): void {
    this.isSaving = false;
    const message = Array.isArray(error?.error?.errors) ? error.error.errors.join('، ') : typeof error?.error === 'string' ? error.error : error?.error?.message;
    this.toasterService.error(message || 'تعذر حفظ المنتج وربطه بالمتجر، يرجى المحاولة مرة أخرى.');
  }

  private showSaveSuccess(message: string): void {
    const preview = this.discountPreview;
    if (preview?.limited) {
      this.toasterService.warning(
        `تم حفظ المنتج. الخصم من السعر الأساسي محدود بعمولة جيتك: ${preview.appliedBasePercentage}% بدلاً من ${preview.requestedPercentage}%. حصة التاجر محفوظة (${preview.merchantPrice} ل.س).`
      );
    } else {
      this.toasterService.success(message);
    }
  }

  create(formValues: Product, computedResult?: any): void {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.showSaveSuccess('تمت إضافة المنتج بنجاح');
          this.modal.close(this.modalResult({ ...formValues, id }, computedResult));
        }),
        catchError((error) => {
          this.handleSaveError(error);
          return of(null);
        })
      )
      .subscribe();
  }

  edit(formValues: Product, computedResult?: any): void {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.showSaveSuccess('تم تحديث بيانات المنتج بنجاح');
          this.modal.close(this.modalResult(formValues, computedResult));
        }),
        catchError((error) => {
          this.handleSaveError(error);
          return of(null);
        })
      )
      .subscribe();
  }

  deleteCurrentProduct(): void {
    if (!this.item?.id) return;
    const modalRef = this.modalService.open(DeleteProductModalComponent, {
      size: 'md',
      centered: true,
    });
    modalRef.componentInstance.id = this.item.id;
    modalRef.componentInstance.isBulk = false;
    modalRef.result.then(
      (result) => {
        if (result) {
          this.toasterService.success('تم حذف المنتج بنجاح وأرشفته بأمان');
          this.modal.close({ deleted: true, id: this.item.id });
        }
      },
      () => {}
    );
  }

  private modalResult(product: Product, computedResult?: any): Product {
    const cat = this.categoryMap.get(product.productCategoryId);
    return {
      ...product,
      ...(computedResult || {}),
      productCategory: cat?.title || product.productCategory || '',
      categoryHierarchy: cat?.fullPath || '',
      parentCategoryTitle: cat?.parentTitle || '',
    };
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
