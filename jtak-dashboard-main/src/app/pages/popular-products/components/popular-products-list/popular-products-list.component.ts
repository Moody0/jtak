import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { Subscription } from 'rxjs';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import {
  AdminPopularProductItem,
  AdminPopularSectionResponse,
  PopularSectionConfig,
} from '../../models/popular-product.model';
import { PopularProductsService } from '../../services/popular-products.service';
import { AddPopularProductModalComponent } from '../add-popular-product-modal/add-popular-product-modal.component';

@Component({
  selector: 'app-popular-products-list',
  templateUrl: './popular-products-list.component.html',
  styleUrls: ['./popular-products-list.component.scss'],
})
export class PopularProductsListComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  private loadRequest?: Subscription;
  private destroyed = false;

  isLoading = false;
  isSaving = false;
  loadError = false;
  readonly pendingToggleIds = new Set<number>();

  // Configuration
  mode: 'Manual' | 'Hybrid' | 'Auto' = 'Hybrid';
  sectionTitle = 'الأكثر طلباً';
  sectionTitleEn = 'Most Popular';
  maxItems = 15;
  enabled = true;

  items: AdminPopularProductItem[] = [];
  searchTerm = '';

  constructor(
    private popularService: PopularProductsService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    if (this.isSaving) return;
    this.loadRequest?.unsubscribe();
    this.isLoading = true;
    this.subs.sink = this.loadRequest = this.popularService.getConfig().subscribe({
      next: (res: AdminPopularSectionResponse) => {
        this.isLoading = false;
        this.loadError = false;
        this.mode = res.mode || 'Hybrid';
        this.sectionTitle = res.sectionTitle || 'الأكثر طلباً';
        this.sectionTitleEn = res.sectionTitleEn || 'Most Popular';
        this.maxItems = res.maxItems || 15;
        this.enabled = res.enabled !== false;
        this.items = (res.items || []).map((item, idx) => ({
          ...item,
          order: idx + 1,
        }));
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoading = false;
        this.loadError = true;
        this.toastr.error('تعذر تحميل بيانات قسم الأكثر طلباً');
        this.cdr.detectChanges();
      },
    });
  }

  get displayedItems(): AdminPopularProductItem[] {
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
    if (this.busy) return;
    const previous = this.mode;
    this.mode = newMode;
    this.saveConfig(false, () => this.mode = previous);
  }

  toggleSectionEnabled(): void {
    if (this.busy) return;
    const previous = this.enabled;
    this.enabled = !this.enabled;
    this.saveConfig(false, () => this.enabled = previous);
  }

  toggleItemActive(item: AdminPopularProductItem): void {
    if (this.busy) return;
    this.isSaving = true;
    this.pendingToggleIds.add(item.productId);
    item.active = !item.active;
    this.subs.sink = this.popularService.toggleItem(item.productId, item.active).subscribe({
      next: () => {
        this.pendingToggleIds.delete(item.productId);
        this.isSaving = false;
        this.toastr.success(
          item.active ? 'تم تفعيل ظهور المنتج بالقسم' : 'تم إخفاء المنتج من القسم'
        );
        this.cdr.detectChanges();
      },
      error: () => {
        this.pendingToggleIds.delete(item.productId);
        this.isSaving = false;
        item.active = !item.active;
        this.toastr.error('تعذر تحديث حالة المنتج');
        this.cdr.detectChanges();
      },
    });
  }

  moveUp(index: number): void {
    if (this.busy || this.hasSearchFilter || index <= 0 || index >= this.items.length) return;
    const previous = this.items.map(item => ({ ...item }));
    const temp = this.items[index];
    this.items[index] = this.items[index - 1];
    this.items[index - 1] = temp;
    this.reindexOrders();
    this.saveReorder(previous);
  }

  moveDown(index: number): void {
    if (this.busy || this.hasSearchFilter || index < 0 || index >= this.items.length - 1) return;
    const previous = this.items.map(item => ({ ...item }));
    const temp = this.items[index];
    this.items[index] = this.items[index + 1];
    this.items[index + 1] = temp;
    this.reindexOrders();
    this.saveReorder(previous);
  }

  removeItem(item: AdminPopularProductItem): void {
    if (this.busy) return;
    if (
      !confirm(
        `هل أنت متأكد من إزالة منتج "${item.title}" من القائمة المختارة؟ ${this.mode !== 'Manual' ? 'قد يظهر تلقائياً حسب الطلبات. استخدم إخفاء المنتج لمنع ظهوره تماماً.' : ''}`
      )
    ) {
      return;
    }

    this.isSaving = true;
    this.subs.sink = this.popularService.removeItem(item.productId).subscribe({
      next: () => {
        this.isSaving = false;
        this.items = this.items.filter((x) => x.productId !== item.productId);
        this.reindexOrders();
        this.toastr.success('تمت إزالة المنتج من قسم الأكثر طلباً');
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.cdr.detectChanges();
        this.toastr.error('تعذر إزالة المنتج');
      },
    });
  }

  openAddModal(): void {
    if (this.busy) return;
    const modalRef = this.modalService.open(AddPopularProductModalComponent, {
      size: 'lg',
      backdrop: 'static',
      keyboard: false,
    });

    modalRef.componentInstance.existingIds = this.items.map((x) => x.productId);
    modalRef.componentInstance.nextOrder = this.items.length + 1;

    modalRef.result.then(
      (result) => {
        if (!this.destroyed && result === true) {
          this.loadData();
        }
      },
      () => {}
    );
  }

  get busy(): boolean { return this.isLoading || this.isSaving || this.loadError; }

  saveConfig(showToast = true, rollback?: () => void): void {
    if (this.busy) return;
    if (!Number.isInteger(Number(this.maxItems)) || this.maxItems < 1 || this.maxItems > 100) {
      rollback?.();
      this.toastr.warning("عدد المنتجات يجب أن يكون بين 1 و100");
      return;
    }
    this.isSaving = true;
    const payload: PopularSectionConfig = {
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

    this.subs.sink = this.popularService.saveConfig(payload).subscribe({
      next: () => {
        this.isSaving = false;
        if (showToast) {
          this.toastr.success('تم حفظ إعدادات وترتيب الأكثر طلباً بنجاح');
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        rollback?.();
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

  private saveReorder(previous: typeof this.items): void {
    this.isSaving = true;
    const productIds = this.items.map((x) => x.productId);
    this.subs.sink = this.popularService.reorder(productIds).subscribe({
      next: () => {
        this.isSaving = false;
        this.toastr.success('تم تحديث الترتيب بنجاح');
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.items = previous;
        this.cdr.detectChanges();
        this.toastr.error('تعذر حفظ الترتيب');
      },
    });
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.loadRequest?.unsubscribe();
    this.subs.unsubscribe();
  }
}
