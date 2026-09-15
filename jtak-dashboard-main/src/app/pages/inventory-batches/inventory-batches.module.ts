import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule, NgbPaginationModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { BatchListComponent } from './components/batch-list/batch-list.component';

@NgModule({
  declarations: [BatchListComponent],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    NgbPaginationModule,
    NgSelectModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: BatchListComponent,
      },
    ]),
  ],
})
export class InventoryBatchesModule {}
