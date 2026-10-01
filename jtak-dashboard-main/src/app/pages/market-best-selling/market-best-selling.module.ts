import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { NgSelectModule } from '@ng-select/ng-select';
import { TranslateModule } from '@ngx-translate/core';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';
import { MarketBestSellingListComponent } from './components/market-best-selling-list/market-best-selling-list.component';
import { AddMarketBestSellingModalComponent } from './components/add-market-best-selling-modal/add-market-best-selling-modal.component';

@NgModule({
  declarations: [
    MarketBestSellingListComponent,
    AddMarketBestSellingModalComponent,
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    NgSelectModule,
    TranslateModule,
    CRUDTableModule,
    RouterModule.forChild([
      {
        path: '',
        component: MarketBestSellingListComponent,
      },
    ]),
  ],
})
export class MarketBestSellingModule {}
