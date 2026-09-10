import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { productReviewsListComponent } from './components/product-reviews-list/product-reviews-list.component';

@NgModule({
  declarations: [
    productReviewsListComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: productReviewsListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ]
})
export class ReviewsModule { }
