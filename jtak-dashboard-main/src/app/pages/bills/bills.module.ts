import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { BillsListComponent } from './components/bills-list/bills-list.component';
import { RouterModule } from '@angular/router';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';


@NgModule({
  declarations: [
    BillsListComponent
  ],

  imports: [
    SharedModule,
    CommonModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: BillsListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ],

})
export class BillsModule { }
