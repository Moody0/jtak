import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { RestaurantCategoriesListComponent } from './components/restaurant-categories-list/restaurant-categories-list.component';
import { EditRestaurantCategoryModalComponent } from './components/edit-restaurant-category-modal/edit-restaurant-category-modal.component';
import { DeleteRestaurantCategoryModalComponent } from './components/delete-restaurant-category-modal/delete-restaurant-category-modal.component';

@NgModule({
  declarations: [
    RestaurantCategoriesListComponent,
    EditRestaurantCategoryModalComponent,
    DeleteRestaurantCategoryModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    TranslateModule,
    CRUDTableModule,
    RouterModule.forChild([
      {
        path: '',
        component: RestaurantCategoriesListComponent,
      },
    ]),
  ],
})
export class RestaurantCategoriesModule {}
