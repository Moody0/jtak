import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import {
  AdminRestaurantCategoriesResponse,
  RestaurantCategoriesSectionConfig,
  RestaurantCategoryItem,
  RestaurantCategoryTarget,
} from '../../models/restaurant-category.model';
import { RestaurantCategoriesService } from '../../services/restaurant-categories.service';
import { EditRestaurantCategoryModalComponent } from '../edit-restaurant-category-modal/edit-restaurant-category-modal.component';
import { DeleteRestaurantCategoryModalComponent } from '../delete-restaurant-category-modal/delete-restaurant-category-modal.component';

@Component({
  selector: 'app-restaurant-categories-list',
  templateUrl: './restaurant-categories-list.component.html',
  styleUrls: ['./restaurant-categories-list.component.scss'],
})
export class RestaurantCategoriesListComponent implements OnInit, OnDestroy {
  private subs = new SubSink();

  isLoading = false;
  isSaving = false;
  loadError = false;
  readonly pendingToggleIds = new Set<number>();

  sectionTitle = 'كل المطاعم';
  sectionTitleEn = 'All Restaurants';
  homeSectionTitle = 'أصناف متنوعة';
  homeSectionTitleEn = 'Browse by kind';
  enabled = true;
  showOnHome = true;
  availableCategories: RestaurantCategoryTarget[] = [];

  items: RestaurantCategoryItem[] = [];
  searchTerm = '';

  constructor(
    private service: RestaurantCategoriesService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.loadData();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  loadData(): void {
    this.isLoading = true;
    this.subs.sink = this.service.getConfig().subscribe({
      next: (res: AdminRestaurantCategoriesResponse) => {
        this.isLoading = false;
        this.loadError = false;
        this.sectionTitle = res.sectionTitle || 'كل المطاعم';
        this.sectionTitleEn = res.sectionTitleEn || 'All Restaurants';
        this.homeSectionTitle = res.homeSectionTitle || 'أصناف متنوعة';
        this.homeSectionTitleEn = res.homeSectionTitleEn || 'Browse by kind';
        this.enabled = res.enabled !== false;
        this.showOnHome = res.showOnHome !== false;
        this.availableCategories = res.availableCategories || [];
        this.items = (res.items || []).map((item, idx) => ({
          ...item,
          order: idx + 1,
        }));
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.loadError = true;
        this.toastr.error('تعذر تحميل تصنيفات المطاعم');
        this.cdr.detectChanges();
      },
    });
  }

  get displayedItems(): RestaurantCategoryItem[] {
    if (!this.searchTerm || !this.searchTerm.trim()) {
      return this.items;
    }
    const term = this.searchTerm.trim().toLowerCase();
    return this.items.filter(
      (item) =>
        item.title?.toLowerCase().includes(term) ||
        item.titleEn?.toLowerCase().includes(term) ||
        item.filterTag?.toLowerCase().includes(term) ||
        item.id?.toString().includes(term)
    );
  }

  get hasSearchFilter(): boolean {
    return !!this.searchTerm && this.searchTerm.trim().length > 0;
  }

  get activeItemsCount(): number {
    return this.items.filter((x) => x.active).length;
  }

  get disabledItemsCount(): number {
    return this.items.filter((x) => !x.active).length;
  }

  getImageUrl(imagePath?: string): string {
    if (!imagePath || !imagePath.trim()) {
      return './assets/media/svg/files/blank-image.svg';
    }
    const val = imagePath.trim();
    if (val.startsWith('http://') || val.startsWith('https://')) {
      return val;
    }
    if (val.startsWith('assets/') || val.startsWith('./assets/')) {
      return val;
    }
    return this.filesService.getFile(val, 100, 100);
  }

  openAddModal(): void {
    const modalRef = this.modalService.open(EditRestaurantCategoryModalComponent, {
      size: 'lg',
      centered: true,
      backdrop: 'static',
    });
    modalRef.componentInstance.item = null;
    modalRef.componentInstance.nextOrder = this.items.length + 1;

    modalRef.result.then(
      (created: RestaurantCategoryItem) => {
        if (created) {
          this.loadData();
        }
      },
      () => {}
    );
  }

  openEditModal(item: RestaurantCategoryItem): void {
    const modalRef = this.modalService.open(EditRestaurantCategoryModalComponent, {
      size: 'lg',
      centered: true,
      backdrop: 'static',
    });
    modalRef.componentInstance.item = { ...item };

    modalRef.result.then(
      (updated: RestaurantCategoryItem) => {
        if (updated) {
          this.loadData();
        }
      },
      () => {}
    );
  }

  openDeleteModal(item: RestaurantCategoryItem): void {
    const modalRef = this.modalService.open(DeleteRestaurantCategoryModalComponent, {
      centered: true,
      backdrop: 'static',
    });
    modalRef.componentInstance.item = item;

    modalRef.result.then(
      (deleted: boolean) => {
        if (deleted) {
          this.loadData();
        }
      },
      () => {}
    );
  }

  toggleSectionEnabled(): void {
    const previousState = this.enabled;
    this.enabled = !this.enabled;
    this.saveConfig(false, previousState);
  }

  toggleItemActive(item: RestaurantCategoryItem): void {
    if (this.pendingToggleIds.has(item.id)) return;

    this.pendingToggleIds.add(item.id);
    const targetState = !item.active;
    item.active = targetState;

    this.subs.sink = this.service.toggleItem(item.id, targetState).subscribe({
      next: () => {
        this.pendingToggleIds.delete(item.id);
        this.toastr.success(targetState ? 'تم تفعيل التصنيف بنجاح' : 'تم تعطيل التصنيف');
        this.cdr.detectChanges();
      },
      error: () => {
        this.pendingToggleIds.delete(item.id);
        item.active = !targetState; // revert
        this.toastr.error('تعذر تغيير حالة التصنيف');
        this.cdr.detectChanges();
      },
    });
  }

  moveUp(index: number): void {
    if (index <= 0 || index >= this.items.length) return;
    const temp = this.items[index];
    this.items[index] = this.items[index - 1];
    this.items[index - 1] = temp;
    this.normalizeAndSaveOrder();
  }

  moveDown(index: number): void {
    if (index < 0 || index >= this.items.length - 1) return;
    const temp = this.items[index];
    this.items[index] = this.items[index + 1];
    this.items[index + 1] = temp;
    this.normalizeAndSaveOrder();
  }

  private normalizeAndSaveOrder(): void {
    for (let i = 0; i < this.items.length; i++) {
      this.items[i].order = i + 1;
    }
    this.isSaving = true;
    const ids = this.items.map((x) => x.id);
    this.subs.sink = this.service.reorder(ids).subscribe({
      next: () => {
        this.isSaving = false;
        this.toastr.success('تم تحديث وحفظ ترتيب التصنيفات');
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.toastr.error('تعذر حفظ الترتيب');
        this.loadData();
      },
    });
  }

  /** Label for the category an entry points at, for the table cell. */
  categoryLabel(item: RestaurantCategoryItem): string {
    if (!item.productCategoryId) {
      return '';
    }
    const target = this.availableCategories.find((c) => c.id === item.productCategoryId);
    if (!target) {
      return `#${item.productCategoryId}`;
    }
    return target.parentTitle ? `${target.parentTitle} ← ${target.title}` : target.title;
  }

  /**
   * Why an active entry would still not reach customers. Entries with no
   * category linked are shown anyway, since their emptiness is unproven.
   */
  hiddenReason(item: RestaurantCategoryItem): string | null {
    if (!item.active) {
      return null;
    }
    if (!item.productCategoryId) {
      return 'غير مرتبط بقسم — لن يظهر عدد المتاجر';
    }
    if ((item.merchantCount ?? 0) === 0) {
      return 'لا توجد متاجر في هذا القسم — مخفي عن العملاء';
    }
    return null;
  }

  get hiddenCount(): number {
    return this.items.filter(
      (item) => item.active && !!item.productCategoryId && (item.merchantCount ?? 0) === 0
    ).length;
  }

  onCategoryLinkChange(item: RestaurantCategoryItem): void {
    const target = this.availableCategories.find((c) => c.id === item.productCategoryId);
    item.merchantCount = target ? target.merchantCount : 0;
    this.saveConfig();
  }

  saveConfig(notify: boolean = true, rollbackEnabled?: boolean): void {
    this.isSaving = true;
    const config: RestaurantCategoriesSectionConfig = {
      sectionTitle: (this.sectionTitle || 'كل المطاعم').trim(),
      sectionTitleEn: (this.sectionTitleEn || 'All Restaurants').trim(),
      homeSectionTitle: (this.homeSectionTitle || 'أصناف متنوعة').trim(),
      homeSectionTitleEn: (this.homeSectionTitleEn || 'Browse by kind').trim(),
      enabled: this.enabled,
      showOnHome: this.showOnHome,
      items: this.items.map((item, idx) => ({
        ...item,
        order: idx + 1,
      })),
    };

    this.subs.sink = this.service.saveConfig(config).subscribe({
      next: () => {
        this.isSaving = false;
        if (notify) {
          this.toastr.success('تم حفظ إعدادات قسم تصنيفات المطاعم بنجاح');
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        if (rollbackEnabled !== undefined) {
          this.enabled = rollbackEnabled;
        }
        this.toastr.error('تعذر حفظ الإعدادات');
        this.cdr.detectChanges();
      },
    });
  }
}
