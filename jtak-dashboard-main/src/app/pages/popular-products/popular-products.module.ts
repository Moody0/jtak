import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { TranslateModule } from '@ngx-translate/core';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { PopularProductsListComponent } from './components/popular-products-list/popular-products-list.component';
import { AddPopularProductModalComponent } from './components/add-popular-product-modal/add-popular-product-modal.component';

@NgModule({
  declarations: [
    PopularProductsListComponent,
    AddPopularProductModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    NgSelectModule,
    TranslateModule,
    CRUDTableModule,
    RouterModule.forChild([
      {
        path: '',
        component: PopularProductsListComponent,
      },
    ]),
  ],
})
export class PopularProductsModule {}
