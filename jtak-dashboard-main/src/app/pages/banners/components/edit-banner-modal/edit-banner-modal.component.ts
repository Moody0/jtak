import { ChangeDetectorRef, Component, OnInit, Input, OnDestroy } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { Banner } from '../../models/banner.model';
import { BannersService } from '../../services/banners.service';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { Merchant } from 'src/app/pages/merchant/models/merchant.model';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';

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
  formGroup: UntypedFormGroup;

  merchants: Merchant[] = [];
  restaurants: Merchant[] = [];
  markets: Merchant[] = [];
  loadingMerchants = false;
  isSaving = false;
  categories: { id: number; title: string; active?: boolean }[] = [];
  loadingCategories = false;

  merchantSearchFn = (term: string, item: Merchant) => {
    if (!term) return true;
    term = term.trim().toLowerCase();
    const cleanTerm = term.startsWith('#') ? term.substring(1).trim() : term;
    const title = (item.title || '').toLowerCase();
    const shortDesc = (item.shortDescription || '').toLowerCase();
    const desc = (item.description || '').toLowerCase();
    const id = String(item.id || '');
    return (
      title.includes(term) ||
      title.includes(cleanTerm) ||
      shortDesc.includes(term) ||
      shortDesc.includes(cleanTerm) ||
      desc.includes(term) ||
      desc.includes(cleanTerm) ||
      id === term ||
      id === cleanTerm ||
      `#${id}` === term ||
      id.includes(term) ||
      id.includes(cleanTerm)
    );
  };

  constructor(
    private bannersService: BannersService,
    private merchantsService: MerchantsService,
    private fb: UntypedFormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService,
    private cdr: ChangeDetectorRef,
    private categoriesService: CategoriesService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.bannersService.isLoading$;
    this.loadItem();
    this.loadForm();
    this.loadMerchants();
    this.loadCategories();
  }

  loadItem(): void {
    if (!this.item) {
      this.item = { ...EMPTY_BANNER };
    }
  }

  loadMerchants(): void {
    this.loadingMerchants = true;
    this.subs.sink = this.merchantsService.getAllMerchants().subscribe({
      next: (items) => {
        const all = items || [];
        this.merchants = all;
        const currentTargetId = Number(this.formGroup?.get('targetMerchantId')?.value);
        if (/^\d+$/.test((this.item?.url || '').replace(/#section:[a-z_]+/gi, '').trim()) && all.some(m => Number(m.id) === currentTargetId && Number(m.merchantKind) === 0)) {
          this.formGroup.patchValue({ targetType: 'restaurant' });
        }

        this.restaurants = all.filter(
          (m) =>
            Number(m.merchantKind) === 0 &&
            (m.active !== false || Number(m.id) === currentTargetId)
        );

        this.markets = all.filter(
          (m) =>
            Number(m.merchantKind) > 0 &&
            (m.active !== false || Number(m.id) === currentTargetId)
        );

        this.loadingMerchants = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.loadingMerchants = false;
        this.toasterService.error('تعذر تحميل المتاجر، أعد فتح النافذة وحاول مرة أخرى');
        this.cdr.detectChanges();
      },
    });
  }

  getMerchantName(id: any): string {
    if (!id) return '';
    const numId = Number(id);
    const m = this.merchants.find((x) => Number(x.id) === numId);
    if (m?.title) return m.title;
    return `#${numId}`;
  }

  loadCategories(): void {
    this.loadingCategories = true;
    this.subs.sink = this.categoriesService.getAll(false, true).subscribe({
      next: items => {
        const currentId = Number(this.formGroup.get('targetCategoryId')?.value);
        this.categories = (items || []).filter(c => c.active !== false || Number(c.id) === currentId).map(c => ({ ...c, id: Number(c.id) }));
        this.loadingCategories = false; this.cdr.detectChanges();
      },
      error: () => { this.loadingCategories = false; this.toasterService.error('تعذر تحميل التصنيفات، أعد فتح النافذة وحاول مرة أخرى'); this.cdr.detectChanges(); }
    });
  }

  isMerchantInactive(id: any): boolean {
    if (!id) return false;
    const numId = Number(id);
    const m = this.merchants.find((x) => Number(x.id) === numId);
    return m ? m.active === false : false;
  }

  loadForm(): void {
    let placement = 'daily_offers';
    const rawUrl = this.item?.url || '';
    const loc = this.item?.bannerLocation;

    const locations = ['daily_offers', 'dont_miss', 'restaurants', 'market', 'all'];
    if (loc != null && locations[loc]) placement = locations[loc];
    else if (rawUrl.includes('section:all')) placement = 'all';
    else if (rawUrl.includes('section:dontmiss')) placement = 'dont_miss';
    else if (rawUrl.includes('section:restaurant')) placement = 'restaurants';
    else if (rawUrl.includes('section:market')) placement = 'market';

    // Clean internal #section: tags from user input URL for clean display
    const cleanUrl = rawUrl.replace(/#section:[a-z_]+/gi, '').trim();

    let targetType = 'none';
    let targetMerchantId: number | null = null;
    let targetExternalUrl = '';
    let targetCategoryId: number | null = null;

    if (cleanUrl.startsWith('restaurant:')) {
      targetType = 'restaurant';
      const idStr = cleanUrl.split(':')[1];
      targetMerchantId = idStr ? parseInt(idStr, 10) : null;
    } else if (cleanUrl.startsWith('market:') || cleanUrl.startsWith('merchant:') || cleanUrl.startsWith('store:')) {
      targetType = 'market';
      const idStr = cleanUrl.split(':')[1];
      targetMerchantId = idStr ? parseInt(idStr, 10) : null;
    } else if (/^\d+$/.test(cleanUrl)) {
      targetType = 'market'; targetMerchantId = Number(cleanUrl);
    } else if (/^category:\d+$/i.test(cleanUrl)) {
      targetType = 'category'; targetCategoryId = Number(cleanUrl.split(':')[1]);
    } else if (cleanUrl === 'offers' || cleanUrl === 'promotions') {
      targetType = 'offers';
    } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      targetType = 'external';
      targetExternalUrl = cleanUrl;
    } else if (cleanUrl && cleanUrl !== 'none' && cleanUrl !== 'no_link') {
      targetType = 'external';
      targetExternalUrl = cleanUrl;
    } else {
      targetType = 'none';
    }

    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item.title, [Validators.required]],
      description: [this.item.description],
      order: [this.item.order ?? 0, [Validators.required]],
      active: [this.item.active !== false],
      featuredImage: [this.item.featuredImage],
      bannerLocation: [this.item.bannerLocation ?? 0, [Validators.required]],
      sectionPlacement: [placement, [Validators.required]],
      targetType: [targetType, [Validators.required]],
      targetMerchantId: [targetMerchantId],
      targetExternalUrl: [targetExternalUrl],
      targetCategoryId: [targetCategoryId],
    });
  }

  onTargetTypeChange(type: string): void {
    const currentId = this.formGroup.get('targetMerchantId')?.value;
    if (!currentId) return;

    if (type === 'restaurant') {
      if (
        this.restaurants.length > 0 &&
        !this.restaurants.some((r) => Number(r.id) === Number(currentId))
      ) {
        this.formGroup.patchValue({ targetMerchantId: null });
      }
    } else if (type === 'market') {
      if (
        this.markets.length > 0 &&
        !this.markets.some((m) => Number(m.id) === Number(currentId))
      ) {
        this.formGroup.patchValue({ targetMerchantId: null });
      }
    } else {
      this.formGroup.patchValue({ targetMerchantId: null });
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
    if (this.isSaving) return;
    if (this.formGroup.invalid) {
      this.formGroup.markAllAsTouched();
      return;
    }

    const formValues = { ...this.formGroup.value };
    const section = formValues.sectionPlacement;
    const targetType = formValues.targetType;
    const targetMerchantId = formValues.targetMerchantId;
    const targetExternalUrl = (formValues.targetExternalUrl || '').trim();
    const targetCategoryId = Number(formValues.targetCategoryId);

    formValues.title = (formValues.title || '').trim();
    if (!formValues.title || (formValues.active && !(formValues.featuredImage || '').trim()) || !Number.isInteger(Number(formValues.order)) || Number(formValues.order) < 0) {
      this.toasterService.warning('أدخل عنواناً وصورة للإعلان المفعّل وترتيباً صحيحاً غير سالب');
      return;
    }
    if (targetType === 'market' || targetType === 'restaurant') {
      const choices = targetType === 'market' ? this.markets : this.restaurants;
      if (!Number.isInteger(Number(targetMerchantId)) || Number(targetMerchantId) <= 0 || !choices.some(m => Number(m.id) === Number(targetMerchantId))) {
        this.toasterService.warning('اختر وجهة موجودة من القائمة بعد اكتمال تحميل المتاجر');
        return;
      }
    }
    if (targetType === 'external') {
      try {
        const url = new URL(targetExternalUrl);
        if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) throw new Error();
      } catch {
        this.toasterService.warning('أدخل رابطاً صحيحاً يبدأ بـ https:// أو http://');
        return;
      }
    }
    if (targetType === 'category' && (!Number.isInteger(targetCategoryId) || targetCategoryId <= 0 || !this.categories.some(c => c.id === targetCategoryId))) {
      this.toasterService.warning('اختر تصنيفاً موجوداً من القائمة بعد اكتمال تحميل التصنيفات'); return;
    }
    delete formValues.sectionPlacement;
    delete formValues.targetType;
    delete formValues.targetMerchantId;
    delete formValues.targetExternalUrl;
    delete formValues.targetCategoryId;

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
    } else if (targetType === 'category') {
      targetUrl = `category:${targetCategoryId}`;
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
      formValues.bannerLocation = 2;
    } else if (section === 'market') {
      formValues.bannerLocation = 3;
    } else if (section === 'all') {
      formValues.bannerLocation = 4;
    } else if (section === 'dont_miss') {
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

  create(formValues: Banner): void { this.persist(formValues, false); }
  edit(formValues: Banner): void { this.persist(formValues, true); }

  private persist(formValues: Banner, editing: boolean): void {
    if (this.isSaving) return;
    this.isSaving = true;
    this.formGroup.disable();
    const request: Observable<unknown> = editing ? this.bannersService.update(formValues) : this.bannersService.create(formValues);
    this.subs.sink = request.subscribe({
      next: () => { this.isSaving = false; this.toasterService.success('تم حفظ الإعلان بنجاح'); this.modal.close(true); },
      error: err => { this.isSaving = false; this.formGroup.enable(); this.toasterService.error(typeof err?.error === 'string' ? err.error : 'تعذر حفظ الإعلان، حاول مرة أخرى'); this.cdr.detectChanges(); }
    });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
