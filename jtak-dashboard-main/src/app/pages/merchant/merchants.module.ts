import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MerchantsListComponent } from './components/merchants-list/merchants-list.component';
import { EditMerchantModalComponent } from './components/edit-merchant-modal/edit-merchant-modal.component';
import { DeleteMerchantModalComponent } from './components/delete-merchant-modal/delete-merchant-modal.component';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { ApplicationRoutes } from 'src/app/_metronic/config/settings';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';
import { SetProductModalComponent } from './components/set-product-modal/set-product-modal.component';
import { GoogleMapsModule } from '@angular/google-maps';
import { MerchantWorkspaceComponent } from './components/merchant-workspace/merchant-workspace.component';
import { CatalogEditorsModule } from '../catalog-editors/catalog-editors.module';

@NgModule({
  declarations: [
    MerchantsListComponent,
    EditMerchantModalComponent,
    DeleteMerchantModalComponent,
    SetProductModalComponent,
    MerchantWorkspaceComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    GoogleMapsModule,
    RouterModule.forChild([
      {
        path: ApplicationRoutes.Empty,
        component: MerchantsListComponent,
        pathMatch: 'full',
      },
      { path: ':id/:tab', component: MerchantWorkspaceComponent },
      { path: ':id', component: MerchantWorkspaceComponent },
    ]),
    FormsModule,
    NgSelectModule,
    ReactiveFormsModule,
    CRUDTableModule,
    NgbModalModule,
    CatalogEditorsModule,
  ],
})
export class MerchantsModule {}
