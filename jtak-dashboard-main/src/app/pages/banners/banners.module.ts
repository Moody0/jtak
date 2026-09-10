import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { BannersListComponent } from './components/banners-list/banners-list.component';
import { EditBannerModalComponent } from './components/edit-banner-modal/edit-banner-modal.component';
import { DeleteBannerModalComponent } from './components/delete-banner-modal/delete-banner-modal.component';
import { RouterModule } from '@angular/router';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';

@NgModule({
  declarations: [
    BannersListComponent,
    EditBannerModalComponent,
    DeleteBannerModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: BannersListComponent,
      },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
  ],
})
export class BannersModule {}
