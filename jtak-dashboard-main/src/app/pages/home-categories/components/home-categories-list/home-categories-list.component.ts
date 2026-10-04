import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription, forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import {
  HomeCategoriesAdminVm,
  HomeCategoriesConfig,
  HomeCategoryLinkType,
  HomeCategoryMerchant,
  HomeCategoryMerchantKind,
  HomeCategoryTarget,
  HomeCategoryTile,
  LINK_TYPE_LABELS,
  MERCHANT_KIND_LABELS,
  ResolvedHomeCategoryTile,
} from '../../models/home-category.model';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { HomeCategoriesService } from '../../services/home-categories.service';
import { RestaurantCategoriesService } from 'src/app/pages/restaurant-categories/services/restaurant-categories.service';
import { RestaurantCategoryItem } from 'src/app/pages/restaurant-categories/models/restaurant-category.model';

@Component({
  selector: 'app-home-categories-list',
  templateUrl: './home-categories-list.component.html',
  styleUrls: ['./home-categories-list.component.scss'],
})
export class HomeCategoriesListComponent implements OnInit, OnDestroy {
  private requests = new Subscription();
  private loadRequest?: Subscription;
  private successTimer?: ReturnType<typeof setTimeout>;
  ngOnDestroy(): void { this.requests.unsubscribe(); this.loadRequest?.unsubscribe(); clearTimeout(this.successTimer); }
  loading = true;
  saving = false;
  saveSuccess = false;
  saveError: string | null = null;

  config: HomeCategoriesConfig = {
    enabled: true,
    sectionTitle: 'تسوق حسب الفئة',
    sectionTitleEn: 'Shop by category',
    maxItems: 8,
    tiles: [],
  };

  resolved: ResolvedHomeCategoryTile[] = [];
  categories: HomeCategoryTarget[] = [];
  merchants: HomeCategoryMerchant[] = [];
  merchantKinds: HomeCategoryMerchantKind[] = [];
  restaurantCategories: RestaurantCategoryItem[] = [];
  restaurantCategoriesLoadError = false;
  merchantCategoryMap: { [merchantId: number]: number[] } = {};
  private expandedTiles = new Set<HomeCategoryTile>();
  private savedConfigSnapshot = '';

  readonly linkTypes = LINK_TYPE_LABELS;
  readonly LinkType = HomeCategoryLinkType;

  constructor(
    private service: HomeCategoriesService,
    private restaurantCategoriesService: RestaurantCategoriesService,
    private cdr: ChangeDetectorRef,
    public filesService: FilesService
  ) {}

  ngOnInit(): void {
    this.load();
  }

  get hasUnsavedChanges(): boolean {
    return this.savedConfigSnapshot.length > 0 && this.serializeConfig() !== this.savedConfigSnapshot;
  }

  load(): void {
    if (this.saving) return;
    this.loadRequest?.unsubscribe();
    if (
      !this.loading &&
      this.hasUnsavedChanges &&
      !window.confirm('لديك تغييرات غير محفوظة. هل تريد تجاهلها وإعادة تحميل البيانات؟')
    ) {
      return;
    }
    this.loading = true;
    this.saveError = null;
    this.restaurantCategoriesLoadError = false;
    this.loadRequest = forkJoin({
      home: this.service.get(),
      restaurantCategories: this.restaurantCategoriesService.getConfig().pipe(catchError(() => of(null))),
    }).subscribe({
      next: ({ home: vm, restaurantCategories }) => {
        this.expandedTiles.clear();
        this.config = vm.config ?? this.config;
        this.config.tiles = vm.config?.tiles ?? [];
        this.categories = (vm.availableCategories ?? []).map((cat) => ({
          ...cat,
          displayLabel: cat.parentTitle ? `${cat.parentTitle} > ${cat.title}` : cat.title,
        }));
        this.merchants = (vm.availableMerchants ?? []).map((m) => ({
          ...m,
          displayLabel: `${m.title} (${this.merchantKindLabel(m.merchantKind)})`,
        }));
        this.merchantKinds = vm.availableMerchantKinds ?? [];
        this.restaurantCategories = restaurantCategories?.items ?? [];
        this.restaurantCategoriesLoadError = restaurantCategories === null;
        this.merchantCategoryMap = vm.merchantCategoryMap ?? {};
        this.resolved = vm.tiles ?? [];

        // A site that has never been configured is still showing something in
        // the app: the default arrangement. Load that in so the admin edits
        // what customers actually see instead of starting from a blank page.
        if (!this.config.tiles.length && this.resolved.length) {
          this.config.tiles = this.resolved.map((tile) => ({
            id: tile.id,
            title: tile.title,
            titleEn: tile.titleEn,
            imageUrl: tile.imageUrl,
            order: tile.order,
            active: true,
            linkType: tile.linkType,
            productCategoryId: tile.productCategoryId,
            secondaryProductCategoryId: tile.secondaryProductCategoryId,
            merchantKind: tile.merchantKind,
            restaurantCategoryId: tile.restaurantCategoryId,
            merchantId: tile.merchantId,
            searchTerm: tile.searchTerm,
          }));
        }
        this.renumber();
        this.savedConfigSnapshot = this.serializeConfig();
        this.loading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.loading = false;
        this.saveError =
          typeof err?.error === 'string' && err.error.trim().length
            ? err.error
            : 'تعذر تحميل إعدادات فئات الصفحة الرئيسية. تحقق من الاتصال وحاول مرة أخرى.';
        this.cdr.detectChanges();
      },
    });
  }

  addTile(): void {
    const tile: HomeCategoryTile = {
      title: '',
      titleEn: '',
      imageUrl: '',
      order: this.config.tiles.length,
      active: true,
      linkType: HomeCategoryLinkType.ProductCategory,
      productCategoryId: null,
      merchantKind: null,
      restaurantCategoryId: null,
      merchantId: null,
      searchTerm: '',
    };
    this.config.tiles.push(tile);
    this.expandedTiles.add(tile);
    this.renumber();
  }

  removeTile(index: number): void {
    const tile = this.config.tiles[index];
    if (!tile) return;
    const title = tile.title?.trim() || 'هذه الفئة';
    if (!window.confirm(`هل تريد حذف «${title}»؟ لن يظهر الحذف للعملاء إلا بعد حفظ التغييرات.`)) {
      return;
    }
    this.expandedTiles.delete(tile);
    this.config.tiles.splice(index, 1);
    this.renumber();
  }

  addMerchantKindTile(kind: number): void {
    const existing = this.config.tiles.find(
      (tile) => tile.linkType === HomeCategoryLinkType.MerchantKind && tile.merchantKind === kind
    );
    if (existing) {
      this.expandedTiles.add(existing);
      return;
    }
    this.addTile();
    const tile = this.config.tiles[this.config.tiles.length - 1];
    tile.linkType = HomeCategoryLinkType.MerchantKind;
    tile.merchantKind = kind;
    tile.title = this.merchantKindLabel(kind);
  }

  isTileExpanded(tile: HomeCategoryTile): boolean {
    return this.expandedTiles.has(tile);
  }

  toggleTile(tile: HomeCategoryTile): void {
    if (this.isTileExpanded(tile)) {
      this.expandedTiles.delete(tile);
    } else {
      this.expandedTiles.add(tile);
    }
  }

  get allTilesExpanded(): boolean {
    return this.config.tiles.length > 0 && this.config.tiles.every((tile) => this.isTileExpanded(tile));
  }

  toggleAllTiles(): void {
    if (this.allTilesExpanded) {
      this.expandedTiles.clear();
    } else {
      this.config.tiles.forEach((tile) => this.expandedTiles.add(tile));
    }
  }

  tileTargetSummary(tile: HomeCategoryTile): string {
    switch (tile.linkType) {
      case HomeCategoryLinkType.ProductCategory: {
        const primary = this.categories.find((category) => category.id === tile.productCategoryId)?.displayLabel || 'لم يتم اختيار قسم';
        if (tile.secondaryProductCategoryId) {
          const secondary = this.categories.find((category) => category.id === tile.secondaryProductCategoryId)?.displayLabel || `#${tile.secondaryProductCategoryId}`;
          return `${primary} + ${secondary}`;
        }
        return primary;
      }
      case HomeCategoryLinkType.MerchantCategory: {
        const merchant = this.merchants.find((item) => item.id === tile.merchantId);
        const category = this.categories.find((item) => item.id === tile.productCategoryId);
        return merchant && category ? `${category.title} ضمن ${merchant.title}` : 'اختر المتجر والقسم';
      }
      case HomeCategoryLinkType.MerchantKind: {
        const filter = this.restaurantCategories.find((item) => item.id === tile.restaurantCategoryId);
        return [this.merchantKindLabel(tile.merchantKind), filter?.title].filter(Boolean).join(' · ') || 'لم يتم اختيار نوع المتاجر';
      }
      case HomeCategoryLinkType.Merchant:
        return this.merchants.find((merchant) => merchant.id === tile.merchantId)?.title || 'لم يتم اختيار متجر';
      case HomeCategoryLinkType.Search:
        return tile.searchTerm?.trim() || 'لم تُحدّد كلمة البحث';
      case HomeCategoryLinkType.ErrandRequests:
        return 'يفتح نموذج طلب غرض';
      default:
        return 'وجهة غير معروفة';
    }
  }

  normalizeMaxItems(): void {
    const value = Number(this.config.maxItems);
    this.config.maxItems = Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0;
  }

  moveUp(index: number): void {
    if (index <= 0) {
      return;
    }
    const tiles = this.config.tiles;
    [tiles[index - 1], tiles[index]] = [tiles[index], tiles[index - 1]];
    this.renumber();
  }

  moveDown(index: number): void {
    if (index >= this.config.tiles.length - 1) {
      return;
    }
    const tiles = this.config.tiles;
    [tiles[index + 1], tiles[index]] = [tiles[index], tiles[index + 1]];
    this.renumber();
  }

  /**
   * Clears the targets that no longer apply, so a tile can never carry a
   * leftover destination from a type it is no longer using.
   */
  onLinkTypeChange(tile: HomeCategoryTile): void {
    if (
      tile.linkType !== HomeCategoryLinkType.ProductCategory &&
      tile.linkType !== HomeCategoryLinkType.MerchantCategory
    ) {
      tile.productCategoryId = null;
    }
    if (tile.linkType !== HomeCategoryLinkType.ProductCategory) {
      tile.secondaryProductCategoryId = null;
    }
    if (
      tile.linkType !== HomeCategoryLinkType.Merchant &&
      tile.linkType !== HomeCategoryLinkType.MerchantCategory
    ) {
      tile.merchantId = null;
    }
    if (tile.linkType !== HomeCategoryLinkType.MerchantKind) {
      tile.merchantKind = null;
      tile.restaurantCategoryId = null;
    }
    if (tile.linkType !== HomeCategoryLinkType.Search) {
      tile.searchTerm = '';
    }
    if (tile.linkType === HomeCategoryLinkType.ErrandRequests) {
      tile.title ||= 'طلبات';
      tile.titleEn ||= 'Requests';
    }
  }

  onMerchantKindChange(tile: HomeCategoryTile): void {
    if (tile.merchantKind !== 0) {
      tile.restaurantCategoryId = null;
    }
    this.onTargetChange(tile);
  }

  onMerchantChange(tile: HomeCategoryTile): void {
    if (tile.productCategoryId && !this.isCategoryInMerchant(tile.merchantId, tile.productCategoryId)) {
      tile.productCategoryId = null;
    }
    this.onTargetChange(tile);
  }

  /** Fills an empty title from whatever the tile now points at. */
  onTargetChange(tile: HomeCategoryTile): void {
    if (tile.title && tile.title.trim().length) {
      return;
    }
    if (tile.linkType === HomeCategoryLinkType.ProductCategory && tile.productCategoryId) {
      tile.title = this.categories.find((c) => c.id === tile.productCategoryId)?.title ?? '';
    } else if (tile.linkType === HomeCategoryLinkType.Merchant && tile.merchantId) {
      tile.title = this.merchants.find((m) => m.id === tile.merchantId)?.title ?? '';
    } else if (tile.linkType === HomeCategoryLinkType.MerchantCategory) {
      const cat = this.categories.find((c) => c.id === tile.productCategoryId);
      if (cat) {
        tile.title = cat.title;
      }
    } else if (tile.linkType === HomeCategoryLinkType.MerchantKind && tile.merchantKind != null) {
      tile.title = this.merchantKindLabel(tile.merchantKind);
    }
  }

  onSecondaryTargetChange(tile: HomeCategoryTile): void {
    // Secondary target selection updated
  }

  merchantKindLabel(kind: number | null | undefined): string {
    if (kind === null || kind === undefined) {
      return '';
    }
    return MERCHANT_KIND_LABELS[kind] ?? `نوع ${kind}`;
  }

  categoryLabel(category: HomeCategoryTarget): string {
    const title = category.parentTitle
      ? `${category.parentTitle} ← ${category.title}`
      : category.title;
    return `${title} — ${this.categoryAvailabilitySummary(category)}`;
  }

  categoryAvailabilitySummary(category: HomeCategoryTarget): string {
    const productCount = category.productCount ?? 0;
    const merchantCount = category.merchantCount ?? 0;
    if (productCount > 0 && merchantCount === 0) {
      return `${productCount} منتج في الكتالوج • لا يوجد متجر يبيعه حالياً`;
    }
    return `${productCount} منتج متاح للبيع • ${merchantCount} متجر نشط`;
  }

  get jtakMarketMerchantId(): number | null {
    const markets = this.merchants.filter(merchant => merchant.isJtakMarket === true);
    return markets.length === 1 ? markets[0].id : null;
  }

  merchantKindOptionLabel(kind: HomeCategoryMerchantKind): string {
    return `${this.merchantKindLabel(kind.value)} — ${kind.merchantCount ?? 0} متجر`;
  }

  merchantOptionLabel(merchant: HomeCategoryMerchant): string {
    return `${merchant.title} (${this.merchantKindLabel(merchant.merchantKind)}) — ${merchant.productCount ?? 0} منتج`;
  }

  /** Only sellable departments belong in a link to this merchant. Retain an
   * existing unavailable choice so the admin can see and replace it. */
  getCategoriesForMerchant(
    merchantId?: number | null,
    selectedCategoryId?: number | null
  ): HomeCategoryTarget[] {
    if (!merchantId) return [];
    const catSet = new Set(this.merchantCategoryMap[merchantId] ?? []);
    return this.categories.filter((category) =>
      catSet.has(category.id) || category.id === selectedCategoryId
    );
  }

  isCategoryInMerchant(merchantId?: number | null, categoryId?: number | null): boolean {
    if (!merchantId || !categoryId) return false;
    const catIds = this.merchantCategoryMap[merchantId];
    return catIds ? catIds.includes(categoryId) : false;
  }

  categorySearchFn(term: string, item: HomeCategoryTarget): boolean {
    term = term.toLowerCase().trim();
    return (
      (item.title && item.title.toLowerCase().includes(term)) ||
      (item.parentTitle && item.parentTitle.toLowerCase().includes(term)) ||
      item.id.toString().includes(term)
    );
  }

  merchantSearchFn(term: string, item: HomeCategoryMerchant): boolean {
    term = term.toLowerCase().trim();
    return (
      (item.title && item.title.toLowerCase().includes(term)) ||
      item.id.toString().includes(term)
    );
  }

  tileAvailabilityProblem(tile: HomeCategoryTile): string | null {
    if (!tile.active || this.tileProblem(tile)) {
      return null;
    }

    switch (tile.linkType) {
      case HomeCategoryLinkType.ProductCategory: {
        const targets = this.categories.filter(item => item.id === tile.productCategoryId || item.id === tile.secondaryProductCategoryId);
        if (!this.categories.some(item => item.id === tile.productCategoryId)) return 'لن تظهر للعملاء حالياً: القسم الأساسي غير موجود أو غير مفعّل.';
        return targets.some(category => category.productCount > 0 && category.merchantCount > 0)
          ? null
          : 'لن تظهر للعملاء حالياً: لا توجد منتجات مسعّرة لدى متجر نشط في هذا القسم.';
      }
      case HomeCategoryLinkType.MerchantKind: {
        const kind = this.merchantKinds.find((item) => item.value === tile.merchantKind);
        if (tile.merchantKind === 0 && tile.restaurantCategoryId != null) {
          const filter = this.restaurantCategories.find(
            (item) => item.id === tile.restaurantCategoryId
          );
          if (!filter || !filter.active) {
            return 'فلتر المطاعم المحدد غير موجود أو غير مفعّل.';
          }
        }
        return kind && kind.merchantCount > 0
          ? null
          : 'لن تظهر للعملاء حالياً: لا يوجد متجر نشط من هذا النوع.';
      }
      case HomeCategoryLinkType.Merchant:
        return this.merchants.some((merchant) => merchant.id === tile.merchantId)
          ? null
          : 'لن تظهر للعملاء حالياً: المتجر غير موجود أو غير مفعّل.';
      case HomeCategoryLinkType.MerchantCategory: {
        const merchant = this.merchants.find((m) => m.id === tile.merchantId);
        if (!merchant) {
          return 'لن تظهر للعملاء حالياً: المتجر المحدد غير موجود أو معطل.';
        }
        const category = this.categories.find((c) => c.id === tile.productCategoryId);
        if (!category) {
          return 'لن تظهر للعملاء حالياً: القسم المحدد غير موجود.';
        }
        const hasStock = this.isCategoryInMerchant(tile.merchantId, tile.productCategoryId);
        if (!hasStock) {
          return `تنبيه: متجر "${merchant.title}" لا يحتوي حالياً على منتجات مسعّرة في هذا القسم.`;
        }
        return null;
      }
      case HomeCategoryLinkType.Search:
        return null;
      case HomeCategoryLinkType.ErrandRequests:
        return null;
      default:
        return 'لن تظهر للعملاء حالياً: الوجهة غير متاحة.';
    }
  }

  /** The problem the admin needs to fix before this tile can go live. */
  tileProblem(tile: HomeCategoryTile): string | null {
    if (!tile.title || !tile.title.trim().length) {
      return 'أدخل اسم الفئة';
    }
    switch (tile.linkType) {
      case HomeCategoryLinkType.ProductCategory:
        return tile.productCategoryId ? null : 'اختر القسم الذي تفتحه هذه الفئة';
      case HomeCategoryLinkType.MerchantKind:
        if (tile.merchantKind === null || tile.merchantKind === undefined) {
          return 'اختر نوع المتاجر';
        }
        if (tile.restaurantCategoryId != null) {
          const filter = this.restaurantCategories.find(
            (item) => item.id === tile.restaurantCategoryId
          );
          if (tile.merchantKind !== 0) return 'فلتر المطاعم متاح عند اختيار نوع المتاجر: مطاعم';
          if (!filter || !filter.active) return 'اختر فلتر مطاعم مفعّلاً';
        }
        return null;
      case HomeCategoryLinkType.Merchant:
        return tile.merchantId ? null : 'اختر المتجر';
      case HomeCategoryLinkType.MerchantCategory:
        if (!tile.merchantId) return 'اختر المتجر أو الماركت';
        if (!tile.productCategoryId) return 'اختر القسم المطلوب داخل هذا المتجر';
        return null;
      case HomeCategoryLinkType.Search:
        return tile.searchTerm && tile.searchTerm.trim().length ? null : 'أدخل كلمة البحث';
      case HomeCategoryLinkType.ErrandRequests:
        return this.config.tiles.filter(
          (item) => item.linkType === HomeCategoryLinkType.ErrandRequests
        ).length > 1
          ? 'يمكن إضافة فئة «طلبات» مرة واحدة فقط'
          : null;
      default:
        return 'نوع وجهة غير معروف';
    }
  }

  get invalidCount(): number {
    return this.config.tiles.filter((tile) => this.tileProblem(tile) !== null).length;
  }

  get activeCount(): number {
    return this.config.tiles.filter((tile) => tile.active).length;
  }

  get unavailableCount(): number {
    return this.config.tiles.filter(
      (tile) => tile.active && this.tileAvailabilityProblem(tile) !== null
    ).length;
  }

  /** How many active tiles the app will actually show, given MaxItems. */
  get visibleCount(): number {
    if (!this.config.enabled) return 0;
    const active = this.config.tiles.filter(
      (tile) => tile.active && this.tileProblem(tile) === null && this.tileAvailabilityProblem(tile) === null
    ).length;
    return this.config.maxItems > 0 ? Math.min(active, this.config.maxItems) : active;
  }

  isHidden(index: number): boolean {
    if (this.config.maxItems <= 0) {
      return false;
    }
    const activeBefore = this.config.tiles
      .slice(0, index + 1)
      .filter((tile) => tile.active && this.tileProblem(tile) === null && this.tileAvailabilityProblem(tile) === null).length;
    return this.config.tiles[index].active && activeBefore > this.config.maxItems;
  }

  save(): void {
    if (this.loading || this.saving) return;
    this.saveError = null;
    this.saveSuccess = false;

    if (this.invalidCount > 0) {
      this.saveError = 'بعض الفئات غير مكتملة. أكمل الحقول المطلوبة قبل الحفظ.';
      return;
    }

    this.renumber();
    this.saving = true;
    const submittedTiles = this.config.tiles.slice();
    const submitted: HomeCategoriesConfig = JSON.parse(this.serializeConfig());
    this.requests.add(this.service.save(submitted).subscribe({
      next: (tiles) => {
        const persistedTiles = [...(tiles ?? [])].sort(
          (a, b) => (a.order ?? 0) - (b.order ?? 0)
        );
        const secondaryTargetWasDropped = submitted.tiles.some((tile, index) => {
          const requestedId = Number(tile.secondaryProductCategoryId);
          if (!Number.isInteger(requestedId) || requestedId <= 0) return false;
          return Number(persistedTiles[index]?.secondaryProductCategoryId) !== requestedId;
        });

        if (secondaryTargetWasDropped) {
          this.saveError =
            'لم يؤكد الخادم حفظ القسم المستهدف الثاني. حدّث الـBackend الداعم لدمج الأقسام ثم أعد الحفظ.';
          this.saving = false;
          this.cdr.detectChanges();
          return;
        }

        this.resolved = tiles ?? [];
        submitted.tiles.forEach((tile, index) => {
          const id = persistedTiles[index]?.id;
          if (id && !tile.id) {
            if (this.config.tiles.includes(submittedTiles[index]) && !submittedTiles[index].id) submittedTiles[index].id = id;
            tile.id = id;
          }
        });
        this.savedConfigSnapshot = JSON.stringify(submitted);
        this.saving = false;
        this.saveSuccess = true;
        this.cdr.detectChanges();
        clearTimeout(this.successTimer);
        this.successTimer = setTimeout(() => {
          this.saveSuccess = false;
          this.cdr.detectChanges();
        }, 3000);
      },
      error: (err) => {
        this.saving = false;
        this.saveError =
          typeof err?.error === 'string' ? err.error : 'تعذر حفظ الإعدادات، حاول مرة أخرى';
        this.cdr.detectChanges();
      },
    }));
  }

  trackByIndex(index: number): number {
    return index;
  }

  getEffectiveImageUrl(tile: HomeCategoryTile): string | null {
    if (tile.imageUrl && tile.imageUrl.trim().length > 0) {
      return tile.imageUrl.trim();
    }
    if (tile.linkType === HomeCategoryLinkType.ProductCategory && tile.productCategoryId) {
      return this.categories.find((c) => c.id === tile.productCategoryId)?.icon || null;
    }
    if (tile.linkType === HomeCategoryLinkType.Merchant && tile.merchantId) {
      return this.merchants.find((m) => m.id === tile.merchantId)?.photo || null;
    }
    if (tile.linkType === HomeCategoryLinkType.MerchantCategory) {
      const cat = this.categories.find((c) => c.id === tile.productCategoryId);
      if (cat?.icon) return cat.icon;
      const m = this.merchants.find((m) => m.id === tile.merchantId);
      return m?.photo || null;
    }
    return null;
  }

  linkTypeHint(linkType: HomeCategoryLinkType): string {
    return this.linkTypes.find((type) => type.value === linkType)?.hint ?? '';
  }

  resolvePreviewUrl(url: string | null | undefined): string {
    if (!url || !url.trim().length) {
      return './assets/media/svg/files/blank-image.svg';
    }
    const trimmed = url.trim();
    if (
      trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:image/') ||
      trimmed.startsWith('assets/') ||
      trimmed.startsWith('./assets/')
    ) {
      return trimmed;
    }
    return this.filesService.getFile(trimmed, 120, 120);
  }

  handleImageError(event: Event): void {
    const img = event.target as HTMLImageElement;
    if (img && !img.src.includes('blank-image.svg')) {
      img.src = './assets/media/svg/files/blank-image.svg';
      img.title = 'تعذر تحميل الصورة من هذا الرابط، تأكد من صحته';
    }
  }

  onImageUrlChange(tile: HomeCategoryTile): void {
    if (tile.imageUrl) {
      tile.imageUrl = tile.imageUrl.trim();
    }
  }

  onImageUploaded(fileIds: string[], tile: HomeCategoryTile): void {
    const imageId = fileIds?.find((id) => !!id?.trim())?.trim();
    if (!imageId) {
      return;
    }

    tile.imageUrl = imageId;
    this.cdr.detectChanges();
  }

  clearImageUrl(tile: HomeCategoryTile): void {
    tile.imageUrl = '';
    this.cdr.detectChanges();
  }

  openImageInNewTab(url?: string | null): void {
    if (!url) return;
    const trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      window.open(trimmed, '_blank');
    } else {
      window.open(this.resolvePreviewUrl(trimmed), '_blank');
    }
  }

  async pasteFromClipboard(tile: HomeCategoryTile): Promise<void> {
    try {
      if (navigator.clipboard && navigator.clipboard.readText) {
        const text = await navigator.clipboard.readText();
        if (text && text.trim().length > 0) {
          tile.imageUrl = text.trim();
          this.cdr.detectChanges();
        }
      }
    } catch (err) {
      console.warn('Clipboard read failed or permission denied:', err);
    }
  }

  private renumber(): void {
    this.config.tiles.forEach((tile, index) => (tile.order = index));
  }

  private serializeConfig(): string {
    return JSON.stringify(this.config);
  }
}
