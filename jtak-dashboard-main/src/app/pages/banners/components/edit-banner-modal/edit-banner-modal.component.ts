import { ChangeDetectorRef, Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Banner } from '../../models/banner.model';
import { BannersService } from '../../services/banners.service';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { Merchant } from 'src/app/pages/merchant/models/merchant.model';

const EMPTY_BANNER: Banner = {
  id: '',
  title: '',
  description: '',
  order: 0,
  url: '',
  active: false,
  featuredImage: '',
  createdDate: '',
  bannerLocation: 0,
};

@Component({
  selector: 'app-edit-banner-modal',
  templateUrl: './edit-banner-modal.component.html',
  styleUrls: ['./edit-banner-modal.component.scss'],
})
export class EditBannerModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Banner;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;

  merchants: Merchant[] = [];
  restaurants: Merchant[] = [];
  markets: Merchant[] = [];
  loadingMerchants = false;

  merchantSearchFn = (term: string, item: Merchant) => {
    if (!term) return true;
    term = term.trim().toLowerCase();
    const title = (item.title || '').toLowerCase();
    const desc = (item.shortDescription || item.description || '').toLowerCase();
    const id = String(item.id || '');
    return (
      title.includes(term) ||
      desc.includes(term) ||
      id === term ||
      `#${id}` === term ||
      id.includes(term)
    );
  };

  constructor(
    private bannersService: BannersService,
    private merchantsService: MerchantsService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.bannersService.isLoading$;
    this.loadItem();
    this.loadForm();
    this.loadMerchants();
  }

  loadItem(): void {
    if (!this.item) {
      this.item = EMPTY_BANNER;
    }
  }

  loadMerchants(): void {
    this.loadingMerchants = true;
    this.subs.sink = this.merchantsService.getAllMerchants().subscribe({
      next: (items) => {
        this.merchants = items || [];
        this.restaurants = this.merchants.filter((m) => !this.isMarket(m));
        this.markets = this.merchants.filter((m) => this.isMarket(m));
        this.loadingMerchants = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.loadingMerchants = false;
        this.cdr.detectChanges();
      },
    });
  }

  isMarket(merchant: Merchant): boolean {
    if (!merchant) return false;
    const kind = merchant.merchantKind != null ? Number(merchant.merchantKind) : null;
    if (kind !== null && !isNaN(kind)) {
      return kind > 0;
    }
    const title = (merchant.title || '').toLowerCase();
    const desc = (merchant.shortDescription || merchant.description || '').toLowerCase();

    const descHasMarket =
      desc.includes('سوبرماركت') ||
      desc.includes('سوبر ماركت') ||
      desc.includes('ماركت') ||
      desc.includes('market') ||
      desc.includes('mart') ||
      desc.includes('بقالة') ||
      desc.includes('أسواق') ||
      desc.includes('تموينات') ||
      desc.includes('هايبر') ||
      desc.includes('صيدلية') ||
      desc.includes('متجر');

    const descHasRestaurant =
      desc.includes('مطعم') ||
      desc.includes('وجبات') ||
      desc.includes('مأكولات') ||
      desc.includes('كافيه') ||
      desc.includes('سناك') ||
      desc.includes('شاورما') ||
      desc.includes('برغر') ||
      desc.includes('بيتزا') ||
      desc.includes('مشاوي') ||
      desc.includes('حلويات') ||
      desc.includes('معجنات');

    if (descHasMarket && !descHasRestaurant) return true;
    if (descHasRestaurant && !descHasMarket) return false;

    return (
      title.includes('ماركت') ||
      title.includes('سوبرماركت') ||
      title.includes('سوبر ماركت') ||
      title.includes('بقالة') ||
      title.includes('أسواق') ||
      title.includes('market') ||
      title.includes('mart') ||
      title.includes('تموينات') ||
      title.includes('صيدلية')
    );
  }

  getMerchantName(id: any): string {
    if (!id) return '';
    const numId = Number(id);
    const m = this.merchants.find((x) => Number(x.id) === numId);
    return m ? m.title : '';
  }

  loadForm(): void {
    let placement = 'daily_offers';
    const rawUrl = this.item?.url || '';
    const rawDesc = this.item?.description || '';
    const loc = this.item?.bannerLocation;

    if (loc === 2 || rawUrl.includes('section:restaurant') || rawDesc.includes('restaurants') || rawDesc.includes('مطاعم')) {
      placement = 'restaurants';
    } else if (loc === 3 || rawUrl.includes('section:market') || rawDesc.includes('market') || rawDesc.includes('ماركت')) {
      placement = 'market';
    } else if (loc === 4 || rawUrl.includes('section:all')) {
      placement = 'all';
    } else if (loc === 1 || rawUrl.includes('section:dontmiss') || rawDesc.includes('dontmiss') || rawDesc.includes('لا تفوتها')) {
      placement = 'dont_miss';
    } else {
      placement = 'daily_offers';
    }

    // Clean internal #section: tags from user input URL for clean display
    const cleanUrl = rawUrl.replace(/#section:[a-z_]+/g, '').trim();

    let targetType = 'none';
    let targetMerchantId: number | null = null;
    let targetExternalUrl = '';

    if (cleanUrl.startsWith('restaurant:')) {
      targetType = 'restaurant';
      const idStr = cleanUrl.split(':')[1];
      targetMerchantId = idStr ? parseInt(idStr, 10) : null;
    } else if (cleanUrl.startsWith('market:') || cleanUrl.startsWith('merchant:')) {
      targetType = 'market';
      const idStr = cleanUrl.split(':')[1];
      targetMerchantId = idStr ? parseInt(idStr, 10) : null;
    } else if (cleanUrl === 'offers') {
      targetType = 'offers';
    } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      targetType = 'external';
      targetExternalUrl = cleanUrl;
    } else if (cleanUrl && cleanUrl !== 'none') {
      targetType = 'external';
      targetExternalUrl = cleanUrl;
    } else {
      targetType = 'none';
    }

    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item.title, [Validators.required]],
      description: [this.item.description, [Validators.required]],
      order: [this.item.order ?? 0, [Validators.required]],
      active: [this.item.active !== false],
      featuredImage: [this.item.featuredImage],
      bannerLocation: [this.item.bannerLocation ?? 0, [Validators.required]],
      sectionPlacement: [placement, [Validators.required]],
      targetType: [targetType, [Validators.required]],
      targetMerchantId: [targetMerchantId],
      targetExternalUrl: [targetExternalUrl],
    });
  }

  onTargetTypeChange(type: string): void {
    if (type === 'restaurant') {
      const currentId = this.formGroup.get('targetMerchantId')?.value;
      if (
        currentId &&
        this.restaurants.length > 0 &&
        !this.restaurants.some((r) => Number(r.id) === Number(currentId))
      ) {
        this.formGroup.patchValue({ targetMerchantId: null });
      }
    } else if (type === 'market') {
      const currentId = this.formGroup.get('targetMerchantId')?.value;
      if (
        currentId &&
        this.markets.length > 0 &&
        !this.markets.some((m) => Number(m.id) === Number(currentId))
      ) {
        this.formGroup.patchValue({ targetMerchantId: null });
      }
    }
  }

  onFileUploaded(filesIds: string[], key: string): void {
    this.formGroup.patchValue({
      [key]: filesIds.join(','),
    });
  }

  onFileDelete(key: string): void {
    this.formGroup.patchValue({
      [key]: '',
    });
  }

  save(): void {
    if (this.formGroup.invalid) {
      this.formGroup.markAllAsTouched();
      return;
    }

    const formValues = { ...this.formGroup.value };
    const section = formValues.sectionPlacement;
    const targetType = formValues.targetType;
    const targetMerchantId = formValues.targetMerchantId;
    const targetExternalUrl = (formValues.targetExternalUrl || '').trim();

    delete formValues.sectionPlacement;
    delete formValues.targetType;
    delete formValues.targetMerchantId;
    delete formValues.targetExternalUrl;

    let targetUrl = '';
    if (targetType === 'restaurant') {
      if (!targetMerchantId) {
        this.toasterService.warning('يرجى اختيار المطعم المطلوب التوجيه إليه');
        return;
      }
      targetUrl = `restaurant:${targetMerchantId}`;
    } else if (targetType === 'market') {
      if (!targetMerchantId) {
        this.toasterService.warning('يرجى اختيار المتجر / الماركت المطلوب التوجيه إليه');
        return;
      }
      targetUrl = `market:${targetMerchantId}`;
    } else if (targetType === 'offers') {
      targetUrl = 'offers';
    } else if (targetType === 'external') {
      if (!targetExternalUrl) {
        this.toasterService.warning('يرجى إدخال الرابط الخارجي المطلوب');
        return;
      }
      targetUrl = targetExternalUrl;
    } else {
      targetUrl = '';
    }

    if (section === 'restaurants') {
      targetUrl = targetUrl ? `${targetUrl}#section:restaurants` : '#section:restaurants';
      formValues.bannerLocation = 2;
    } else if (section === 'market') {
      targetUrl = targetUrl ? `${targetUrl}#section:market` : '#section:market';
      formValues.bannerLocation = 3;
    } else if (section === 'all') {
      targetUrl = targetUrl ? `${targetUrl}#section:all` : '#section:all';
      formValues.bannerLocation = 4;
    } else if (section === 'dont_miss') {
      targetUrl = targetUrl ? `${targetUrl}#section:dontmiss` : '#section:dontmiss';
      formValues.bannerLocation = 1;
    } else {
      formValues.bannerLocation = 0;
    }
    formValues.url = targetUrl;

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Banner): void {
    this.subs.sink = this.bannersService
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تمت إضافة الإعلان بنجاح');
          this.modal.close();
        })
      )
      .subscribe();
  }

  edit(formValues: Banner): void {
    this.subs.sink = this.bannersService
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تم تحديث بيانات الإعلان بنجاح');
          this.modal.close();
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
