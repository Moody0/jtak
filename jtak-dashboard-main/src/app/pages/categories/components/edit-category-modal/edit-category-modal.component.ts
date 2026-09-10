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
  styles: [],
})
export class EditCategoryModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Category;
  parentCategories: Category[];
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);

  constructor(
    private service: CategoriesService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) { }

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    this.service.getAll(true).subscribe(cats => {
      this.parentCategories = cats;
    });
    if (!this.item) {
      this.item = EMPTY_Item;
    } else {
      //this.service.getItem(this.item.id).subscribe((item) => {
      //  this.item = item as Category;
      //});
    }
    console.log(this.item);
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item.title, [Validators.required]],
      parentId: [this.item.parentId || null],
      order: [this.item?.order ?? 0],
      active: [this.item.active ?? true, [Validators.required]],
      icon: [this.item.icon || ''],
    });
  }

  onFileUploaded(filesIds: string[], key: string) {
    this.formGroup.patchValue({
      [key]: filesIds.join(",")
    });
  }

  onFileDelete(key: string) {
    this.formGroup.patchValue({
      [key]: '',
    });
  }

  save() {
    const formValues = { ...this.formGroup.value };
    if (!formValues.parentId) {
      formValues.parentId = null;
    }
    formValues.order = Number(formValues.order) || 0;

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Category) {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('Category Added');
          this.modal.close({ ...formValues, id });
        })
      )
      .subscribe();
  }

  edit(formValues: Category) {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Category Updated');
          this.modal.close(formValues);
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
