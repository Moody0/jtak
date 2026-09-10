import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { EditProductModalComponent } from '../products/components/edit-product-modal/edit-product-modal.component';
import { EditCategoryModalComponent } from '../categories/components/edit-category-modal/edit-category-modal.component';

@NgModule({
  declarations: [EditProductModalComponent, EditCategoryModalComponent],
  imports: [CommonModule, FormsModule, ReactiveFormsModule, NgSelectModule, SharedModule],
  exports: [EditProductModalComponent, EditCategoryModalComponent],
})
export class CatalogEditorsModule {}
