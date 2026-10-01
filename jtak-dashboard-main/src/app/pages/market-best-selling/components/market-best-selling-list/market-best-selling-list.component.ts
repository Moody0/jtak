import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import {
  AdminMarketBestSellingProductItem,
  AdminMarketBestSellingSectionResponse,
  MarketBestSellingSectionConfig,
} from '../../models/market-best-selling.model';
import { MarketBestSellingService } from '../../services/market-best-selling.service';
import { AddMarketBestSellingModalComponent } from '../add-market-best-selling-modal/add-market-best-selling-modal.component';

@Component({
  selector: 'app-market-best-selling-list',
  templateUrl: './market-best-selling-list.component.html',
  styleUrls: ['./market-best-selling-list.component.scss'],
})
export class MarketBestSellingListComponent implements OnInit, OnDestroy {
  private subs = new SubSink();

  isLoading = false;
  isSaving = false;
  loadError = false;
  readonly pendingToggleIds = new Set<number>();

  // Configuration
  mode: 'Manual' | 'Hybrid' | 'Auto' = 'Hybrid';
  sectionTitle = 'الأكثر مبيعًا';
  sectionTitleEn = 'Best Selling';
  maxItems = 10;
  enabled = true;

  items: AdminMarketBestSellingProductItem[] = [];
  searchTerm = '';

  constructor(
    private bestSellingService: MarketBestSellingService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    this.isLoading = true;
    this.subs.sink = this.bestSellingService.getConfig().subscribe({
      next: (res: AdminMarketBestSellingSectionResponse) => {
        this.isLoading = false;
        this.loadError = false;
        this.mode = res.mode || 'Hybrid';
        this.sectionTitle = res.sectionTitle || 'الأكثر مبيعًا';
        this.sectionTitleEn = res.sectionTitleEn || 'Best Selling';
        this.maxItems = res.maxItems || 10;
        this.enabled = res.enabled !== false;
        this.items = (res.items || []).map((item, idx) => ({
          ...item,
          order: idx + 1,
        }));
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.loadError = true;
        this.toastr.error('تعذر تحميل بيانات قسم الأكثر مبيعًا بالسوبرماركت');
        this.cdr.detectChanges();
      },
    });
  }

  get displayedItems(): AdminMarketBestSellingProductItem[] {
    if (!this.searchTerm || !this.searchTerm.trim()) {
      return this.items;
    }
    const term = this.searchTerm.trim().toLowerCase();
    return this.items.filter(
      (item) =>
        item.title?.toLowerCase().includes(term) ||
        item.merchantTitle?.toLowerCase().includes(term) ||
        item.categoryTitle?.toLowerCase().includes(term) ||
        item.productId?.toString().includes(term)
    );
  }

  get hasSearchFilter(): boolean {
    return !!this.searchTerm && this.searchTerm.trim().length > 0;
  }

  get activeItemsCount(): number {
    return this.items.filter((x) => x.active).length;
  }

  setMode(newMode: 'Manual' | 'Hybrid' | 'Auto'): void {
    this.mode = newMode;
    this.saveConfig(false);
  }

  toggleSectionEnabled(): void {
    this.enabled = !this.enabled;
    this.saveConfig(false);
  }

  toggleItemActive(item: AdminMarketBestSellingProductItem): void {
    if (this.pendingToggleIds.has(item.productId)) return;
    this.pendingToggleIds.add(item.productId);
    item.active = !item.active;
    this.bestSellingService.toggleItem(item.productId, item.active).subscribe({
      next: () => {
        this.pendingToggleIds.delete(item.productId);
        this.toastr.success(
          item.active ? 'تم تفعيل ظهور الصنف بالقسم' : 'تم إخفاء الصنف من القسم'
        );
        this.cdr.detectChanges();
      },
      error: () => {
        this.pendingToggleIds.delete(item.productId);
        item.active = !item.active;
        this.toastr.error('تعذر تحديث حالة الصنف');
        this.cdr.detectChanges();
      },
    });
  }

  moveUp(index: number): void {
    if (this.hasSearchFilter || index <= 0 || index >= this.items.length) return;
    const temp = this.items[index];
    this.items[index] = this.items[index - 1];
    this.items[index - 1] = temp;
    this.reindexOrders();
    this.saveReorder();
  }

  moveDown(index: number): void {
    if (this.hasSearchFilter || index < 0 || index >= this.items.length - 1) return;
    const temp = this.items[index];
    this.items[index] = this.items[index + 1];
    this.items[index + 1] = temp;
    this.reindexOrders();
    this.saveReorder();
  }

  removeItem(item: AdminMarketBestSellingProductItem): void {
    if (
      !confirm(
        `هل أنت متأكد من إزالة صنف "${item.title}" من قسم الأكثر مبيعًا؟`
      )
    ) {
      return;
    }

    this.bestSellingService.removeItem(item.productId).subscribe({
      next: () => {
        this.items = this.items.filter((x) => x.productId !== item.productId);
        this.reindexOrders();
        this.toastr.success('تمت إزالة الصنف من قسم الأكثر مبيعًا');
        this.cdr.detectChanges();
      },
      error: () => {
        this.toastr.error('تعذر إزالة الصنف');
      },
    });
  }

  openAddModal(): void {
    const modalRef = this.modalService.open(AddMarketBestSellingModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: false,
    });

    modalRef.componentInstance.existingIds = this.items.map((x) => x.productId);
    modalRef.componentInstance.nextOrder = this.items.length + 1;

    modalRef.result.then(
      (result) => {
        if (result === true) {
          this.loadData();
        }
      },
      () => {}
    );
  }

  saveConfig(showToast = true): void {
    this.isSaving = true;
    const payload: MarketBestSellingSectionConfig = {
      mode: this.mode,
      sectionTitle: this.sectionTitle,
      sectionTitleEn: this.sectionTitleEn,
      maxItems: this.maxItems,
      enabled: this.enabled,
      items: this.items.map((item, idx) => ({
        productId: item.productId,
        order: idx + 1,
        active: item.active,
        customBadge: item.customBadge,
        customTitle: item.customTitle,
      })),
    };

    this.subs.sink = this.bestSellingService.saveConfig(payload).subscribe({
      next: () => {
        this.isSaving = false;
        if (showToast) {
          this.toastr.success('تم حفظ إعدادات وترتيب الأكثر مبيعًا بنجاح');
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.toastr.error('تعذر حفظ الإعدادات');
        this.cdr.detectChanges();
      },
    });
  }

  private reindexOrders(): void {
    this.items.forEach((item, idx) => {
      item.order = idx + 1;
    });
  }

  private saveReorder(): void {
    const productIds = this.items.map((x) => x.productId);
    this.subs.sink = this.bestSellingService.reorder(productIds).subscribe({
      next: () => {
        this.toastr.success('تم تحديث الترتيب بنجاح');
        this.cdr.detectChanges();
      },
      error: () => {
        this.toastr.error('تعذر حفظ الترتيب');
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
