import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { SupportMessagesListComponent } from './components/support-messages-list/support-messages-list.component';
import { ErrandRequestsListComponent } from './components/errand-requests-list/errand-requests-list.component';

const routes: Routes = [
  {
    path: 'errands',
    component: ErrandRequestsListComponent,
  },
  {
    path: '',
    pathMatch: 'full',
    component: SupportMessagesListComponent,
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class SupportMessagesRoutingModule {}
