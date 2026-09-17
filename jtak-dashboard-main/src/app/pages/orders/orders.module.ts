import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { OrdersListComponent } from './components/orders-list/orders-list.component';
import { RouterModule } from '@angular/router';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbDropdownModule, NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { EditDilevry } from './components/orders-list/EditDilevry/edit-dilevry.component';
import { LiveTrackModalComponent } from './components/orders-list/LiveTrackModal/live-track-modal.component';
import { AdminDeliverModalComponent } from './components/orders-list/AdminDeliverModal/admin-deliver-modal.component';
import { OrderStatusHistoryModalComponent } from './components/orders-list/OrderStatusHistoryModal/order-status-history-modal.component';
import { NgSelectModule } from '@ng-select/ng-select';
import { GoogleMapsModule } from '@angular/google-maps';

@NgModule({
  declarations: [
    OrdersListComponent,
    EditDilevry,
    LiveTrackModalComponent,
    AdminDeliverModalComponent,
    OrderStatusHistoryModalComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: OrdersListComponent,
      },
    ]),
    FormsModule,
    ReactiveFormsModule,
    CommonModule,
    CRUDTableModule,
    NgbModalModule,
    NgbDropdownModule,
    NgSelectModule,
    GoogleMapsModule
  ]
})
export class OrdersModule { }
