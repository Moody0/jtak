import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { UsersListComponent } from './components/users-list/users-list.component';
import { EditUserModalComponent } from './components/edit-user-modal/edit-user-modal.component';
import { DeleteUserModalComponent } from './components/delete-user-modal/delete-user-modal.component';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';

@NgModule({
  declarations: [UsersListComponent, EditUserModalComponent, DeleteUserModalComponent],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: UsersListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ],
})
export class UsersModule {}
