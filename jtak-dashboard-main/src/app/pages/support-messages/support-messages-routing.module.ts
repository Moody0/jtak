import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { SupportMessagesListComponent } from './components/support-messages-list/support-messages-list.component';

const routes: Routes = [
  {
    path: '',
    component: SupportMessagesListComponent,
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class SupportMessagesRoutingModule {}
