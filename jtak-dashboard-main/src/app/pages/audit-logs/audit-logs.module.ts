import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbDropdownModule, NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { AuditLogsListComponent } from './components/audit-logs-list/audit-logs-list.component';
import { AuditLogDetailsModalComponent } from './components/audit-log-details-modal/audit-log-details-modal.component';

@NgModule({
  declarations: [
    AuditLogsListComponent,
    AuditLogDetailsModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
    NgbDropdownModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: AuditLogsListComponent,
      },
    ]),
  ],
})
export class AuditLogsModule {}
