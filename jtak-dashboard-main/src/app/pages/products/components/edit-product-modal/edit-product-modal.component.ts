import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Product } from '../../models/product.model';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import { ProductsService } from '../../services/products.service';
import { Category } from '../../../categories/models/Category.model';
import { CategoriesService } from 'src/app/pages/categories/services/categories.service';

const EMPTY_Product: Product = {
  id: null,
  title: '',
  description: '',
  photos: '',
  unit: '',
  active: false,
  isFeatured: false,
  productCategoryId: 0,
  productCategory: '',
};

@Component({
  selector: 'app-edit-product-modal',
  templateUrl: './edit-product-modal.component.html',
  styles: [],
})
export class EditProductModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Product;
  productCategories: Category[];
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);

  constructor(
    private service: ProductsService,
    private categoriesService: CategoriesService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    this.categoriesService.getAll().subscribe(cats => {
      this.productCategories = cats;
    });
    if (!this.item) {
      this.item = EMPTY_Product;
    } else {
      //this.service.getItem(this.item.id).subscribe((prod) => {
      //  this.item = prod as Product;
      //});
    }
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item.title, [Validators.required]],
      description: [this.item.description],
      unit: [this.item.unit, [Validators.required]],
      isFeatured: [this.item.isFeatured, [Validators.required]],
      active: [this.item.active, [Validators.required]],
      photos: [this.item.photos?.split(',')],
      productCategoryId: [this.item.productCategoryId, [Validators.required]],
    });
  }

  onFileUploaded(filesIds: string[], key: string) {
    const photos = [...this.formGroup.value.photos, ...filesIds];
    this.formGroup.patchValue({
      [key]: photos
    });
  }

  onFileDelete(key: string, filesId: string) {
    console.log(this.formGroup.value.photos);
    const photos = this.formGroup.value.photos?.filter((e: string) => e !== filesId);
    this.formGroup.patchValue({
      [key]: photos
    });
  }

  save() {
    const formValues = this.formGroup.value;
    formValues.photos = formValues.photos.join(",");
    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Product) {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('Product added');
          this.modal.close(this.modalResult({ ...formValues, id }));
        })
      )
      .subscribe();
  }

  edit(formValues: Product) {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Product updated');
          this.modal.close(this.modalResult(formValues));
        })
      )
      .subscribe();
  }

  private modalResult(product: Product): Product {
    const category = this.productCategories?.find((item) => item.id === product.productCategoryId);
    return { ...product, productCategory: category?.title || product.productCategory || '' };
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
