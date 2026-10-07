import { DashboardWriteDirective } from 'src/app/modules/shared/directives/dashboard-write.directive';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { TranslationModule } from 'src/app/modules/i18n';
import { TedallalSettingsComponent } from './tedallal-settings.component';

const routes: Routes = [
  {
    path: '',
    component: TedallalSettingsComponent,
  },
];

@NgModule({
  declarations: [TedallalSettingsComponent],
  imports: [DashboardWriteDirective, 
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    TranslationModule,
    RouterModule.forChild(routes),
  ],
})
export class TedallalSettingsModule {}
