import { ChangeDetectionStrategy, ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs';
import { ISortView, IPaginatorView, ISearchView, PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { SubSink } from 'subsink';
import { Balance } from './models/balance.model';
import { Dashboard } from './models/dashboard.model';
import { DashboardService } from './services/dashboard.service';
import { Category } from '../categories/models/Category.model';
import { CategoriesService } from '../categories/services/categories.service';
import { OrdersService } from '../orders/services/orders.service';
import { Order } from '../orders/models/orders.model';
import { OrderDetailStatus } from '../orders/models/order-status.enum';
import { TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
  changeDetection: ChangeDetectionStrategy.Default,
})
export class DashboardComponent implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView {
private subs = new SubSink();
isLoading: boolean;
dashboardLoading = true;
lastUpdated = new Date();
totalRecords: number;
searchGroup: FormGroup;
  public data: Dashboard = {
    billsCount: 0,
    jTakAdditionalOrdersValue: 0,
    jTakOrdersValue: 0,
    merchantOrdersValue: 0,
    ordersCount: 0,
    productsCount: 0,
    totalOrdersValue: 0,
    usersCount: 0,
    topProducts: []
  };
  public balances: Balance[] = [];

  constructor(
    private fb: FormBuilder,
    public service: DashboardService,
    public ordersService: OrdersService,
    private categoriesService: CategoriesService,
    private translate: TranslateService,
    private cdr: ChangeDetectorRef) { }


  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.service.patchState({ paginator });
  }

  sorting: SortState;
  sort(column: string): void {
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

  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string) {
    this.service.patchState({ searchTerm });
  }
  exchangeRate: number = 15000;
  isSavingRate: boolean = false;
  rateSaveSuccess: boolean = false;
  rateSaveError: boolean = false;
  featuredCategories: Category[] = [];
  catalogCategories: Category[] = [];
  featuredCategoryToAdd: number | null = null;
  featuredCategoriesLoading = true;
  isSavingFeaturedCategories = false;
  featuredCategoriesSaveSuccess = false;
  featuredCategoriesSaveError = false;
  private featuredCategoryIds: number[] = [];
  private hasSavedFeaturedCategorySelection = false;

  loadExchangeRate() {
    this.service.getSettings().subscribe({
      next: (settings: any) => {
        if (settings && settings.usdToSypExchangeRate) {
          this.exchangeRate = settings.usdToSypExchangeRate;
          this.cdr.detectChanges();
        }
      },
      error: () => {}
    });
  }

  loadFeaturedCategories() {
    this.featuredCategoriesLoading = true;
    this.subs.sink = this.categoriesService.getAll(true, true).subscribe({
      next: (categories) => {
        this.catalogCategories = (categories || []).filter(category => category.active);
        this.rebuildFeaturedCategories();
      },
      error: () => {
        this.catalogCategories = [];
        this.featuredCategoriesLoading = false;
        this.cdr.detectChanges();
      }
    });
    this.subs.sink = this.service.getSettings().subscribe({
      next: (settings: any) => {
        this.hasSavedFeaturedCategorySelection = Array.isArray(settings?.homeFeaturedCategoryIds)
          && settings.homeFeaturedCategoryIds.length > 0;
        this.featuredCategoryIds = Array.isArray(settings?.homeFeaturedCategoryIds)
          ? settings.homeFeaturedCategoryIds.map((id: any) => Number(id)).filter((id: number) => id > 0)
          : [];
        this.rebuildFeaturedCategories();
      },
      error: () => {
        this.featuredCategoryIds = [];
        this.rebuildFeaturedCategories();
      }
    });
  }

  private rebuildFeaturedCategories() {
    if (!this.catalogCategories.length && this.featuredCategoriesLoading) return;
    // The customer API preserves the legacy behaviour of showing every active
    // root category until an admin saves a curated list. Reflect that same
    // state in the editor so the dashboard never suggests Home is empty when
    // the app is actually showing categories.
    if (!this.hasSavedFeaturedCategorySelection && !this.featuredCategoryIds.length) {
      this.featuredCategoryIds = this.catalogCategories.map(category => category.id).slice(0, 8);
    }
    const categoryById = new Map(this.catalogCategories.map(category => [category.id, category]));
    this.featuredCategories = this.featuredCategoryIds
      .map(id => categoryById.get(id))
      .filter((category): category is Category => !!category);
    this.featuredCategoriesLoading = false;
    this.cdr.detectChanges();
  }

  get availableFeaturedCategories(): Category[] {
    const featuredIds = new Set(this.featuredCategories.map(category => category.id));
    return this.catalogCategories.filter(category => !featuredIds.has(category.id));
  }

  addFeaturedCategory() {
    if (!this.featuredCategoryToAdd || this.featuredCategories.length >= 8) return;
    const category = this.catalogCategories.find(item => item.id === this.featuredCategoryToAdd);
    if (category && !this.featuredCategories.some(item => item.id === category.id)) {
      this.featuredCategories = [...this.featuredCategories, category];
    }
    this.featuredCategoryToAdd = null;
  }

  removeFeaturedCategory(category: Category) {
    this.featuredCategories = this.featuredCategories.filter(item => item.id !== category.id);
  }

  moveFeaturedCategory(index: number, direction: -1 | 1) {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= this.featuredCategories.length) return;
    const items = [...this.featuredCategories];
    const current = items[index];
    items[index] = items[targetIndex];
    items[targetIndex] = current;
    this.featuredCategories = items;
  }

  saveFeaturedCategories() {
    this.isSavingFeaturedCategories = true;
    this.featuredCategoriesSaveSuccess = false;
    this.featuredCategoriesSaveError = false;
    this.service.getSettings().subscribe({
      next: (settings: any) => {
        const payload = {
          ...settings,
          homeFeaturedCategoryIds: this.featuredCategories.map(category => category.id),
        };
        this.service.saveSettings(payload).subscribe({
          next: () => {
            this.featuredCategoryIds = this.featuredCategories.map(category => category.id);
            this.isSavingFeaturedCategories = false;
            this.featuredCategoriesSaveSuccess = true;
            this.cdr.detectChanges();
          },
          error: () => {
            this.isSavingFeaturedCategories = false;
            this.featuredCategoriesSaveError = true;
            this.cdr.detectChanges();
          }
        });
      },
      error: () => {
        this.isSavingFeaturedCategories = false;
        this.featuredCategoriesSaveError = true;
        this.cdr.detectChanges();
      }
    });
  }

  saveExchangeRate() {
    if (!this.exchangeRate || this.exchangeRate <= 0) return;
    this.isSavingRate = true;
    this.rateSaveSuccess = false;
    this.rateSaveError = false;

    this.service.getSettings().subscribe({
      next: (settings: any) => {
        const payload = {
          ...settings,
          usdToSypExchangeRate: this.exchangeRate
        };
        this.service.saveSettings(payload).subscribe({
          next: () => {
            this.isSavingRate = false;
            this.rateSaveSuccess = true;
            this.cdr.detectChanges();
            setTimeout(() => {
              this.rateSaveSuccess = false;
              this.cdr.detectChanges();
            }, 3000);
          },
          error: () => {
            this.isSavingRate = false;
            this.rateSaveError = true;
            this.cdr.detectChanges();
          }
        });
      },
      error: () => {
        this.isSavingRate = false;
        this.rateSaveError = true;
        this.cdr.detectChanges();
      }
    });
  }

  refreshDashboard(): void {
    this.dashboardLoading = true;
    this.service.getDashboard().subscribe({
      next: (data) => {
        this.data = data;
        this.dashboardLoading = false;
        this.lastUpdated = new Date();
        this.cdr.detectChanges();
      },
      error: () => {
        this.dashboardLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  getTopProductShare(count: number): number {
    const max = Math.max(...(this.data.topProducts || []).map(item => item.count), 1);
    return Math.max(8, Math.round((count / max) * 100));
  }

  trackByProductId(_index: number, item: { productId: number }): number {
    return item.productId;
  }

  getJTakSharePercent(): number {
    const total = this.data.totalOrdersValue || 0;
    if (total <= 0) return 0;
    return Math.min(100, Math.round(((this.data.jTakOrdersValue || 0) / total) * 100));
  }

  getMerchantSharePercent(): number {
    const total = this.data.totalOrdersValue || 0;
    if (total <= 0) return 0;
    return Math.min(100, Math.round(((this.data.merchantOrdersValue || 0) / total) * 100));
  }

  getOrderStatus(order: Order): { label: string; badgeClass: string; icon: string } {
    const isAr = (this.translate.currentLang || localStorage.getItem('language') || 'ar') === 'ar';
    if (!order || !order.orderDetails || order.orderDetails.length === 0) {
      return { label: isAr ? 'طلب جديد' : 'New Order', badgeClass: 'badge-light-warning text-warning', icon: 'fa-clock' };
    }

    const items = order.orderDetails;
    const allTerminal = items.every(d =>
      d.orderDetailStatus === OrderDetailStatus.CustomerCanceled ||
      d.orderDetailStatus === OrderDetailStatus.DeliveryCanceled ||
      d.orderDetailStatus === OrderDetailStatus.MerchantRejected);

    if (allTerminal) {
      if (items.some(d => d.orderDetailStatus === OrderDetailStatus.MerchantRejected)) {
        return { label: isAr ? 'مرفوض من التاجر' : 'Rejected by Merchant', badgeClass: 'badge-light-danger text-danger', icon: 'fa-ban' };
      }
      return { label: isAr ? 'ملغي' : 'Canceled', badgeClass: 'badge-light-danger text-danger', icon: 'fa-ban' };
    }

    const active = items.filter(d =>
      d.orderDetailStatus !== OrderDetailStatus.CustomerCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.DeliveryCanceled &&
      d.orderDetailStatus !== OrderDetailStatus.MerchantRejected);

    if (active.length > 0 && active.every(d => d.orderDetailStatus === OrderDetailStatus.Delivered)) {
      return { label: isAr ? 'تم التوصيل' : 'Delivered', badgeClass: 'badge-light-success text-success', icon: 'fa-check-double' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.ShippingStarted)) {
      return { label: isAr ? 'جاري التوصيل' : 'In Transit', badgeClass: 'badge-light-info text-info', icon: 'fa-motorcycle' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.ReadyForPickup)) {
      return { label: isAr ? 'جاهز للتوصيل' : 'Ready', badgeClass: 'badge-light-primary text-primary', icon: 'fa-box-open' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.MerchantAccepted)) {
      return { label: isAr ? 'مقبول من التاجر' : 'Accepted', badgeClass: 'badge-light-primary text-primary', icon: 'fa-box-open' };
    }
    if (active.some(d => d.orderDetailStatus === OrderDetailStatus.Pending || d.orderDetailStatus === OrderDetailStatus.CustomerPending)) {
      return { label: isAr ? 'قيد الانتظار' : 'Pending', badgeClass: 'badge-light-warning text-warning', icon: 'fa-hourglass-half' };
    }
    return { label: isAr ? 'قيد المعالجة' : 'Processing', badgeClass: 'badge-light-primary text-primary', icon: 'fa-spinner' };
  }

  ngOnInit(): void {
    this.refreshDashboard();
    this.service.setDefaults();
    this.searchForm();
    this.loadExchangeRate();
    this.loadFeaturedCategories();
    this.service.fetchPost();
    this.ordersService.fetchPost();
    this.subs.sink = this.service.isLoading$.subscribe(res => this.isLoading = res);
    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
