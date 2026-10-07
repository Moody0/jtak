import { DashboardWriteDirective } from 'src/app/modules/shared/directives/dashboard-write.directive';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import { CRUDTableModule } from 'src/app/_metronic/shared/crud-table';

import { SupportMessagesRoutingModule } from './support-messages-routing.module';
import { SupportMessagesListComponent } from './components/support-messages-list/support-messages-list.component';
import { ViewMessageModalComponent } from './components/view-message-modal/view-message-modal.component';
import { ErrandRequestsListComponent } from './components/errand-requests-list/errand-requests-list.component';

@NgModule({
  declarations: [SupportMessagesListComponent, ViewMessageModalComponent, ErrandRequestsListComponent],
  imports: [DashboardWriteDirective, 
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    TranslateModule,
    CRUDTableModule,
    SupportMessagesRoutingModule,
  ],
})
export class SupportMessagesModule {}
