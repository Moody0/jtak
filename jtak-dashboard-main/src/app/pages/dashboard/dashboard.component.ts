import { AuthService } from 'src/app/modules/auth';
import { ChangeDetectionStrategy, ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs';
import { ISortView, IPaginatorView, ISearchView, PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { SubSink } from 'subsink';
import { Balance } from './models/balance.model';
import { Dashboard } from './models/dashboard.model';
import { DashboardService } from './services/dashboard.service';
import { DriverBalancesService } from './services/driver-balances.service';
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
isDriverLoading: boolean;
dashboardLoading = true;
lastUpdated = new Date();
totalRecords: number;
searchGroup: UntypedFormGroup;
driverSearchGroup: UntypedFormGroup;
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
    private fb: UntypedFormBuilder,
    public service: DashboardService,
    public driverBalancesService: DriverBalancesService,
    public ordersService: OrdersService,
    private categoriesService: CategoriesService,
    private translate: TranslateService,
    private cdr: ChangeDetectorRef, public auth: AuthService) { }


  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.service.patchState({ paginator });
  }

  driverPaginator: PaginatorState;
  paginateDrivers(paginator: PaginatorState) {
    this.driverBalancesService.patchState({ paginator });
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

  driverSorting: SortState;
  sortDrivers(column: string): void {
    const driverSorting = this.driverSorting;
    const isActiveColumn = driverSorting.column === column;
    if (!isActiveColumn) {
      driverSorting.column = column;
      driverSorting.direction = 'ASC';
    } else {
      driverSorting.direction = driverSorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }

    this.driverBalancesService.patchState({ sorting: driverSorting });
  }

  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));

    this.driverSearchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.driverSearchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.searchDrivers(val));
  }

  search(searchTerm: string) {
    this.service.patchState({ searchTerm });
  }

  searchDrivers(searchTerm: string) {
    this.driverBalancesService.patchState({ searchTerm });
  }
  exchangeRate: number = 15000;
  isSavingRate: boolean = false;
  private settingsSaveTimers: ReturnType<typeof setTimeout>[] = [];
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

  loadSettings() {
    this.subs.sink = this.service.getSettings().subscribe({
      next: (settings: any) => {
        if (settings && settings.usdToSypExchangeRate) {
          this.exchangeRate = settings.usdToSypExchangeRate;
        }
        this.hasSavedFeaturedCategorySelection = Array.isArray(settings?.homeFeaturedCategoryIds)
          && settings.homeFeaturedCategoryIds.length > 0;
        this.featuredCategoryIds = Array.isArray(settings?.homeFeaturedCategoryIds)
          ? settings.homeFeaturedCategoryIds.map((id: any) => Number(id)).filter((id: number) => id > 0)
          : [];
        this.rebuildFeaturedCategories();
        this.cdr.detectChanges();
      },
      error: () => {
        this.featuredCategoryIds = [];
        this.rebuildFeaturedCategories();
      }
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
    this.subs.sink = this.service.getSettings().subscribe({
      next: (settings: any) => {
        const payload = {
          ...settings,
          homeFeaturedCategoryIds: this.featuredCategories.map(category => category.id),
        };
        this.subs.sink = this.service.saveSettings(payload).subscribe({
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
    if (this.isSavingRate || !Number.isFinite(this.exchangeRate) || this.exchangeRate <= 0 || this.exchangeRate > 100000000 || Math.abs(this.exchangeRate * 1e6 - Math.round(this.exchangeRate * 1e6)) > 0.01) return;
    const requestedRate = this.exchangeRate;
    this.isSavingRate = true;
    this.rateSaveSuccess = false;
    this.rateSaveError = false;

    this.subs.sink = this.service.getSettings().subscribe({
      next: (settings: any) => {
        const payload = {
          ...settings,
          usdToSypExchangeRate: requestedRate
        };
        this.subs.sink = this.service.saveSettings(payload).subscribe({
          next: () => {
            this.isSavingRate = false;
            this.rateSaveSuccess = true;
            this.cdr.detectChanges();
            this.settingsSaveTimers.push(setTimeout(() => {
              this.rateSaveSuccess = false;
              this.cdr.detectChanges();
            }, 3000));
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

  driverPricing: any = {
    mode: 0,
    fixedAmount: 5000,
    distanceBaseFee: 2000,
    distanceRatePerUnit: 1000,
    unit: 0,
    minEarning: 3000,
    maxEarning: 0,
    isFreeDeliveryEnabled: false,
    customerRatePerKm: 45,
    minDeliveryFee: 50
  };
  driverPricingLoaded = false;
  driverPricingLoadError = false;
  isSavingDriverPricing: boolean = false;
  driverPricingSaveSuccess: boolean = false;
  driverPricingSaveError: boolean = false;
  // Must start false: loadDriverPricing() returns early while this is true,
  // which would leave the pricing fields disabled forever.
  driverPricingLoading: boolean = false;
  simulatedDistance: number = 4.5;
  errandDriverEarning = 0;
  errandDriverEarningLoading = true;
  isSavingErrandDriverEarning = false;
  errandDriverEarningSaveSuccess = false;
  errandDriverEarningSaveError = false;

  loadErrandDriverEarning() {
    this.errandDriverEarningLoading = true;
    this.subs.sink = this.service.getErrandDriverEarning().subscribe({
      next: (setting: any) => {
        this.errandDriverEarning = Number(setting?.amount ?? 0);
        this.errandDriverEarningLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.errandDriverEarningLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  saveErrandDriverEarning() {
    if (!Number.isFinite(Number(this.errandDriverEarning)) || Number(this.errandDriverEarning) <= 0) {
      this.errandDriverEarningSaveError = true;
      return;
    }
    this.isSavingErrandDriverEarning = true;
    this.errandDriverEarningSaveSuccess = false;
    this.errandDriverEarningSaveError = false;
    this.subs.sink = this.service.saveErrandDriverEarning({ amount: Number(this.errandDriverEarning) }).subscribe({
      next: () => {
        this.isSavingErrandDriverEarning = false;
        this.errandDriverEarningSaveSuccess = true;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSavingErrandDriverEarning = false;
        this.errandDriverEarningSaveError = true;
        this.cdr.detectChanges();
      }
    });
  }

  loadDriverPricing() {
    if (this.driverPricingLoading || this.isSavingDriverPricing) return;
    this.driverPricingLoaded = false;
    this.driverPricingLoadError = false;
    this.driverPricingLoading = true;
    this.subs.sink = this.service.getDriverPricing().subscribe({
      next: (pricing: any) => {
        this.driverPricingLoaded = !!pricing;
        this.driverPricingLoadError = !pricing;
        if (pricing) {
          this.driverPricing = {
            mode: pricing.mode ?? 0,
            fixedAmount: pricing.fixedAmount ?? 5000,
            distanceBaseFee: pricing.distanceBaseFee ?? 2000,
            distanceRatePerUnit: pricing.distanceRatePerUnit ?? 1000,
            unit: pricing.unit ?? 0,
            minEarning: pricing.minEarning ?? 3000,
            maxEarning: pricing.maxEarning ?? 0,
            isFreeDeliveryEnabled: !!pricing.isFreeDeliveryEnabled,
            customerRatePerKm: pricing.customerRatePerKm ?? 45,
            minDeliveryFee: pricing.minDeliveryFee ?? 50
          };
        }
        this.driverPricingLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.driverPricingLoadError = true;
        this.driverPricingLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  saveDriverPricing() {
    if (this.isSavingDriverPricing || this.driverPricingLoading || !this.driverPricingLoaded) return;
    this.isSavingDriverPricing = true;
    this.driverPricingSaveSuccess = false;
    this.driverPricingSaveError = false;

    const payload = {
      mode: Number(this.driverPricing.mode),
      fixedAmount: Number(this.driverPricing.fixedAmount || 0),
      distanceBaseFee: Number(this.driverPricing.distanceBaseFee || 0),
      distanceRatePerUnit: Number(this.driverPricing.distanceRatePerUnit || 0),
      unit: Number(this.driverPricing.unit || 0),
      minEarning: Number(this.driverPricing.minEarning || 0),
      maxEarning: Number(this.driverPricing.maxEarning || 0),
      isFreeDeliveryEnabled: !!this.driverPricing.isFreeDeliveryEnabled,
      customerRatePerKm: Number(this.driverPricing.customerRatePerKm ?? 45),
      minDeliveryFee: Number(this.driverPricing.minDeliveryFee ?? 50)
    };

    this.subs.sink = this.service.saveDriverPricing(payload).subscribe({
      next: () => {
        this.isSavingDriverPricing = false;
        this.driverPricingSaveSuccess = true;
        this.cdr.detectChanges();
        this.settingsSaveTimers.push(setTimeout(() => {
          this.driverPricingSaveSuccess = false;
          this.cdr.detectChanges();
        }, 3500));
      },
      error: () => {
        this.isSavingDriverPricing = false;
        this.driverPricingSaveError = true;
        this.cdr.detectChanges();
      }
    });
  }

  get simulatedDriverPayout(): number {
    if (!this.driverPricing) return 0;
    if (Number(this.driverPricing.mode) === 0) {
      return Number(this.driverPricing.fixedAmount || 0);
    }
    const dist = Math.max(0, Number(this.simulatedDistance || 0));
    const base = Number(this.driverPricing.distanceBaseFee || 0);
    const rate = Number(this.driverPricing.distanceRatePerUnit || 0);
    let total = base + (dist * rate);
    const min = Number(this.driverPricing.minEarning || 0);
    const max = Number(this.driverPricing.maxEarning || 0);
    if (min > 0) total = Math.max(min, total);
    if (max > 0) total = Math.min(max, total);
    return Math.round(total);
  }

  get simulatedCustomerDeliveryFee(): number {
    if (!this.driverPricing) return 0;
    if (this.driverPricing.isFreeDeliveryEnabled) return 0;
    return this.simulatedOriginalDeliveryFee;
  }

  get simulatedOriginalDeliveryFee(): number {
    if (!this.driverPricing) return 0;
    const dist = Math.max(0, Number(this.simulatedDistance || 0));
    const rate = Number(this.driverPricing.customerRatePerKm ?? 45);
    const minFee = Number(this.driverPricing.minDeliveryFee ?? 50);
    const calculated = dist * rate;
    return Math.max(minFee, Math.round(calculated));
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
    if (this.auth.can('finance.view')) {
      this.service.fetchPost();
      this.driverBalancesService.fetchPost();
    }
    if (this.auth.can('orders.view')) this.ordersService.fetchPost();
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
    this.service.setDefaults();
    this.driverBalancesService.setDefaults();
    this.ordersService.setDefaults();
    this.searchForm();
    if (this.auth.can('settings.view')) {
      this.loadSettings();
      if (this.auth.can('catalog.view')) this.loadFeaturedCategories();
      this.loadDriverPricing();
      this.loadErrandDriverEarning();
    }
    this.refreshDashboard();
    this.subs.sink = this.service.isLoading$.subscribe(res => this.isLoading = res);
    this.subs.sink = this.driverBalancesService.isLoading$.subscribe(res => this.isDriverLoading = res);
    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
    this.driverPaginator = this.driverBalancesService.paginator;
    this.driverSorting = this.driverBalancesService.sorting;
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
    this.settingsSaveTimers.forEach(timer => clearTimeout(timer));
  }
}
