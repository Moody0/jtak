import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { ReconciliationListComponent } from './components/reconciliation-list/reconciliation-list.component';

@NgModule({
  declarations: [ReconciliationListComponent],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: ReconciliationListComponent,
      },
    ]),
  ],
})
export class ReconciliationModule {}
