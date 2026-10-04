import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { TranslateModule } from '@ngx-translate/core';
import { NgbActiveModal, NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { of, Subject, throwError } from 'rxjs';
import { PaginatorState, SortState } from 'src/app/_metronic/shared/crud-table';
import { BannersModule } from '../../banners.module';
import { HomeCategoriesModule } from '../../../home-categories/home-categories.module';
import { PopularProductsModule } from '../../../popular-products/popular-products.module';
import { MarketBestSellingModule } from '../../../market-best-selling/market-best-selling.module';
import { BannersService } from '../../services/banners.service';
import { MerchantsService } from '../../../merchant/services/merchants.service';
import { HomeCategoriesService } from '../../../home-categories/services/home-categories.service';
import { RestaurantCategoriesService } from '../../../restaurant-categories/services/restaurant-categories.service';
import { PopularProductsService } from '../../../popular-products/services/popular-products.service';
import { MarketBestSellingService } from '../../../market-best-selling/services/market-best-selling.service';
import { BannersListComponent } from './banners-list.component';
import { EditBannerModalComponent } from '../edit-banner-modal/edit-banner-modal.component';
import { DeleteBannerModalComponent } from '../delete-banner-modal/delete-banner-modal.component';
import { HomeCategoriesListComponent } from '../../../home-categories/components/home-categories-list/home-categories-list.component';
import { PopularProductsListComponent } from '../../../popular-products/components/popular-products-list/popular-products-list.component';
import { AddPopularProductModalComponent } from '../../../popular-products/components/add-popular-product-modal/add-popular-product-modal.component';
import { MarketBestSellingListComponent } from '../../../market-best-selling/components/market-best-selling-list/market-best-selling-list.component';
import { AddMarketBestSellingModalComponent } from '../../../market-best-selling/components/add-market-best-selling-modal/add-market-best-selling-modal.component';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';

describe('Customer interface table HTTP contracts', () => {
  it('banner filters reach the server and reset pagination', () => {
    TestBed.configureTestingModule({imports:[HttpClientTestingModule]});
    const service=TestBed.inject(BannersService), http=TestBed.inject(HttpTestingController);
    service.setDefaults(); service.paginator.page=5;
    service.patchState({filter:{section:'dont_miss',status:'disabled'}});
    const request=http.expectOne(r=>r.url.endsWith('/Banner/DataTable'));
    expect(request.request.params.get('section')).toBe('dont_miss'); expect(request.request.params.get('status')).toBe('disabled');
    expect(request.request.body.pageNumber).toBe(1); request.flush({items:[],totalRecords:0}); http.verify(); service.ngOnDestroy();
  });
});

describe('Customer interface actual pages and every modal', () => {
  let banners:any, merchants:any, home:any, popular:any, best:any, modal:any, toast:any;
  const store:any={id:30,title:'Other grocery',merchantKind:1,active:true};
  const items:any[]=[{productId:100,title:'One',active:true,order:1},{productId:200,title:'Two',active:true,order:2}];
  function list(name:string) {
    const service=jasmine.createSpyObj(name,['getConfig','saveConfig','reorder','toggleItem','removeItem','searchProducts','addItem']);
    service.getConfig.and.returnValue(of({items:items.map(i=>({...i})),enabled:true,mode:'Hybrid',maxItems:10}));
    for(const key of ['saveConfig','reorder','toggleItem','removeItem','addItem']) service[key].and.returnValue(new Subject());
    service.searchProducts.and.returnValue(of([])); return service;
  }
  beforeEach(async()=>{
    banners=jasmine.createSpyObj('banners',['setDefaults','fetchPost','patchState','summary','create','update','delete','setStatus','deleteMany']);
    Object.assign(banners,{items$:of([]),isLoading$:of(false),listError$:of(''),totalRecords$:of(0),paginator:new PaginatorState(),sorting:new SortState('id')});
    banners.summary.and.returnValue(of({total:12,active:6,daily:4,dontMiss:8}));
    for(const key of ['create','update','delete','setStatus','deleteMany']) banners[key].and.returnValue(new Subject());
    merchants={getAllMerchants:()=>of([store])};
    home=jasmine.createSpyObj('home',['get','save']);
    home.get.and.returnValue(of({config:{enabled:true,maxItems:8,tiles:[]},tiles:[],availableCategories:[],availableMerchants:[],availableMerchantKinds:[]}));
    home.save.and.returnValue(new Subject()); popular=list('popular');best=list('best');
    modal=jasmine.createSpyObj('modal',['close','dismiss']);toast=jasmine.createSpyObj('toast',['success','error','warning','info']);
    await TestBed.configureTestingModule({imports:[HttpClientTestingModule,RouterTestingModule,TranslateModule.forRoot(),BannersModule,HomeCategoriesModule,PopularProductsModule,MarketBestSellingModule],providers:[
      {provide:BannersService,useValue:banners},{provide:MerchantsService,useValue:merchants},{provide:HomeCategoriesService,useValue:home},
      {provide:RestaurantCategoriesService,useValue:{getConfig:()=>of({items:[]})}},
      {provide:CategoriesService,useValue:{getAll:()=>of([{id:9,title:'Food',active:true}])}},
      {provide:PopularProductsService,useValue:popular},{provide:MarketBestSellingService,useValue:best},
      {provide:NgbActiveModal,useValue:modal},{provide:ToastrService,useValue:toast}
    ]}).compileComponents();
  });
  for(const component of [BannersListComponent,HomeCategoriesListComponent,PopularProductsListComponent,MarketBestSellingListComponent,EditBannerModalComponent,DeleteBannerModalComponent,AddPopularProductModalComponent,AddMarketBestSellingModalComponent,BulkConfirmModalComponent]) {
    it(component.name+' renders its actual template',()=>{const f=TestBed.createComponent(component as any);f.detectChanges();expect(f.nativeElement.textContent.length).toBeGreaterThan(0);f.destroy();});
  }
  it('bulk banner confirmation submits once and displays a failed action without closing',()=>{
    const f=TestBed.createComponent(BulkConfirmModalComponent), pending=new Subject<unknown>();
    f.componentInstance.count=2; f.componentInstance.action=jasmine.createSpy('action').and.returnValue(pending);
    f.detectChanges(); f.componentInstance.confirm(); f.componentInstance.confirm();
    expect(f.componentInstance.action).toHaveBeenCalledTimes(1);
    pending.error('offline'); f.detectChanges();
    expect(f.componentInstance.hasError).toBeTrue(); expect(f.componentInstance.isLoading).toBeFalse();
    expect(f.nativeElement.querySelector('[role="alert"]')).not.toBeNull(); expect(modal.close).not.toHaveBeenCalled(); f.destroy();
  });
  it('banner placement ignores title/description keywords and has no fabricated merchant 12',()=>{
    const f=TestBed.createComponent(EditBannerModalComponent);f.componentInstance.item={id:'1',title:'ماركت',description:'market restaurants',bannerLocation:0,url:'market:30',featuredImage:'a',order:1,active:true} as any;
    f.detectChanges();expect(f.componentInstance.formGroup.value.sectionPlacement).toBe('daily_offers');expect(f.componentInstance.markets.map(m=>m.id)).toEqual([30]);f.destroy();
  });
  it('existing category and numeric store targets remain editable as internal destinations',()=>{
    for(const [url,target,expected] of [['category:9','category','category:9'],['30','market','market:30']]) {
      const f=TestBed.createComponent(EditBannerModalComponent);
      f.componentInstance.item={id:'1',title:'Banner',bannerLocation:0,url,featuredImage:'a',order:1,active:true} as any;
      f.detectChanges(); expect(f.componentInstance.formGroup.value.targetType).toBe(target);
      f.componentInstance.save(); expect(banners.update.calls.mostRecent().args[0].url).toBe(expected); f.destroy();
    }
  });
  it('banner editor saves clean external fragments once and displays API errors',()=>{
    const f=TestBed.createComponent(EditBannerModalComponent);f.detectChanges();
    f.componentInstance.formGroup.patchValue({title:'Banner',active:true,featuredImage:'a',targetType:'external',targetExternalUrl:'https://example.com/#sale',sectionPlacement:'market'});
    f.componentInstance.save();f.componentInstance.save();expect(banners.create).toHaveBeenCalledTimes(1);
    const payload=banners.create.calls.mostRecent().args[0];expect(payload.url).toBe('https://example.com/#sale');expect(payload.bannerLocation).toBe(3);
    banners.create.calls.mostRecent().returnValue.error({error:'server reason'});expect(toast.error).toHaveBeenCalledWith('server reason');expect(modal.close).not.toHaveBeenCalled();f.destroy();
  });
  it('invalid external target cannot save',()=>{
    const f=TestBed.createComponent(EditBannerModalComponent);f.detectChanges();f.componentInstance.formGroup.patchValue({title:'Banner',active:false,targetType:'external',targetExternalUrl:'javascript:alert(1)'});
    f.componentInstance.save();expect(banners.create).not.toHaveBeenCalled();f.destroy();
  });
  it('banner delete cannot submit twice and stays open on failure',()=>{
    const f=TestBed.createComponent(DeleteBannerModalComponent);f.detectChanges();f.componentInstance.id='1';f.componentInstance.delete();f.componentInstance.delete();expect(banners.delete).toHaveBeenCalledTimes(1);
    banners.delete.calls.mostRecent().returnValue.error({error:'not found'});expect(modal.close).not.toHaveBeenCalled();expect(toast.error).toHaveBeenCalledWith('not found');f.destroy();
  });
  it('banner KPI counts are global even when the current page is empty',()=>{
    const f=TestBed.createComponent(BannersListComponent);f.detectChanges();expect(f.componentInstance.kpiTotal).toBe(12);expect(f.componentInstance.kpiDontMiss).toBe(8);
    f.componentInstance.filterBySection('daily');f.componentInstance.filterByStatus('active');expect(banners.patchState.calls.mostRecent().args[0].filter).toEqual({section:'daily',status:'active'});f.destroy();
  });
  it('banner mutation refreshes global counts as well as the table',()=>{
    const f=TestBed.createComponent(BannersListComponent); f.detectChanges();
    banners.summary.and.returnValue(of({total:11,active:5,daily:3,dontMiss:8}));
    f.componentInstance.refresh(); expect(f.componentInstance.kpiTotal).toBe(11); expect(f.componentInstance.kpiActive).toBe(5);
    expect(banners.summary).toHaveBeenCalledTimes(2); f.destroy();
  });
  it('banner edit and delete modals cannot be dismissed during a pending write',()=>{
    const f=TestBed.createComponent(BannersListComponent); f.detectChanges();
    const ref:any={componentInstance:{},result:new Promise(()=>{})};
    const open=spyOn(TestBed.inject(NgbModal),'open').and.returnValue(ref);
    f.componentInstance.edit(null);
    let options:any=open.calls.mostRecent().args[1]; ref.componentInstance.isSaving=true;
    expect(options.beforeDismiss()).toBeFalse(); ref.componentInstance.isSaving=false; expect(options.beforeDismiss()).toBeTrue();
    f.componentInstance.delete('1'); options=open.calls.mostRecent().args[1]; ref.componentInstance.deleting=true;
    expect(options.beforeDismiss()).toBeFalse(); ref.componentInstance.deleting=false; expect(options.beforeDismiss()).toBeTrue(); f.destroy();
  });
  for(const [component,key,addComponent] of [[PopularProductsListComponent,'popular',AddPopularProductModalComponent],[MarketBestSellingListComponent,'best',AddMarketBestSellingModalComponent]] as any[]) {
    it(component.name+' rolls back failed reorder and blocks another mutation',()=>{
      const service=key==='popular'?popular:best;const f=TestBed.createComponent(component as any);f.detectChanges();const c:any=f.componentInstance;
      c.moveDown(0);c.moveUp(1);expect(service.reorder).toHaveBeenCalledTimes(1);expect(c.items[0].productId).toBe(200);
      service.reorder.calls.mostRecent().returnValue.error('offline');expect(c.items[0].productId).toBe(100);expect(c.isSaving).toBeFalse();f.destroy();
    });
    it(component.name+' restores section visibility on failed save',()=>{
      const service=key==='popular'?popular:best;const f=TestBed.createComponent(component as any);f.detectChanges();const c:any=f.componentInstance;
      c.toggleSectionEnabled();c.setMode('Auto');expect(service.saveConfig).toHaveBeenCalledTimes(1);
      service.saveConfig.calls.mostRecent().returnValue.error('offline');expect(c.enabled).toBeTrue();expect(c.mode).toBe('Hybrid');f.destroy();
    });
    it(addComponent.name+' cancels stale search, submits once and cancels on destroy',()=>{
      const service=key==='popular'?popular:best;const first=new Subject(),second=new Subject();service.searchProducts.and.returnValues(first,second);
      const f=TestBed.createComponent(addComponent as any);f.detectChanges();const c:any=f.componentInstance;c.performSearch('new');
      first.next([{id:1,title:'old'}]);second.next([{id:2,title:'new'}]);expect(c.candidates.map((i:any)=>i.id)).toEqual([2]);
      c.selectProduct({id:2,title:'new'});c.submit();c.submit();expect(service.addItem).toHaveBeenCalledTimes(1);f.destroy();
      service.addItem.calls.mostRecent().returnValue.next(true);expect(modal.close).not.toHaveBeenCalled();
    });
  }
  it('Home save snapshot keeps edits made during a pending save unsaved',()=>{
    const f=TestBed.createComponent(HomeCategoriesListComponent);f.detectChanges();const c=f.componentInstance;
    c.config.sectionTitle='submitted';c.save();c.save();expect(home.save).toHaveBeenCalledTimes(1);c.config.sectionTitle='later edit';
    home.save.calls.mostRecent().returnValue.next([]);expect(c.hasUnsavedChanges).toBeTrue();expect(home.save.calls.mostRecent().args[0].sectionTitle).toBe('submitted');f.destroy();
  });
  it('Home quick action uses authoritative market identity and never guesses another grocery',()=>{
    const f=TestBed.createComponent(HomeCategoriesListComponent);f.detectChanges();const c=f.componentInstance;
    c.merchants=[{id:30,title:'test',merchantKind:1}] as any;expect(c.jtakMarketMerchantId).toBeNull();
    c.merchants=[{id:30,title:'test',merchantKind:1,isJtakMarket:false},{id:73,title:'Market',merchantKind:1,isJtakMarket:true}] as any;
    expect(c.jtakMarketMerchantId).toBe(73);f.destroy();
  });
  it('Home merged categories count content from either target and ignore unavailable tiles in the limit',()=>{
    const f=TestBed.createComponent(HomeCategoriesListComponent);f.detectChanges();const c=f.componentInstance;
    c.categories=[{id:1,title:'Empty',productCount:0,merchantCount:0},{id:2,title:'Full',productCount:1,merchantCount:1}] as any;
    c.config.maxItems=1;c.config.tiles=[{title:'empty',linkType:0,productCategoryId:1,active:true},{title:'merged',linkType:0,productCategoryId:1,secondaryProductCategoryId:2,active:true}] as any;
    expect(c.tileAvailabilityProblem(c.config.tiles[1])).toBeNull();expect(c.visibleCount).toBe(1);expect(c.isHidden(1)).toBeFalse();f.destroy();
  });
});
