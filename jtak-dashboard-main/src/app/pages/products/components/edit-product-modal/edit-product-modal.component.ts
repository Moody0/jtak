import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable, forkJoin, of } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap, catchError } from 'rxjs/operators';
import { Product } from '../../models/product.model';
import { ProductsService } from '../../services/products.service';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { InventoryBatchService } from 'src/app/pages/inventory-batches/services/inventory-batch.service';
import { BatchMerchantLookup } from 'src/app/pages/inventory-batches/models/product-batch.model';

export interface CategoryOption {
  id: number;
  title: string;
  parentId: number | null;
  parentTitle?: string;
  fullPath: string;
  isRoot: boolean;
}

const EMPTY_Product: Product = {
  id: null,
  title: '',
  description: '',
  photos: '',
  unit: 'قطعة',
  active: true,
  isFeatured: false,
  productCategoryId: 0,
  productCategory: '',
  merchantId: undefined,
  price: 0,
};

@Component({
  selector: 'app-edit-product-modal',
  templateUrl: './edit-product-modal.component.html',
  styleUrls: ['./edit-product-modal.component.scss'],
})
export class EditProductModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Product;

  isLoading$: Observable<boolean>;
  formGroup: FormGroup;

  // Category & Hierarchy structure
  categoriesList: CategoryOption[] = [];
  categoryMap = new Map<number, CategoryOption>();

  // Merchants
  merchantsList: BatchMerchantLookup[] = [];

  // Quick Unit Presets
  unitPresets = ['قطعة', 'كغ', 'علبة', 'وجبة', 'لتر', 'صندوق', 'حبة'];

  constructor(
    private service: ProductsService,
    private categoriesService: CategoriesService,
    private batchService: InventoryBatchService,
    public filesService: FilesService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.initItemAndForm();
    this.loadLookups();
  }

  private initItemAndForm(): void {
    if (!this.item) {
      this.item = { ...EMPTY_Product };
    }

    const photoList = this.item.photos
      ? this.item.photos.split(',').map((p) => p.trim()).filter(Boolean)
      : [];

    this.formGroup = this.fb.group({
      id: [this.item.id],
      title: [this.item.title || '', [Validators.required, Validators.minLength(2)]],
      description: [this.item.description || ''],
      unit: [this.item.unit || 'قطعة', [Validators.required]],
      isFeatured: [this.item.isFeatured ?? false],
      active: [this.item.active ?? true],
      photos: [photoList],
      productCategoryId: [this.item.productCategoryId || null, [Validators.required]],
      merchantId: [this.item.merchantId || null],
    });
  }

  loadLookups(): void {
    forkJoin({
      roots: this.categoriesService.getAll(true).pipe(catchError(() => of([]))),
      subs: this.categoriesService.getAll(false).pipe(catchError(() => of([]))),
      merchants: this.batchService.lookupMerchants().pipe(catchError(() => of([]))),
    }).subscribe(({ roots, subs, merchants }) => {
      const rootMap = new Map<number, string>();
      roots.forEach((r) => rootMap.set(r.id, r.title));

      const allCats: CategoryOption[] = [];

      // Add roots
      roots.forEach((r) => {
        const option: CategoryOption = {
          id: r.id,
          title: r.title,
          parentId: null,
          fullPath: `[تصنيف رئيسي] ${r.title}`,
          isRoot: true,
        };
        this.categoryMap.set(r.id, option);
        allCats.push(option);
      });

      // Add subcategories
      subs.forEach((s) => {
        const parentTitle = s.parentId ? rootMap.get(s.parentId) : undefined;
        const fullPath = parentTitle ? `${parentTitle} > ${s.title}` : s.title;
        const option: CategoryOption = {
          id: s.id,
          title: s.title,
          parentId: s.parentId,
          parentTitle,
          fullPath,
          isRoot: false,
        };
        this.categoryMap.set(s.id, option);
        allCats.push(option);
      });

      this.categoriesList = allCats.sort((a, b) => a.fullPath.localeCompare(b.fullPath));
      this.merchantsList = merchants || [];
      if (this.item?.merchantId && this.item?.merchantTitle) {
        if (!this.merchantsList.some((m) => m.id === this.item.merchantId)) {
          this.merchantsList.unshift({
            id: this.item.merchantId,
            title: this.item.merchantTitle,
          });
        }
      }
    });
  }

  setUnit(unit: string): void {
    this.formGroup.patchValue({ unit });
  }

  getSelectedCategoryInfo(): CategoryOption | null {
    const catId = this.formGroup.get('productCategoryId')?.value;
    if (catId && this.categoryMap.has(catId)) {
      return this.categoryMap.get(catId)!;
    }
    return null;
  }

  getSuggestedSubcategory(): CategoryOption | null {
    const title = this.formGroup.get('title')?.value;
    if (!title) return null;
    const t = title.toLowerCase();
    let keyword = '';
    if (/وافل|كريب|تشيزكيك|كيك|برازق|مدلوقة|بقلاوة|مبرومة|حلاوة الجبن|كنافة|معمول|شوكولا|غريبة|بوظة|آيس كريم|حلوى|تورتة|دونات/.test(t)) {
      keyword = 'حلويات';
    } else if (/كولد برو|لاتيه|قهوة|مشروب|عصير|سبانش|اسبريسو|موكا|شاي|كوكتيل|ميلك شيك|سموذي|مشروبات/.test(t)) {
      keyword = 'مشروبات';
    } else if (/برغر|برجر|فرايز|بطاطا|كرسبي|تشيكن|شاورما|بروستد|ساندويش|سندويش|تاكو|بيتزا|زنجر|فاير/.test(t)) {
      keyword = 'وجبات';
    } else if (/فول|حمص|فلافل|فتة|مسبحة|تسقية|بيض|فطور|معجنات|فطائر|مناقيش/.test(t)) {
      keyword = 'فطور';
    } else if (/مشاوي|كباب|شيش|شقف|كبة|لحمة|عرايس|طاووق|ريش|كفتة/.test(t)) {
      keyword = 'مشاوي';
    }

    if (!keyword) return null;
    return this.categoriesList.find((c) => !c.isRoot && (c.title.includes(keyword) || c.fullPath.includes(keyword))) || null;
  }

  applySuggestion(option: CategoryOption): void {
    this.formGroup.patchValue({ productCategoryId: option.id });
    this.toasterService.success(`تم اختيار "${option.fullPath}" كإعداد للتصنيف`);
  }

  getPrimaryPhoto(): string | undefined {
    const photos = this.formGroup.get('photos')?.value;
    return photos && photos.length ? photos[0] : undefined;
  }

  onFileUploaded(filesIds: string[], key: string): void {
    const current = this.formGroup.get(key)?.value || [];
    const updated = [...current, ...filesIds];
    this.formGroup.patchValue({ [key]: updated });
  }

  onFileDelete(key: string, fileId: string): void {
    const current = this.formGroup.get(key)?.value || [];
    const updated = current.filter((id: string) => id !== fileId);
    this.formGroup.patchValue({ [key]: updated });
  }

  setAsPrimaryPhoto(fileId: string): void {
    const current: string[] = this.formGroup.get('photos')?.value || [];
    const reordered = [fileId, ...current.filter((id) => id !== fileId)];
    this.formGroup.patchValue({ photos: reordered });
    this.toasterService.info('تم تعيين الصورة كصورة رئيسية للمنتج');
  }

  save(): void {
    if (this.formGroup.invalid) {
      this.formGroup.markAllAsTouched();
      return;
    }

    const formValues = { ...this.formGroup.value };
    const photosArray = formValues.photos || [];
    formValues.photos = photosArray.join(',');

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Product): void {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('تمت إضافة المنتج بنجاح');
          this.modal.close(this.modalResult({ ...formValues, id }));
        })
      )
      .subscribe();
  }

  edit(formValues: Product): void {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تم تحديث بيانات المنتج بنجاح');
          this.modal.close(this.modalResult(formValues));
        })
      )
      .subscribe();
  }

  private modalResult(product: Product): Product {
    const cat = this.categoryMap.get(product.productCategoryId);
    return {
      ...product,
      productCategory: cat?.title || product.productCategory || '',
      categoryHierarchy: cat?.fullPath || '',
      parentCategoryTitle: cat?.parentTitle || '',
    };
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
