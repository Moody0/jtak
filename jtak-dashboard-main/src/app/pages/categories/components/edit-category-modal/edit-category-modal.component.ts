import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import { CategoriesService } from '../../services/categories.service';
import { Category } from '../../models/Category.model';
import { FilesService } from 'src/app/modules/shared/services/files.service';

const EMPTY_Item: Category = {
  id: 0,
  title: '',
  parentId: null,
  active: true,
  icon: '',
  order: 0,
};

@Component({
  selector: 'app-edit-category-modal',
  templateUrl: './edit-category-modal.component.html',
  styleUrls: ['./edit-category-modal.component.scss'],
})
export class EditCategoryModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Category;
  parentCategories: Category[] = [];
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);

  orderPresets: number[] = [0, 1, 2, 3, 4, 5, 10];

  constructor(
    private service: CategoriesService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    public filesService: FilesService,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem(): void {
    this.service.getAll(true).subscribe((cats) => {
      this.parentCategories = cats || [];
    });
    if (!this.item) {
      this.item = { ...EMPTY_Item };
    }
  }

  loadForm(): void {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item?.title || '', [Validators.required]],
      parentId: [this.item?.parentId || null],
      order: [this.item?.order ?? 0],
      active: [this.item?.active ?? true, [Validators.required]],
      icon: [this.item?.icon || ''],
    });
  }

  getAvailableParents(): Category[] {
    if (!this.parentCategories) return [];
    if (!this.item?.id) return this.parentCategories;
    return this.parentCategories.filter((c) => c.id !== this.item.id);
  }

  getParentTitle(): string | null {
    const parentId = this.formGroup?.get('parentId')?.value;
    if (!parentId) return null;
    const parent = this.parentCategories.find((c) => c.id === parentId);
    return parent ? parent.title : null;
  }

  getIconPreview(): string | null {
    return this.formGroup?.get('icon')?.value || null;
  }

  setOrder(val: number): void {
    this.formGroup.get('order')?.setValue(val);
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

  onImageError(event: any): void {
    event.target.src = './assets/media/svg/files/blank-image.svg';
  }

  save(): void {
    const formValues = { ...this.formGroup.value };
    if (!formValues.parentId) {
      formValues.parentId = null;
    }
    formValues.order = Number(formValues.order) || 0;

    if (this.item && this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Category): void {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('تمت إضافة التصنيف بنجاح');
          this.modal.close({ ...formValues, id });
        })
      )
      .subscribe();
  }

  edit(formValues: Category): void {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تم تحديث بيانات التصنيف بنجاح');
          this.modal.close(formValues);
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
