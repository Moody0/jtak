import { ChangeDetectorRef, Component, OnInit } from '@angular/core';
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
import { HomeCategoriesService } from '../../services/home-categories.service';

@Component({
  selector: 'app-home-categories-list',
  templateUrl: './home-categories-list.component.html',
  styleUrls: ['./home-categories-list.component.scss'],
})
export class HomeCategoriesListComponent implements OnInit {
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

  readonly linkTypes = LINK_TYPE_LABELS;
  readonly LinkType = HomeCategoryLinkType;

  constructor(
    private service: HomeCategoriesService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.service.get().subscribe({
      next: (vm: HomeCategoriesAdminVm) => {
        this.config = vm.config ?? this.config;
        this.config.tiles = vm.config?.tiles ?? [];
        this.categories = vm.availableCategories ?? [];
        this.merchants = vm.availableMerchants ?? [];
        this.merchantKinds = vm.availableMerchantKinds ?? [];
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
            merchantKind: tile.merchantKind,
            merchantId: tile.merchantId,
            searchTerm: tile.searchTerm,
          }));
        }
        this.renumber();
        this.loading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.loading = false;
        this.saveError = 'تعذر تحميل إعدادات فئات الصفحة الرئيسية';
        this.cdr.detectChanges();
      },
    });
  }

  addTile(): void {
    this.config.tiles.push({
      title: '',
      titleEn: '',
      imageUrl: '',
      order: this.config.tiles.length,
      active: true,
      linkType: HomeCategoryLinkType.ProductCategory,
      productCategoryId: null,
      merchantKind: null,
      merchantId: null,
      searchTerm: '',
    });
    this.renumber();
  }

  removeTile(index: number): void {
    this.config.tiles.splice(index, 1);
    this.renumber();
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
    tile.productCategoryId =
      tile.linkType === HomeCategoryLinkType.ProductCategory ? tile.productCategoryId : null;
    tile.merchantKind =
      tile.linkType === HomeCategoryLinkType.MerchantKind ? tile.merchantKind : null;
    tile.merchantId = tile.linkType === HomeCategoryLinkType.Merchant ? tile.merchantId : null;
    tile.searchTerm = tile.linkType === HomeCategoryLinkType.Search ? tile.searchTerm : '';
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
    } else if (tile.linkType === HomeCategoryLinkType.MerchantKind && tile.merchantKind != null) {
      tile.title = this.merchantKindLabel(tile.merchantKind);
    }
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
    return `${title} — ${category.productCount ?? 0} منتج / ${category.merchantCount ?? 0} متجر`;
  }

  merchantKindOptionLabel(kind: HomeCategoryMerchantKind): string {
    return `${this.merchantKindLabel(kind.value)} — ${kind.merchantCount ?? 0} متجر`;
  }

  merchantOptionLabel(merchant: HomeCategoryMerchant): string {
    return `${merchant.title} (${this.merchantKindLabel(merchant.merchantKind)}) — ${merchant.productCount ?? 0} منتج`;
  }

  tileAvailabilityProblem(tile: HomeCategoryTile): string | null {
    if (!tile.active || this.tileProblem(tile)) {
      return null;
    }

    switch (tile.linkType) {
      case HomeCategoryLinkType.ProductCategory: {
        const category = this.categories.find((item) => item.id === tile.productCategoryId);
        return category && category.productCount > 0 && category.merchantCount > 0
          ? null
          : 'لن تظهر للعملاء حالياً: لا توجد منتجات مسعّرة لدى متجر نشط في هذا القسم.';
      }
      case HomeCategoryLinkType.MerchantKind: {
        const kind = this.merchantKinds.find((item) => item.value === tile.merchantKind);
        return kind && kind.merchantCount > 0
          ? null
          : 'لن تظهر للعملاء حالياً: لا يوجد متجر نشط من هذا النوع.';
      }
      case HomeCategoryLinkType.Merchant:
        return this.merchants.some((merchant) => merchant.id === tile.merchantId)
          ? null
          : 'لن تظهر للعملاء حالياً: المتجر غير موجود أو غير مفعّل.';
      case HomeCategoryLinkType.Search:
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
        return tile.merchantKind !== null && tile.merchantKind !== undefined
          ? null
          : 'اختر نوع المتاجر';
      case HomeCategoryLinkType.Merchant:
        return tile.merchantId ? null : 'اختر المتجر';
      case HomeCategoryLinkType.Search:
        return tile.searchTerm && tile.searchTerm.trim().length ? null : 'أدخل كلمة البحث';
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
    const active = this.config.tiles.filter(
      (tile) => tile.active && this.tileAvailabilityProblem(tile) === null
    ).length;
    return this.config.maxItems > 0 ? Math.min(active, this.config.maxItems) : active;
  }

  isHidden(index: number): boolean {
    if (this.config.maxItems <= 0) {
      return false;
    }
    const activeBefore = this.config.tiles
      .slice(0, index + 1)
      .filter((tile) => tile.active).length;
    return this.config.tiles[index].active && activeBefore > this.config.maxItems;
  }

  save(): void {
    this.saveError = null;
    this.saveSuccess = false;

    if (this.invalidCount > 0) {
      this.saveError = 'بعض الفئات غير مكتملة. أكمل الحقول المطلوبة قبل الحفظ.';
      return;
    }

    this.renumber();
    this.saving = true;
    this.service.save(this.config).subscribe({
      next: (tiles) => {
        this.resolved = tiles ?? [];
        this.saving = false;
        this.saveSuccess = true;
        this.cdr.detectChanges();
        setTimeout(() => {
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
    });
  }

  trackByIndex(index: number): number {
    return index;
  }

  private renumber(): void {
    this.config.tiles.forEach((tile, index) => (tile.order = index));
  }
}
