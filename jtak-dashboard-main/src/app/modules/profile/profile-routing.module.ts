import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import { CampaignsComponent } from './campaigns/campaigns.component';
import { DocumentsComponent } from './documents/documents.component';
import { ProjectsComponent } from './projects/projects.component';
import { ProfileComponent } from './profile.component';
import { ConnectionsComponent } from './connections/connections.component';
import { BannersComponent } from './banners/banners.component';

const routes: Routes = [
  {
    path: '',
    component: ProfileComponent,
    children: [
      {
        path: 'banners',
        component: BannersComponent,
      },
      {
        path: 'projects',
        component: ProjectsComponent,
      },
      {
        path: 'campaigns',
        component: CampaignsComponent,
      },
      {
        path: 'documents',
        component: DocumentsComponent,
      },
      {
        path: 'connections',
        component: ConnectionsComponent,
      },
      { path: '', redirectTo: 'banners', pathMatch: 'full' },
      { path: '**', redirectTo: 'banners', pathMatch: 'full' },
    ],
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class ProfileRoutingModule {}
