import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DeleteProductModalComponent } from './components/delete-product-modal/delete-product-modal.component';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';
import { ProductsListComponent } from './components/products-list/products-list.component';
import { CatalogEditorsModule } from '../catalog-editors/catalog-editors.module';

@NgModule({
  declarations: [
    ProductsListComponent,
    DeleteProductModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: ProductsListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
    CatalogEditorsModule,
  ],
})
export class ProductsModule {}
