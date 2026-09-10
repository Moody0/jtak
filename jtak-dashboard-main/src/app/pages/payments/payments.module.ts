import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CreatePaymentModalComponent } from './components/create-payment-modal/create-payment-modal.component';
import { PaymentsListComponent } from './components/payments-list/payments-list.component';
import { RouterModule } from '@angular/router';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';

@NgModule({
  declarations: [
    CreatePaymentModalComponent,
    PaymentsListComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: PaymentsListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ]
})
export class PaymentsModule { }
