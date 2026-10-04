import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { HttpClient } from '@angular/common/http';
import { RouterTestingModule } from '@angular/router/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { of, Subject, throwError } from 'rxjs';
import { ProductsModule } from '../../products.module';
import { MerchantsModule } from '../../../merchant/merchants.module';
import { CategoriesModule } from '../../../categories/categories.module';
import { RestaurantCategoriesModule } from '../../../restaurant-categories/restaurant-categories.module';
import { ProductsService } from '../../services/products.service';
import { MerchantsService } from '../../../merchant/services/merchants.service';
import { ProductMerchantsService } from '../../../merchant/services/product-merchants.service';
import { CategoriesService } from '../../../categories/services/categories.service';
import { RestaurantCategoriesService } from '../../../restaurant-categories/services/restaurant-categories.service';
import { InventoryBatchService } from '../../../inventory-batches/services/inventory-batch.service';
import { DashboardService } from '../../../dashboard/services/dashboard.service';
import { UsersService } from '../../../users/services/users.service';
import { PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { ProductsListComponent } from './products-list.component';
import { EditProductModalComponent } from '../edit-product-modal/edit-product-modal.component';
import { DeleteProductModalComponent } from '../delete-product-modal/delete-product-modal.component';
import { MerchantsListComponent } from '../../../merchant/components/merchants-list/merchants-list.component';
import { MerchantWorkspaceComponent } from '../../../merchant/components/merchant-workspace/merchant-workspace.component';
import { EditMerchantModalComponent } from '../../../merchant/components/edit-merchant-modal/edit-merchant-modal.component';
import { DeleteMerchantModalComponent } from '../../../merchant/components/delete-merchant-modal/delete-merchant-modal.component';
import { SetProductModalComponent } from '../../../merchant/components/set-product-modal/set-product-modal.component';
import { CategoriesListComponent } from '../../../categories/components/categories-list/categories-list.component';
import { EditCategoryModalComponent } from '../../../categories/components/edit-category-modal/edit-category-modal.component';
import { DeleteCategoryModalComponent } from '../../../categories/components/delete-category-modal/delete-category-modal.component';
import { RestaurantCategoriesListComponent } from '../../../restaurant-categories/components/restaurant-categories-list/restaurant-categories-list.component';
import { EditRestaurantCategoryModalComponent } from '../../../restaurant-categories/components/edit-restaurant-category-modal/edit-restaurant-category-modal.component';
import { DeleteRestaurantCategoryModalComponent } from '../../../restaurant-categories/components/delete-restaurant-category-modal/delete-restaurant-category-modal.component';

describe('Catalog table HTTP contracts', () => {
  let http: HttpTestingController; let merchants: MerchantsService;
  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule] });
    http = TestBed.inject(HttpTestingController); merchants = TestBed.inject(MerchantsService);
  });
  afterEach(() => http.verify());
  it('empty filtered merchant table stays empty without fetching every merchant', () => {
    merchants.patchState({ filter: { kind: 1, active: false } });
    const req = http.expectOne(r => r.url.endsWith('/Admin/Merchants/DataTable'));
    expect(req.request.params.get('kind')).toBe('1'); expect(req.request.params.get('active')).toBe('false');
    req.flush({ items: [], totalRecords: 0 });
    merchants.items$.subscribe(items => expect(items).toEqual([]));
    http.expectNone(r => r.url.endsWith('/Admin/Merchants'));
  });
  it('new merchant query cancels the older one and exposes server failure', () => {
    merchants.fetchPost(); const old = http.expectOne(r => r.url.endsWith('/DataTable'));
    merchants.patchState({ searchTerm: 'new' }); expect(old.cancelled).toBeTrue();
    http.expectOne(r => r.url.endsWith('/DataTable')).flush('offline', { status: 503, statusText: 'Offline' });
    merchants.listError$.subscribe(error => expect(error).toContain('تعذر')); http.expectNone(r => r.url.endsWith('/Admin/Merchants'));
  });
  it('category parent/status/level are sent to the API together', () => {
    const c = TestBed.inject(CategoriesService); c.setCategoryLevel('sub');
    c.patchState({ filter: { parentId: 4, active: false } });
    const req = http.expectOne(r => r.url.endsWith('/ProductCategories/DataTable'));
    expect(req.request.params.get('level')).toBe('sub'); expect(req.request.params.get('parentId')).toBe('4');
    expect(req.request.body.pageNumber).toBe(1); req.flush({ items: [], totalRecords: 0 });
  });
});

describe('Products/stores actual pages and every catalog modal', () => {
  let products: any; let merchants: any; let categories: any; let assignments: any; let restaurant: any;
  let routeIds: Subject<any>; let modal: any; let toast: any;
  const root: any = { id: 1, title: 'Root', active: true, parentId: null, order: 1 };
  const sub: any = { id: 2, title: 'Child', active: true, parentId: 1, order: 2 };
  const owner = '11111111-1111-1111-1111-111111111111';
  const store: any = { id: 30, title: 'Independent grocery', merchantKind: 1, ownerId: owner,
    owner: 'Owner', active: true, phone1: '0987654321', shortDescription: 'Grocery', profitOutOfMerchantPricePercent: 10 };
  function table(name: string, methods: string[]) {
    const value = jasmine.createSpyObj(name, ['setDefaults', 'fetchPost', 'patchState', 'create', 'update', 'delete', ...methods]);
    Object.assign(value, { items$: of([]), totalRecords$: of(0), listError$: of(''), isLoading$: of(false),
      paginator: new PaginatorState(), sorting: new SortState('id') });
    value.create.and.returnValue(new Subject()); value.update.and.returnValue(new Subject()); value.delete.and.returnValue(new Subject());
    return value;
  }
  beforeEach(async () => {
    products = table('products', ['deleteSelected']); products.deleteSelected.and.returnValue(new Subject());
    merchants = table('merchants', ['getAllMerchants', 'getSummary', 'getWorkspaceMerchant', 'rememberWorkspaceMerchant', 'getItem']);
    merchants.getAllMerchants.and.returnValue(of([store])); merchants.getSummary.and.returnValue(of({ total: 1, active: 1, grocery: 1, restaurants: 0 }));
    merchants.getItem.and.returnValue(of(store)); merchants.getWorkspaceMerchant.and.returnValue(null);
    categories = table('categories', ['getAll', 'setCategoryLevel']); categories.getAll.and.callFake((isRoot: boolean) => of(isRoot ? [root] : [sub]));
    assignments = jasmine.createSpyObj('assignments', ['getProducts', 'saveProducts']);
    Object.assign(assignments, { isLoading$: of(false) }); assignments.getProducts.and.returnValue(of([])); assignments.saveProducts.and.returnValue(new Subject());
    restaurant = jasmine.createSpyObj('restaurant', ['getConfig', 'updateItem', 'addItem', 'deleteItem', 'reorder', 'saveConfig']);
    restaurant.getConfig.and.returnValue(of({ items: [], availableCategories: [], enabled: true, showOnHome: true }));
    restaurant.updateItem.and.returnValue(new Subject()); restaurant.addItem.and.returnValue(new Subject()); restaurant.deleteItem.and.returnValue(new Subject());
    routeIds = new Subject(); modal = jasmine.createSpyObj('modal', ['close', 'dismiss']); toast = jasmine.createSpyObj('toast', ['success', 'error', 'warning', 'info']);
    await TestBed.configureTestingModule({ imports: [HttpClientTestingModule, RouterTestingModule, TranslateModule.forRoot(),
      ProductsModule, MerchantsModule, CategoriesModule, RestaurantCategoriesModule], providers: [
      { provide: ProductsService, useValue: products }, { provide: MerchantsService, useValue: merchants },
      { provide: CategoriesService, useValue: categories }, { provide: ProductMerchantsService, useValue: assignments },
      { provide: RestaurantCategoriesService, useValue: restaurant }, { provide: DashboardService, useValue: { getSettings: () => of({ usdToSypExchangeRate: 100 }) } },
      { provide: InventoryBatchService, useValue: { lookupMerchants: () => of([store]) } },
      { provide: UsersService, useValue: { getMerchantUsers: () => of([{ id: owner, fullName: 'Owner', isActive: true }]) } },
      { provide: ActivatedRoute, useValue: { paramMap: routeIds, queryParamMap: of(convertToParamMap({})), snapshot: { queryParamMap: convertToParamMap({}) } } },
      { provide: NgbActiveModal, useValue: modal }, { provide: ToastrService, useValue: toast }
    ] }).compileComponents();
  });
  for (const component of [ProductsListComponent, MerchantsListComponent, CategoriesListComponent, RestaurantCategoriesListComponent]) {
    it(`${component.name} renders its actual empty template`, () => {
      const f = TestBed.createComponent(component as any); f.detectChanges(); expect(f.nativeElement.textContent.length).toBeGreaterThan(0); f.destroy();
    });
  }
  it('product filter starts on the first page and preserves both status and category', () => {
    const f = TestBed.createComponent(ProductsListComponent); f.detectChanges();
    f.componentInstance.selectedCategoryId = 2; f.componentInstance.filterByStatus('disabled');
    const patch = products.patchState.calls.mostRecent().args[0]; expect(patch.paginator.page).toBe(0);
    expect(patch.filter).toEqual({ categoryId: 2, active: false }); f.destroy();
  });
  it('category editor blocks duplicate saving and reports the API reason while staying open', () => {
    const f = TestBed.createComponent(EditCategoryModalComponent); f.detectChanges();
    f.componentInstance.formGroup.patchValue({ title: 'New' }); f.componentInstance.save(); f.componentInstance.save();
    expect(categories.create).toHaveBeenCalledTimes(1);
    categories.create.calls.mostRecent().returnValue.error({ error: { errors: ['سبب واضح'] } });
    expect(toast.error).toHaveBeenCalledWith('سبب واضح'); expect(modal.dismiss).not.toHaveBeenCalled(); f.destroy();
  });
  it('publication badge follows server visibility for disabled stores or category ancestors', () => {
    const f = TestBed.createComponent(ProductsListComponent); f.detectChanges();
    const badge = f.componentInstance.getPublicationInfo({ id: 100, title: 'Product', active: true, merchantId: 30, price: 500, isPublishedToCustomer: false } as any);
    expect(badge.status).toBe('assigned_inactive'); expect(badge.label).toContain('المتجر أو التصنيف'); f.destroy();
  });
  it('product editor includes independent groceries and prevents duplicate writes', () => {
    const f = TestBed.createComponent(EditProductModalComponent); f.detectChanges();
    expect(f.componentInstance.merchantOptions.some(x => x.id === 30)).toBeTrue();
    f.componentInstance.formGroup.patchValue({ title: 'Product', merchantId: 30, productCategoryId: 2, priceUsd: 5 });
    f.componentInstance.save(); f.componentInstance.save(); expect(products.create).toHaveBeenCalledTimes(1); f.destroy();
  });
  it('merchant editor renders without Google and guards phone checks/save', () => {
    const f = TestBed.createComponent(EditMerchantModalComponent); f.componentInstance.item = store; f.detectChanges();
    expect(f.nativeElement.querySelector('input[formControlName="lat"]')).not.toBeNull();
    f.componentInstance.save(); f.componentInstance.save(); expect(merchants.update).toHaveBeenCalledTimes(1); f.destroy();
  });
  for (const [component, serviceName] of [[DeleteProductModalComponent, 'products'], [DeleteCategoryModalComponent, 'categories'], [DeleteMerchantModalComponent, 'merchants']] as const) {
    it(`${component.name} keeps the modal open after a failed delete and allows retry`, () => {
      const service = serviceName === 'products' ? products : serviceName === 'categories' ? categories : merchants;
      service.delete.and.returnValue(throwError(() => ({ error: { errors: ['رفض الحذف'] } })));
      const f = TestBed.createComponent(component as any); (f.componentInstance as any).id = 1; f.detectChanges();
      (f.componentInstance as any).delete(); expect(modal.dismiss).not.toHaveBeenCalled();
      expect(toast.error).toHaveBeenCalledWith('رفض الحذف'); (f.componentInstance as any).delete(); expect(service.delete).toHaveBeenCalledTimes(2); f.destroy();
    });
  }
  it('restaurant category editor keeps the catalog link in its form and save request', () => {
    const f = TestBed.createComponent(EditRestaurantCategoryModalComponent);
    f.componentInstance.item = { id: 1, title: 'Meals', filterTag: 'Meals', image: '', active: true, order: 1, productCategoryId: 2 };
    f.componentInstance.availableCategories = [{ id: 2, title: 'Child', merchantCount: 1 }]; f.detectChanges();
    f.componentInstance.save(); f.componentInstance.save(); expect(restaurant.updateItem).toHaveBeenCalledTimes(1);
    expect(restaurant.updateItem.calls.mostRecent().args[0].productCategoryId).toBe(2); f.destroy();
  });
  it('restaurant category delete modal prevents a second submit', () => {
    const f = TestBed.createComponent(DeleteRestaurantCategoryModalComponent); f.componentInstance.item = { id: 1, title: 'Meals', filterTag: '', image: '', order: 1, active: true }; f.detectChanges();
    f.componentInstance.confirm(); f.componentInstance.confirm(); expect(restaurant.deleteItem).toHaveBeenCalledTimes(1); f.destroy();
  });
  it('legacy product assignment renders empty and cannot save before loading', () => {
    const pending = new Subject(); assignments.getProducts.and.returnValue(pending);
    const f = TestBed.createComponent(SetProductModalComponent); f.componentInstance.mid = 30; f.detectChanges();
    f.componentInstance.save(); expect(assignments.saveProducts).not.toHaveBeenCalled();
    pending.next([]); f.componentInstance.save(); f.componentInstance.save(); expect(assignments.saveProducts).toHaveBeenCalledTimes(1); f.destroy();
  });
  it('merchant workspace loads real merchant details and cancels the previous store request', () => {
    const old = new Subject(); assignments.getProducts.and.returnValues(old, of([]));
    const f = TestBed.createComponent(MerchantWorkspaceComponent); f.detectChanges();
    routeIds.next(convertToParamMap({ id: '12' })); routeIds.next(convertToParamMap({ id: '30' }));
    old.next([{ productId: 100, product: 'Old store', merchantId: 12 }]); f.detectChanges();
    expect(f.componentInstance.merchant?.title).toBe(store.title); expect(f.componentInstance.products).toEqual([]);
    expect(merchants.getItem).toHaveBeenCalledWith(30); f.destroy();
  });
  it('editing a product does not mark unsaved catalog assignments as already saved', () => {
    assignments.getProducts.and.returnValue(of([{ productId: 100, product: 'Product', merchantId: 30 }]));
    const f = TestBed.createComponent(MerchantWorkspaceComponent); f.detectChanges(); routeIds.next(convertToParamMap({ id: '30' }));
    f.componentInstance.products[0].isSelected = false;
    (f.componentInstance as any).reloadCatalogPreservingAssignments();
    expect(f.componentInstance.hasChanges).toBeTrue(); f.destroy();
  });
});
