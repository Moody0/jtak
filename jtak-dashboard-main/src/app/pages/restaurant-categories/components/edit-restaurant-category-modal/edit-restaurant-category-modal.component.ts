import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { RestaurantCategoryItem } from '../../models/restaurant-category.model';
import { RestaurantCategoriesService } from '../../services/restaurant-categories.service';

const EMPTY_ITEM: RestaurantCategoryItem = {
  id: 0,
  title: '',
  titleEn: '',
  image: '',
  order: 0,
  active: true,
  filterTag: '',
};

@Component({
  selector: 'app-edit-restaurant-category-modal',
  templateUrl: './edit-restaurant-category-modal.component.html',
  styleUrls: ['./edit-restaurant-category-modal.component.scss'],
})
export class EditRestaurantCategoryModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();

  @Input() item: RestaurantCategoryItem | null = null;
  @Input() nextOrder: number = 1;

  formGroup: FormGroup;
  isSaving = false;

  presetImages: Array<{ label: string; path: string }> = [
    { label: 'شاورما', path: 'assets/images/products/Arabic Chicken Shawarma Platter.webp' },
    { label: 'مشاوي', path: 'assets/images/categories/meat_poultry.png' },
    { label: 'فطور شعبي', path: 'assets/images/categories/dish_syrian.png' },
    { label: 'حلويات', path: 'assets/images/products/Classic Roll.webp' },
    { label: 'برجر', path: 'assets/images/products/Double Angus Smash Burger.webp' },
    { label: 'مشروبات', path: 'assets/images/products/Iced Spanish Latte.webp' },
    { label: 'مخبوزات', path: 'assets/images/products/Minibon 9-Pack Box.webp' },
    { label: 'بيتزا', path: 'assets/images/cuisines/pizza.webp' },
    { label: 'سوشي ومأكولات بحرية', path: 'assets/images/categories/fish.png' },
  ];

  constructor(
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private categoriesService: RestaurantCategoriesService,
    public filesService: FilesService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    this.initForm();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  private initForm(): void {
    const isEdit = !!this.item && this.item.id > 0;
    this.formGroup = this.fb.group({
      id: [isEdit ? this.item!.id : 0],
      title: [isEdit ? this.item!.title : '', [Validators.required, Validators.maxLength(100)]],
      titleEn: [isEdit ? (this.item!.titleEn || '') : '', [Validators.maxLength(100)]],
      filterTag: [isEdit ? (this.item!.filterTag || '') : ''],
      image: [isEdit ? (this.item!.image || '') : ''],
      order: [isEdit ? this.item!.order : this.nextOrder, [Validators.required, Validators.min(1)]],
      active: [isEdit ? this.item!.active : true],
    });

    // Auto-populate filterTag when title changes if filterTag was empty or equal to old title
    this.subs.sink = this.formGroup.get('title')!.valueChanges.subscribe((val) => {
      const currentTag = this.formGroup.get('filterTag')!.value;
      if (!currentTag || currentTag === (this.item?.title || '')) {
        this.formGroup.patchValue({ filterTag: val }, { emitEvent: false });
      }
    });
  }

  get isEdit(): boolean {
    return !!this.item && this.item.id > 0;
  }

  getImageUrl(): string {
    const raw = this.formGroup.get('image')?.value;
    if (!raw || !raw.trim()) {
      return './assets/media/svg/files/blank-image.svg';
    }
    const val = raw.trim();
    if (val.startsWith('http://') || val.startsWith('https://')) {
      return val;
    }
    if (val.startsWith('assets/') || val.startsWith('./assets/')) {
      return val;
    }
    return this.filesService.getFile(val, 200, 200);
  }

  selectPresetImage(path: string): void {
    this.formGroup.patchValue({ image: path });
  }

  onFileUploaded(fileIds: string[], key: string): void {
    if (fileIds && fileIds.length > 0) {
      this.formGroup.patchValue({ [key]: fileIds[0] });
    }
  }

  onFileDelete(key: string): void {
    this.formGroup.patchValue({ [key]: '' });
  }

  save(): void {
    if (this.formGroup.invalid) {
      this.formGroup.markAllAsTouched();
      return;
    }

    this.isSaving = true;
    const formVal = this.formGroup.value;

    const payload: RestaurantCategoryItem = {
      id: formVal.id,
      title: (formVal.title || '').trim(),
      titleEn: (formVal.titleEn || '').trim(),
      filterTag: (formVal.filterTag || formVal.title || '').trim(),
      image: (formVal.image || '').trim(),
      order: Number(formVal.order) || 1,
      active: !!formVal.active,
    };

    if (this.isEdit) {
      this.subs.sink = this.categoriesService.updateItem(payload).subscribe({
        next: () => {
          this.isSaving = false;
          this.toastr.success('تم تحديث تصنيف المطاعم بنجاح');
          this.modal.close(payload);
        },
        error: () => {
          this.isSaving = false;
          this.toastr.error('تعذر تحديث التصنيف. حاول مرة أخرى.');
        },
      });
    } else {
      this.subs.sink = this.categoriesService.addItem(payload).subscribe({
        next: (created) => {
          this.isSaving = false;
          this.toastr.success('تمت إضافة تصنيف المطاعم بنجاح');
          this.modal.close(created);
        },
        error: () => {
          this.isSaving = false;
          this.toastr.error('تعذر إضافة التصنيف. حاول مرة أخرى.');
        },
      });
    }
  }
}
