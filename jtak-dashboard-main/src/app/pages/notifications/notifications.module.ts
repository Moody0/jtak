import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NotificationsListComponent } from './components/notifications-list/notifications-list.component';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';
import { NotificationsCreateComponent } from './components/notifications-create/notifications-create.component';

@NgModule({
  declarations: [
    NotificationsListComponent,
    NotificationsCreateComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: NotificationsListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ],
})
export class NotificationsModule { }
