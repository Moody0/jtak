import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DeleteCategoryModalComponent } from './components/delete-category-modal/delete-category-modal.component';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';
import { CategoriesListComponent } from './components/categories-list/categories-list.component';
import { CatalogEditorsModule } from '../catalog-editors/catalog-editors.module';

@NgModule({
  declarations: [
    CategoriesListComponent,
    DeleteCategoryModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: CategoriesListComponent,
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
export class CategoriesModule {}
